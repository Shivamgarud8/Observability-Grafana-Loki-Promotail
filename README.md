# ObserveOps — Production DevOps Observability Stack

> A real-world, three-server monitoring and observability infrastructure built on AWS EC2 — covering CI/CD automation, infrastructure metrics, centralized log aggregation, Grafana dashboards, and email alerting.

---

## Table of Contents

1. [About the Project](#about-the-project)
2. [Tech Stack](#tech-stack)
3. [Architecture](#architecture)
4. [Server Roles](#server-roles)
5. [Server 1 — Jenkins Server](#server-1--jenkins-server)
6. [Server 2 — Flask App Server](#server-2--flask-app-server)
7. [Server 3 — Monitoring Server](#server-3--monitoring-server)
8. [Grafana — Datasource Configuration](#grafana--datasource-configuration)
9. [Email Alerting — Gmail SMTP Setup](#email-alerting--gmail-smtp-setup)
10. [Grafana — Contact Point Setup](#grafana--contact-point-setup)
11. [Alert Rules](#alert-rules)
12. [Grafana Dashboards](#grafana-dashboards)
13. [Port Reference](#port-reference)
14. [AWS Security Group Rules](#aws-security-group-rules)
15. [Common Issues and Fixes](#common-issues-and-fixes)
16. [Key Learnings](#key-learnings)
17. [Project Files](#project-files)

---

## About the Project

ObserveOps is a production-grade DevOps observability project deployed across three dedicated AWS EC2 instances. Each server has a clearly defined role — CI/CD automation, Python application hosting, and centralized monitoring — mirroring how real engineering teams operate production infrastructure.

The project implements the full observability triangle:

- **Metrics** — CPU, RAM, disk, and network data collected by Node Exporter, scraped and stored by Prometheus
- **Logs** — Jenkins, Flask, and NGINX logs shipped via Promtail and aggregated in Loki
- **Alerting** — Grafana alert rules that evaluate every minute and fire Gmail email notifications when thresholds are breached

Every component runs as a systemd service, ensuring automatic restart on reboot. Alert rules are configured with pending periods to prevent false fires from momentary spikes, and SMTP uses Gmail App Passwords for secure credential handling without exposing your main account password.

---

## Tech Stack

| Category          | Tool               | Version        |
|-------------------|--------------------|----------------|
| CI/CD             | Jenkins            | LTS            |
| Application       | Flask + Gunicorn   | Latest         |
| Reverse Proxy     | NGINX              | Latest         |
| Metrics Database  | Prometheus         | v3.4.2         |
| Log Aggregation   | Loki               | v3.0.0         |
| Log Shipper       | Promtail           | v3.0.0         |
| Metrics Agent     | Node Exporter      | v1.9.1         |
| Visualization     | Grafana Enterprise | v12.0.1        |
| Runtime           | Java 17 (Corretto) | 17             |
| OS — Server 1     | Amazon Linux 2     | —              |
| OS — Server 2 & 3 | Ubuntu 24.04       | —              |
| Cloud             | AWS EC2            | —              |

---

## Architecture

```
┌──────────────────────────┐
│        SERVER 1          │
│      Jenkins Server      │
│                          │
│  Jenkins   (CI/CD)       │
│  Node Exporter (metrics) │
│  Promtail  (logs)        │
└────────────┬─────────────┘
             │  Logs + Metrics
             ▼
┌──────────────────────────┐
│        SERVER 3          │
│    Monitoring Server     │
│                          │
│  Prometheus (metrics DB) │
│  Loki       (log store)  │
│  Grafana    (dashboards) │
└────────────▲─────────────┘
             │  Logs + Metrics
┌────────────┴─────────────┐
│        SERVER 2          │
│     Flask App Server     │
│                          │
│  Flask App  (Python API) │
│  NGINX      (proxy)      │
│  Node Exporter (metrics) │
│  Promtail  (logs)        │
└──────────────────────────┘
```

Metrics flow from Server 1 and Server 2 into Prometheus on Server 3 via Node Exporter scraping. Logs flow from Server 1 and Server 2 into Loki on Server 3 via Promtail push. Grafana on Server 3 reads both Prometheus and Loki as datasources and renders all dashboards and alert evaluations.

---

## Server Roles

| Server   | Role                  | Tools Installed                                      |
|----------|-----------------------|------------------------------------------------------|
| Server 1 | CI/CD Server          | Jenkins, Node Exporter, Promtail                     |
| Server 2 | Application Server    | Flask, Gunicorn, NGINX, Node Exporter, Promtail      |
| Server 3 | Central Monitoring    | Prometheus, Loki, Grafana                            |

---

## Server 1 — Jenkins Server

Server 1 runs the CI/CD pipeline. It ships its infrastructure metrics and application logs to Server 3.

**Jenkins** handles GitHub integration, automated builds, and deployment triggers. It runs on port 8080.

**Node Exporter** runs on port 9100 and exposes CPU, RAM, disk, network, and uptime metrics in Prometheus format. Prometheus on Server 3 scrapes this endpoint on a 15-second interval. The scrape target is labeled `Jenkins-Server` so dashboards show a human-readable name instead of an IP address.

**Promtail** reads Jenkins log files from disk and pushes them to Loki on Server 3. Logs are tagged with the job label `jenkins` for filtering in Grafana log panels.

All three components are registered as systemd services and restart automatically on server reboot.

Installation script: `install-server1.sh`

---

## Server 2 — Flask App Server

Server 2 hosts the Python web application and ships its own metrics and logs to Server 3.

**Flask + Gunicorn** serves the Python application. Gunicorn acts as the production WSGI server and Flask handles routing and application logic.

**NGINX** sits in front of Gunicorn as a reverse proxy on port 80. It handles incoming HTTP requests, serves static files, and forwards dynamic requests to Gunicorn on port 5000.

**Node Exporter** runs identically to Server 1 on port 9100, scraped by Prometheus with the instance label `Flask-Server`.

**Promtail** on Server 2 ships two log streams to Loki — Flask application logs tagged `flask-app` and NGINX access and error logs tagged `nginx`.

All four components run as systemd services.

Installation script: `install-server2.sh`

---

## Server 3 — Monitoring Server

Server 3 is the central observability hub. It receives all metrics and logs from Server 1 and Server 2 and exposes the Grafana web interface for dashboards, alerting, and log exploration.

**Prometheus** is configured with three scrape targets — itself, the Jenkins server (Server 1 IP on port 9100), and the Flask server (Server 2 IP on port 9100). Each target carries custom labels for readable dashboard filtering.

**Loki** receives log streams pushed by Promtail from both servers. It stores logs in a local filesystem store and exposes an HTTP API on port 3100 that Promtail writes to and Grafana reads from.

**Grafana** connects to both Prometheus and Loki as datasources. All dashboards, alert rules, contact points, and notification policies are managed from the Grafana UI on port 3000.

Installation script: `install-server3.sh`

---

## Grafana — Datasource Configuration

After Server 3 is running, open Grafana in the browser at `http://SERVER3-IP:3000`. Default login is `admin` / `admin`.

**Add Prometheus Datasource**

Navigate to: Connections → Data Sources → Add new datasource → Prometheus

Set the URL to `http://localhost:9090` and click Save & Test. The confirmation message should show that the datasource is working.

**Add Loki Datasource**

Navigate to: Connections → Data Sources → Add new datasource → Loki

Set the URL to `http://localhost:3100` and click Save & Test.

**Verify Prometheus Targets**

Open the Prometheus UI at `http://SERVER3-IP:9090/targets`. Three targets should appear — `prometheus`, `jenkins-server`, and `flask-server`. All must show status `UP`.

If `flask-server` or `jenkins-server` shows `DOWN`, the most common causes are:
- Node Exporter is not running on that server
- Port 9100 inbound rule is missing from the EC2 Security Group
- The IP address in `prometheus.yml` does not match the current server IP

---

## Email Alerting — Gmail SMTP Setup

Grafana sends alert emails via Gmail SMTP. This requires a Gmail App Password — a separate 16-character credential generated by Google specifically for third-party apps.

**Step 1 — Enable 2-Step Verification**

Open Google Account Security at `myaccount.google.com/security` and enable 2-Step Verification. App Passwords cannot be created without this step completed first.

**Step 2 — Create App Password**

Open Google Account → Security → App Passwords. Create a new entry and name it Grafana. Google generates a 16-character password in the format `xxxx xxxx xxxx xxxx`. Copy this value — it is shown only once.

**Step 3 — Edit Grafana Configuration**

On Server 3, open the Grafana configuration file at `/etc/grafana/grafana.ini` using a text editor. Find the `[smtp]` section. The entire section is disabled by default because every line starts with a semicolon (`;`), which is a comment character in `.ini` files.

Replace the entire `[smtp]` block with the following structure, filling in your own Gmail address and App Password:

```
[smtp]
enabled = true
host = smtp.gmail.com:587
user = YOUR_GMAIL@gmail.com
password = YOUR_APP_PASSWORD
skip_verify = true
from_address = YOUR_GMAIL@gmail.com
from_name = Grafana Alerts
ehlo_identity = grafana.local
startTLS_policy = OpportunisticStartTLS
```

The most common mistakes that break SMTP are:
- Leaving semicolons at the start of any line (they disable the setting silently)
- Setting `host = localhost:25` instead of `smtp.gmail.com:587`
- Using your regular Gmail password instead of the App Password

**Step 4 — Restart Grafana**

After saving the file, restart the Grafana service on Server 3 so the new SMTP settings take effect.

---

## Grafana — Contact Point Setup

A Contact Point tells Grafana where to deliver alert notifications. Without a contact point assigned, alerts will fire internally but no email is ever sent.

Navigate to: Alerts & IRM → Contact Points → Add Contact Point

Set the type to Email and enter the destination email address. Save the contact point.

Click the Test button. A test email should arrive within a few seconds. If it does not arrive:
- Verify the SMTP section in `grafana.ini` has no semicolons on any line
- Verify the host is `smtp.gmail.com:587` (not localhost)
- Verify the App Password was copied correctly (spaces in the 16-character key are fine)
- Check Grafana service logs for SMTP errors

---

## Alert Rules

All alert rules are created in Grafana under Alerts & IRM → Alert Rules. Each rule is placed in the folder `Infrastructure Alerts` and assigned to the evaluation group `server-alerts` with a 1-minute interval.

**Required settings for every alert rule**

| Setting          | Value                        | Why It Matters                                         |
|------------------|------------------------------|--------------------------------------------------------|
| Folder           | Infrastructure Alerts        | Organizes rules; must exist before saving              |
| Evaluation Group | server-alerts (interval: 1m) | Controls how frequently the rule is evaluated          |
| Pending Period   | 1m (production) / None (test)| Prevents false alerts from short spikes                |
| Contact Point    | grafana-default-email        | Must be selected or no notification is ever sent       |

---

### CPU Alert

Tracks real CPU utilization as a percentage. The query subtracts idle CPU time from 100 to give actual usage.

The alert fires when CPU exceeds 70% and stays above that threshold for 1 continuous minute before the email is sent.

To test this alert, run a CPU stress command on the Jenkins server. Within 1–2 minutes the alert status in Grafana moves from Normal → Pending → Firing and an email is delivered. Stop the stress test and the alert returns to Normal.

---

### RAM Alert

Tracks memory utilization by comparing available bytes to total bytes. The alert fires when RAM usage exceeds 85%.

---

### Disk Alert

Tracks disk usage as a percentage of total filesystem size using Node Exporter filesystem metrics. The alert fires when disk usage exceeds 90%.

---

### Server Down Alert

Monitors the `up` metric, which Prometheus automatically sets to 0 when a scrape target becomes unreachable. This alert fires immediately when a server goes offline, making it the most critical rule in the stack.

---

## Grafana Dashboards

| Dashboard                  | Datasource  | Import ID |
|----------------------------|-------------|-----------|
| Jenkins Server Monitoring  | Prometheus  | 1860      |
| Flask Server Monitoring    | Prometheus  | 1860      |
| Jenkins Application Logs   | Loki        | Custom    |
| Flask Application Logs     | Loki        | Custom    |

Dashboards are imported via Grafana → Dashboards → Import by entering the dashboard ID and selecting the Prometheus datasource.

**Loki Log Queries**

| Purpose                  | Query                               |
|--------------------------|-------------------------------------|
| All Jenkins logs         | `{job="jenkins"}`                   |
| All Flask logs           | `{job="flask-app"}`                 |
| Flask errors only        | `{job="flask-app"} \|= "ERROR"`     |
| Jenkins build failures   | `{job="jenkins"} \|= "FAILED"`      |

---

## Port Reference

| Service       | Port | Server   |
|---------------|------|----------|
| Jenkins       | 8080 | Server 1 |
| Node Exporter | 9100 | Server 1 |
| Flask App     | 5000 | Server 2 |
| NGINX         | 80   | Server 2 |
| Node Exporter | 9100 | Server 2 |
| Prometheus    | 9090 | Server 3 |
| Loki          | 3100 | Server 3 |
| Grafana       | 3000 | Server 3 |

---

## AWS Security Group Rules

These inbound rules must be configured on each EC2 instance's Security Group. Missing rules are the most common reason Prometheus targets show DOWN or Promtail logs stop arriving.

| Server   | Port | Protocol | Source    | Purpose                         |
|----------|------|----------|-----------|---------------------------------|
| Server 1 | 8080 | TCP      | 0.0.0.0/0 | Jenkins Web UI                  |
| Server 1 | 9100 | TCP      | 0.0.0.0/0 | Node Exporter — Prometheus scrape |
| Server 2 | 80   | TCP      | 0.0.0.0/0 | NGINX / Flask HTTP access       |
| Server 2 | 9100 | TCP      | 0.0.0.0/0 | Node Exporter — Prometheus scrape |
| Server 3 | 3000 | TCP      | 0.0.0.0/0 | Grafana Web UI                  |
| Server 3 | 9090 | TCP      | 0.0.0.0/0 | Prometheus Web UI and API       |
| Server 3 | 3100 | TCP      | 0.0.0.0/0 | Loki — Promtail log push        |

---

## Common Issues and Fixes

**Grafana dashboard shows N/A or No Data for Flask server**

Node Exporter is not running on Server 2, or port 9100 is not open in the Security Group. SSH into Server 2, check the Node Exporter process, start it if stopped, and verify the Prometheus target at `http://SERVER3-IP:9090/targets` shows `UP`.

**Alert fires but no email is received**

The contact point was not selected in the alert rule. Every alert rule has a Contact Point field that defaults to empty. Open the alert rule, select `grafana-default-email` in the Contact Point field, and save.

**SMTP test email fails in Grafana**

The `[smtp]` section in `/etc/grafana/grafana.ini` still has semicolons disabling the settings, the host is set to `localhost:25` instead of `smtp.gmail.com:587`, or the App Password is wrong. Fix all three, restart Grafana, then test again.

**CPU alert always firing even at 0.35% usage**

The alert threshold was left at `Is above 0` instead of `Is above 70`. Edit the alert rule and change the condition threshold to 70 (or 80 for production). Also verify the PromQL query is calculating a real percentage and not a raw fractional value.

---

## Key Learnings

- Deploying a distributed monitoring stack across multiple AWS EC2 instances
- Configuring Prometheus scrape targets with custom instance labels for human-readable dashboards
- Shipping logs from multiple servers to a centralized Loki instance using Promtail
- Diagnosing Node Exporter DOWN status by checking Security Group rules and process state
- Configuring Gmail SMTP in Grafana using App Passwords and fixing `.ini` comment-disabling pitfalls
- Writing PromQL expressions that correctly calculate real CPU, RAM, and disk usage percentages
- Building Grafana alert rules with pending periods, contact point assignment, and folder organization
- Understanding the difference between an alert firing internally and an alert notification being delivered

---

## Project Files

| File                 | Purpose                                              |
|----------------------|------------------------------------------------------|
| `README.md`          | Full project documentation                           |
| `install-server1.sh` | Automated setup for Jenkins Server (Server 1)        |
| `install-server2.sh` | Automated setup for Flask App Server (Server 2)      |
| `install-server3.sh` | Automated setup for Monitoring Server (Server 3)     |

---

## Author

**Shivam Garud**  
Cloud & DevOps Engineer · B.Tech CSE — P.P. Savani University · [@cloud_build_](https://instagram.com/cloud_build_)
