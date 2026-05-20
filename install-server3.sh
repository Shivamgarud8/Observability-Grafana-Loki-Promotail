#!/bin/bash

# ============================================================
#  ObserveOps — Server 3 Setup: Prometheus + Loki + Grafana
#  Author: Shivam Garud
#  Description: Installs and starts all monitoring tools on the central server
# ============================================================

set -e

echo ""
echo "============================================================"
echo "  ObserveOps — Server 3 (Monitoring Server) Setup"
echo "============================================================"
echo ""

# ─────────────────────────────────────────
# INPUT — Server IPs
# ─────────────────────────────────────────

echo "Enter Jenkins Server (Server 1) public IP:"
read -r JENKINS_IP

echo "Enter Flask Server (Server 2) public IP:"
read -r FLASK_IP

echo ""

# ─────────────────────────────────────────
# SECTION 1 — PROMETHEUS
# ─────────────────────────────────────────

echo "[1/3] Installing Prometheus..."
echo ""

sudo apt update -y

cd /tmp

wget https://github.com/prometheus/prometheus/releases/download/v3.4.2/prometheus-3.4.2.linux-amd64.tar.gz

tar xvf prometheus-3.4.2.linux-amd64.tar.gz

cd prometheus-3.4.2.linux-amd64

# Write prometheus.yml with entered IPs
tee /tmp/prometheus-3.4.2.linux-amd64/prometheus.yml > /dev/null <<EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:

  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]
        labels:
          instance: "Monitoring-Server"

  - job_name: "jenkins-server"
    static_configs:
      - targets: ["${JENKINS_IP}:9100"]
        labels:
          app: "jenkins"
          server: "server-1"
          instance: "Jenkins-Server"

  - job_name: "flask-server"
    static_configs:
      - targets: ["${FLASK_IP}:9100"]
        labels:
          app: "flask-app"
          server: "server-2"
          instance: "Flask-Server"
EOF

# Create systemd service for Prometheus
sudo tee /etc/systemd/system/prometheus.service > /dev/null <<EOF
[Unit]
Description=Prometheus Monitoring
After=network.target

[Service]
ExecStart=/tmp/prometheus-3.4.2.linux-amd64/prometheus \
  --config.file=/tmp/prometheus-3.4.2.linux-amd64/prometheus.yml
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable prometheus
sudo systemctl start prometheus

echo ""
echo "✅ Prometheus installed and started on port 9090"
echo ""

# ─────────────────────────────────────────
# SECTION 2 — LOKI
# ─────────────────────────────────────────

echo "[2/3] Installing Loki..."
echo ""

mkdir -p /tmp/loki
cd /tmp/loki

wget https://github.com/grafana/loki/releases/download/v3.0.0/loki-linux-amd64.zip

unzip -o loki-linux-amd64.zip

chmod +x loki-linux-amd64

# Write minimal Loki config
tee /tmp/loki/loki-config.yaml > /dev/null <<EOF
auth_enabled: false

server:
  http_listen_port: 3100

common:
  path_prefix: /tmp/loki
  storage:
    filesystem:
      chunks_directory: /tmp/loki/chunks
      rules_directory: /tmp/loki/rules
  replication_factor: 1
  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h
EOF

# Create systemd service for Loki
sudo tee /etc/systemd/system/loki.service > /dev/null <<EOF
[Unit]
Description=Loki Log Aggregation
After=network.target

[Service]
ExecStart=/tmp/loki/loki-linux-amd64 -config.file=/tmp/loki/loki-config.yaml
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable loki
sudo systemctl start loki

echo ""
echo "✅ Loki installed and started on port 3100"
echo ""

# ─────────────────────────────────────────
# SECTION 3 — GRAFANA
# ─────────────────────────────────────────

echo "[3/3] Installing Grafana..."
echo ""

sudo apt install -y adduser libfontconfig1 musl

cd /tmp

wget https://dl.grafana.com/enterprise/release/grafana-enterprise_12.0.1_amd64.deb

sudo dpkg -i grafana-enterprise_12.0.1_amd64.deb

sudo systemctl enable grafana-server
sudo systemctl start grafana-server

echo ""
echo "✅ Grafana installed and started on port 3000"
echo ""

# ─────────────────────────────────────────
# SUMMARY
# ─────────────────────────────────────────

echo "============================================================"
echo "  Server 3 Setup Complete"
echo "============================================================"
echo ""
echo "  Service         Port    URL"
echo "  --------------- ------  ----------------------------"
echo "  Prometheus      9090    http://$(curl -s ifconfig.me):9090"
echo "  Loki            3100    http://$(curl -s ifconfig.me):3100"
echo "  Grafana         3000    http://$(curl -s ifconfig.me):3000"
echo ""
echo "  Grafana default login:"
echo "  Username: admin"
echo "  Password: admin"
echo ""
echo "  Next Steps in Grafana:"
echo "  1. Add Prometheus datasource → http://localhost:9090"
echo "  2. Add Loki datasource       → http://localhost:3100"
echo "  3. Import dashboard ID 1860 for Jenkins server"
echo "  4. Import dashboard ID 1860 for Flask server"
echo "  5. Configure Gmail SMTP in /etc/grafana/grafana.ini"
echo "  6. Add Contact Point → Email"
echo "  7. Create CPU / RAM / Disk alert rules"
echo ""
echo "  Verify Prometheus targets:"
echo "  http://$(curl -s ifconfig.me):9090/targets"
echo ""
echo "  Jenkins and Flask must show UP status."
echo ""
echo "============================================================"
