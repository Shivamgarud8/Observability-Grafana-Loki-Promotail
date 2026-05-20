#!/bin/bash

# ============================================================
#  ObserveOps — Server 1 Setup: Jenkins + Node Exporter + Promtail
#  Author: Shivam Garud
#  Description: Installs and starts all tools on the Jenkins CI/CD server
# ============================================================

set -e

echo ""
echo "============================================================"
echo "  ObserveOps — Server 1 (Jenkins Server) Setup"
echo "============================================================"
echo ""

# ─────────────────────────────────────────
# SECTION 1 — JENKINS
# ─────────────────────────────────────────

echo "[1/3] Installing Jenkins..."
echo ""

sudo yum update -y

sudo wget -O /etc/yum.repos.d/jenkins.repo \
  https://pkg.jenkins.io/redhat-stable/jenkins.repo

sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

sudo yum install java-17-amazon-corretto -y

sudo yum install jenkins -y

sudo systemctl enable jenkins
sudo systemctl start jenkins

echo ""
echo "✅ Jenkins installed and started on port 8080"
echo ""

# ─────────────────────────────────────────
# SECTION 2 — NODE EXPORTER
# ─────────────────────────────────────────

echo "[2/3] Installing Node Exporter..."
echo ""

cd /tmp

wget https://github.com/prometheus/node_exporter/releases/download/v1.9.1/node_exporter-1.9.1.linux-amd64.tar.gz

tar xvf node_exporter-1.9.1.linux-amd64.tar.gz

cd node_exporter-1.9.1.linux-amd64

chmod +x node_exporter

# Create systemd service for Node Exporter
sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<EOF
[Unit]
Description=Node Exporter
After=network.target

[Service]
ExecStart=/tmp/node_exporter-1.9.1.linux-amd64/node_exporter
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl start node_exporter

echo ""
echo "✅ Node Exporter installed and started on port 9100"
echo ""

# ─────────────────────────────────────────
# SECTION 3 — PROMTAIL
# ─────────────────────────────────────────

echo "[3/3] Installing Promtail..."
echo ""

cd /tmp

wget https://github.com/grafana/loki/releases/download/v3.0.0/promtail-linux-amd64.zip

unzip -o promtail-linux-amd64.zip

chmod +x promtail-linux-amd64

# Write Promtail config — update MONITORING_SERVER_IP below
MONITORING_SERVER_IP="YOUR_SERVER3_IP"

tee /tmp/promtail-config.yaml > /dev/null <<EOF
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://${MONITORING_SERVER_IP}:3100/loki/api/v1/push

scrape_configs:
  - job_name: jenkins
    static_configs:
      - targets:
          - localhost
        labels:
          job: jenkins
          __path__: /var/log/jenkins/*.log
EOF

# Create systemd service for Promtail
sudo tee /etc/systemd/system/promtail.service > /dev/null <<EOF
[Unit]
Description=Promtail Log Shipper
After=network.target

[Service]
ExecStart=/tmp/promtail-linux-amd64 -config.file=/tmp/promtail-config.yaml
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable promtail
sudo systemctl start promtail

echo ""
echo "✅ Promtail installed and started"
echo ""

# ─────────────────────────────────────────
# SUMMARY
# ─────────────────────────────────────────

echo "============================================================"
echo "  Server 1 Setup Complete"
echo "============================================================"
echo ""
echo "  Service         Port"
echo "  --------------- ------"
echo "  Jenkins         8080"
echo "  Node Exporter   9100"
echo "  Promtail        9080"
echo ""
echo "  ⚠  ACTION REQUIRED:"
echo "  Update MONITORING_SERVER_IP in /tmp/promtail-config.yaml"
echo "  with your Server 3 (Monitoring Server) IP address."
echo "  Then restart Promtail:"
echo "  sudo systemctl restart promtail"
echo ""
echo "  Verify Node Exporter:"
echo "  curl localhost:9100/metrics"
echo ""
echo "  Jenkins initial admin password:"
echo "  sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
echo ""
echo "============================================================"
