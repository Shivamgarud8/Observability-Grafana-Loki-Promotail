# ObserveOps — Full-Stack DevOps Observability Infrastructure

> A production-grade, three-server monitoring and observability platform built with Jenkins, Prometheus, Loki, Grafana, and Flask — covering CI/CD pipelines, infrastructure metrics, and centralized log aggregation.

---

## Project Overview

ObserveOps demonstrates a real-world DevOps observability stack deployed across three dedicated EC2 servers. Each server has a distinct role — CI/CD automation, application hosting, and centralized monitoring — mirroring how modern engineering teams instrument production systems.

The project covers the full observability triangle: **metrics**, **logs**, and **alerting**, all visualized in Grafana dashboards and backed by Prometheus and Loki as the data stores.

---

## Architecture

```
┌──────────────────────────┐
│       SERVER 1           │
│     Jenkins Server       │
│                          │
│  Jenkins  (CI/CD)        │
│  Node Exporter (metrics) │
│  Promtail  (logs)        │
└────────────┬─────────────┘
             │  Logs + Metrics
             ▼
┌──────────────────────────┐
│       SERVER 3           │
│   Monitoring Server      │
│                          │
│  Prometheus (metrics DB) │
│  Loki       (log store)  │
│  Grafana    (dashboards) │
└────────────▲─────────────┘
             │  Logs + Metrics
┌────────────┴─────────────┐
│       SERVER 2           │
│    Flask App Server      │
│                          │
│  Flask App  (Python API) │
│  NGINX      (proxy)      │
│  Node Exporter (metrics) │
│  Promtail   (logs)       │
└──────────────────────────┘
```

---

## Server Roles

| Server   | Role                    | Key Tools                                   |
|----------|-------------------------|---------------------------------------------|
| Server 1 | CI/CD Server            | Jenkins, Node Exporter, Promtail            |
| Server 2 | Application Server      | Flask, NGINX, Node Exporter, Promtail       |
| Server 3 | Central Monitoring      | Prometheus, Loki, Grafana                   |

---

## What Gets Monitored

### Infrastructure Metrics (via Prometheus + Node Exporter)
- CPU utilization per server
- RAM and memory availability
- Disk usage and I/O
- Network traffic
- Server uptime

### Application Logs (via Loki + Promtail)
- Jenkins build and deployment logs
- Flask application logs
- NGINX access and error logs
- Python error traces

### Alerts (via Grafana Alerting)
- CPU > 80%
- RAM > 85%
- Disk > 90%
- Server unreachable (Node Exporter down)
- Jenkins build failure
- Flask application errors

---

## Grafana Dashboards

| Dashboard                     | Data Source | Dashboard ID |
|-------------------------------|-------------|--------------|
| Jenkins Server Monitoring     | Prometheus  | 1860         |
| Flask Server Monitoring       | Prometheus  | 1860         |
| Application Logs — Jenkins    | Loki        | Custom       |
| Application Logs — Flask      | Loki        | Custom       |

---

## Loki Log Queries

| Query                                   | Purpose                      |
|-----------------------------------------|------------------------------|
| `{job="jenkins"}`                       | All Jenkins logs             |
| `{job="flask-app"}`                     | All Flask application logs   |
| `{job="flask-app"} \|= "ERROR"`         | Python errors only           |
| `{job="jenkins"} \|= "FAILED"`          | Failed Jenkins builds        |

---

## Port Reference

| Service       | Port | Server   |
|---------------|------|----------|
| Jenkins       | 8080 | Server 1 |
| Node Exporter | 9100 | Server 1 |
| Node Exporter | 9100 | Server 2 |
| Flask App     | 5000 | Server 2 |
| NGINX         | 80   | Server 2 |
| Prometheus    | 9090 | Server 3 |
| Loki          | 3100 | Server 3 |
| Grafana       | 3000 | Server 3 |

---

## Alert Configuration

Grafana alerts are configured via Gmail SMTP. When a threshold is breached, Grafana evaluates the alert rule every minute and sends an email notification through a configured Contact Point.

Alert flow:

```
Metric threshold breached
        ↓
Prometheus detects anomaly
        ↓
Grafana alert rule fires
        ↓
Contact Point triggers
        ↓
Email notification sent
```

---

## AWS Security Group Rules Required

| Server   | Port | Protocol | Purpose                    |
|----------|------|----------|----------------------------|
| Server 1 | 8080 | TCP      | Jenkins UI                 |
| Server 1 | 9100 | TCP      | Node Exporter (Prometheus) |
| Server 2 | 9100 | TCP      | Node Exporter (Prometheus) |
| Server 2 | 80   | TCP      | NGINX / Flask              |
| Server 3 | 3000 | TCP      | Grafana UI                 |
| Server 3 | 9090 | TCP      | Prometheus UI              |
| Server 3 | 3100 | TCP      | Loki (Promtail push)       |

---

## Tech Stack

| Category        | Tool                  | Version   |
|-----------------|-----------------------|-----------|
| CI/CD           | Jenkins               | LTS       |
| App Framework   | Flask                 | Latest    |
| Reverse Proxy   | NGINX                 | Latest    |
| Metrics DB      | Prometheus            | v3.4.2    |
| Log Aggregation | Loki                  | v3.0.0    |
| Log Shipper     | Promtail              | v3.0.0    |
| Metrics Agent   | Node Exporter         | v1.9.1    |
| Visualization   | Grafana Enterprise    | v12.0.1   |
| Runtime         | Java 17 (Corretto)    | 17        |
| OS              | Amazon Linux 2 / Ubuntu 24 | —    |
| Cloud           | AWS EC2               | —         |

---

## Key Learnings

- Deploying a multi-server monitoring stack on AWS EC2
- Configuring Prometheus scrape targets with custom labels
- Shipping logs with Promtail to a remote Loki instance
- Building Grafana dashboards from Prometheus and Loki datasources
- Setting up Gmail SMTP alerting in Grafana
- Diagnosing Node Exporter connectivity issues via Security Groups and Prometheus targets UI
- Writing LogQL queries for log filtering and error detection

---

## Project Files

| File                    | Purpose                                  |
|-------------------------|------------------------------------------|
| `README.md`             | Project overview and documentation       |
| `install-server1.sh`    | Automated setup script for Jenkins server|
| `install-server2.sh`    | Automated setup script for Flask server  |
| `install-server3.sh`    | Automated setup script for monitoring server |

---

## Author

**Shivam Garud**
Cloud & DevOps Engineer | B.Tech CSE — P.P. Savani University
