#!/bin/bash
set -e

if [ $# -lt 1 ]; then
  echo "Usage: qlab-install.sh <USERNAME> [THREADS or 1gb] [1gb (optional)]"
  exit 1
fi

username="$1"

# Determine threads and extraArgs based on inputs
if [ "$2" == "1gb" ]; then
  threads=$(($(nproc) - 2))
  extraArgs="--randomx-1gb-pages"
elif [ -n "$2" ] && [ "$3" == "1gb" ]; then
  threads="$2"
  extraArgs="--randomx-1gb-pages"
else
  threads="${2:-$(($(nproc) - 2))}"
  extraArgs=""
fi

package="qli-Client-3.3.8-Linux-x64.tar.gz"
worker="$(echo $RANDOM | md5sum | head -c 10)"

path="/q"
xmrigBinary="xmrig-qlab"
serviceScript="qlab-Service.sh"
servicePath="/etc/systemd/system"
serviceName="qlab.service"
settingsFile="appsettings.json"

accessToken='eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJJZCI6ImQzNzMyODc2LTY5ZDctNGI1OC1hNmUzLWM2MzZkMGQ4ZDE0NiIsIk1pbmluZyI6IiIsIm5iZiI6MTc1NjkxNzY1NCwiZXhwIjoxNzg4NDUzNjU0LCJpYXQiOjE3NTY5MTc2NTQsImlzcyI6Imh0dHBzOi8vcXViaWMubGkvIiwiYXVkIjoiaHR0cHM6Ly9xdWJpYy5saS8ifQ.vt5Eu1jhiZFCAYYBhmH3MJpliLUeC06AzRijOSCA9cQRI3c8ANPubYv5dOSaroRdO1X1Ik9QM1obQGrGeSXCV8ZRotNAGqmvpoyZ-O5xLXytQMGE-3gGAIjdqIb2_qSv2uP1OCQ654P0QpAc7bYxoY1-b3qieOSzRtA5EFPg4k-UfH0kZHi1JBt9cXFjpF58okgnNKCJt1Jkg2axvNzWzG5AHC52M6I7cZPPxewTwNigyTsG_P5iBGymxHEBNtG99yn9A_GNJeYfqXBv-RM6M6dTiJeD78EY5m4xvr0q8fIJTJJkdP4w1OpzboTFRudPM94bDeeviMxwV6pAcBG7tw'
userToken="minerlab"

systemctl stop $serviceName 2>/dev/null || true

mkdir -p $path
cd $path
rm -f *.tar.gz *.lock *.sol *.e* *.json

if [[ ! -f "qli-Client" ]]; then
  echo "ðŸ”¥ Downloading QLI Client..."
  wget -4 -O "$package" "https://poolsolution.s3.eu-west-2.amazonaws.com/$package"
  tar -xzvf "$package"
  rm -f "$package"
  chmod +x qli-Client
else
  echo "âœ… qli-Client already exists, skipping download."
fi

if [[ ! -f "$xmrigBinary" ]]; then
  echo "ðŸ”¥ Downloading xmrig-qlab..."
  wget -4 -O "$xmrigBinary" "https://poolsolution.s3.eu-west-2.amazonaws.com/$xmrigBinary"
  chmod +x xmrig-qlab
else
  echo "âœ… xmrig-qlab already exists, skipping download."
fi

cat > "$settingsFile" <<'EOF'
{
  "ClientSettings": {
    "poolAddress": "wss://pps.minerlab.io/ws/REPLACE_USERNAME",
    "alias": "REPLACE_WORKER",
    "accessToken": "REPLACE_ACCESS_TOKEN",
    "qubicAddress": null,
    "pps": true,
    "trainer": {
      "cpu": true,
      "gpu": false,
      "cpuVersion": null,
      "gpuVersion": "CUDA",
      "cpuThreads": REPLACE_THREADS
    },
    "xmrSettings": {
      "disable": false,
      "enableGpu": false,
      "poolAddress": "qxmr.minerlab.io:3333",
      "customParameters": "-a rx/0  -u REPLACE_TOKEN::REPLACE_USERNAME -t 0",
      "binaryName": "xmrig-qlab"
    },
    "idling": {
      "command": "",
      "arguments": ""
    }
  }
}
EOF

sed -i "s/REPLACE_USERNAME/$username/g" "$settingsFile"
sed -i "s/REPLACE_WORKER/$worker/g" "$settingsFile"
sed -i "s|REPLACE_ACCESS_TOKEN|$accessToken|g" "$settingsFile"
sed -i "s/REPLACE_THREADS/$threads/g" "$settingsFile"
sed -i "s|REPLACE_TOKEN|$userToken|g" "$settingsFile"
sed -i "s|REPLACE_EXTRA|$extraArgs|g" "$settingsFile"

cat > "$serviceScript" <<EOF
#!/bin/bash
cd "$path"
./qli-Client
EOF
chmod +x "$serviceScript"

cat > "$servicePath/$serviceName" <<EOF
[Unit]
Description=QLAB Miner Service
After=network-online.target

[Service]
ExecStart=/bin/bash $path/$serviceScript
WorkingDirectory=$path
StandardOutput=append:/var/log/qlab.log
StandardError=append:/var/log/qlab.error.log
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

chmod 664 "$servicePath/$serviceName"
systemctl daemon-reload
systemctl enable "$serviceName"
systemctl start "$serviceName"

echo "âœ… QLAB Miner installed and running."
echo "Username: $username"
echo "Worker: $worker"
echo "Threads: $threads"
