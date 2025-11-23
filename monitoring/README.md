# Monitoring Stack

## Overview

The Orion-Sentinel-CoreSrv monitoring stack provides comprehensive observability for the entire home lab infrastructure:

- **Prometheus**: Metrics collection and time-series database
- **Grafana**: Visualization and dashboards
- **Loki**: Log aggregation
- **Promtail**: Log collection agent
- **Uptime Kuma**: Uptime monitoring and status page
- **Node Exporter**: Host metrics (CPU, RAM, disk, network)
- **cAdvisor**: Container metrics

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Orion-Sentinel-CoreSrv                    │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Grafana    │  │  Prometheus  │  │     Loki     │      │
│  │ Dashboards   │  │   Metrics    │  │     Logs     │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
│         │                 │                  │              │
│         │                 │                  │              │
│  ┌──────▼─────────────────▼──────────────────▼───────┐      │
│  │           Query & Visualization Layer             │      │
│  └───────────────────────────────────────────────────┘      │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Node Exporter│  │   cAdvisor   │  │  Promtail    │      │
│  │ Host Metrics │  │Container Mtx │  │ Log Scraper  │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│                                                              │
└─────────────────────────────────────────────────────────────┘
                              ▲
                              │
        ┌─────────────────────┴─────────────────────┐
        │                                           │
┌───────▼────────┐                         ┌────────▼───────┐
│   DNS Pi       │                         │  NetSec Pi     │
│                │                         │                │
│  Promtail ────────────────┐              │  Promtail ─────┤
│  PiHole Exp   │           │              │  Suricata      │
│  Unbound Exp  │           │              │  IDS/IPS       │
└────────────────┘           │              └────────────────┘
                             │
                    Metrics & Logs
                    sent to CoreSrv
```

## Components

### Prometheus (Port 9090)

**Purpose**: Collects and stores metrics from all services and hosts

**Scraped Targets**:
- CoreSrv node metrics (node_exporter on 9100)
- CoreSrv container metrics (cAdvisor on 8080)
- DNS Pi exporters (PiHole on 9617, Unbound on 9167)
- NetSec Pi exporters (node_exporter on 9100)
- Traefik metrics (optional, port 8082)

**Access**: https://prometheus.local

**Data Retention**: 15 days (configurable via PROMETHEUS_RETENTION_TIME)

### Grafana (Port 3000)

**Purpose**: Visualization and dashboarding

**Datasources**:
- Prometheus (default)
- Loki

**Access**: https://grafana.local

**Credentials**: Set via GRAFANA_ADMIN_USER and GRAFANA_ADMIN_PASSWORD

**Provisioning**:
- Datasources: `monitoring/grafana/provisioning/datasources/`
- Dashboards: `monitoring/grafana/provisioning/dashboards/`

### Loki (Port 3100)

**Purpose**: Log aggregation from all nodes

**Log Sources**:
- CoreSrv Docker containers (via Promtail)
- DNS Pi Docker containers (via remote Promtail)
- NetSec Pi Docker containers (via remote Promtail)

**Access**: Internal only (http://loki:3100)

**Data Retention**: 7 days (168h)

**External Access**: Optionally expose port 3100 for Pi agents (see docs/REMOTE-LOGS.md)

### Promtail (Port 9080)

**Purpose**: Collect and ship logs to Loki

**Scrapes**:
- Docker container logs from `/var/lib/docker/containers`

**Pipeline**: Parses Docker JSON logs and extracts metadata

### Uptime Kuma (Port 3001)

**Purpose**: Uptime monitoring and status page

**Access**: https://status.local

**Monitors**:
- All CoreSrv services
- Pi DNS services
- Pi NetSec services
- External websites/APIs

### Node Exporter (Port 9100)

**Purpose**: Host-level metrics (CPU, RAM, disk, network)

**Metrics Collected**:
- CPU usage and load
- Memory usage
- Disk I/O and space
- Network traffic
- System uptime

**Mode**: Host network mode for accurate host metrics

### cAdvisor (Port 8080)

**Purpose**: Docker container metrics

**Metrics Collected**:
- Container CPU usage
- Container memory usage
- Container network I/O
- Container filesystem usage

## Configuration Files

```
monitoring/
├── prometheus/
│   └── prometheus.yml          # Scrape config for all targets
├── loki/
│   └── config.yml             # Loki configuration & retention
├── promtail/
│   └── config.yml             # Log scraping config
└── grafana/
    ├── provisioning/
    │   ├── datasources/
    │   │   └── datasources.yml     # Auto-configure Prometheus & Loki
    │   └── dashboards/
    │       └── orion.yml           # Dashboard provider config
    └── dashboards/
        └── orion/                  # Dashboard JSON files
            └── .gitkeep
```

## Quick Start

### Start Monitoring Stack

```bash
# Start core + monitoring
./scripts/orionctl.sh up-observability

# Or start everything
./scripts/orionctl.sh up-full
```

### Access Services

- **Grafana**: https://grafana.local (protected by Authelia)
- **Prometheus**: https://prometheus.local (protected by Authelia)
- **Uptime Kuma**: https://status.local (protected by Authelia)

### View Logs in Grafana

1. Navigate to https://grafana.local
2. Click "Explore" in left sidebar
3. Select "Loki" datasource
4. Use LogQL queries:

```logql
# All logs from CoreSrv
{job="docker"}

# Logs from specific container
{container_name="traefik"}

# Logs from Pi DNS
{host="pi-dns"}

# Errors across all nodes
{host=~".*"} |= "error"
```

### View Metrics in Grafana

1. Navigate to https://grafana.local
2. Click "Explore" in left sidebar
3. Select "Prometheus" datasource
4. Use PromQL queries:

```promql
# CPU usage by container
rate(container_cpu_usage_seconds_total[5m])

# Memory usage
container_memory_usage_bytes

# Network traffic
rate(container_network_transmit_bytes_total[5m])
```

## Importing Dashboards

### From Grafana.com

Popular dashboard IDs to import:

1. **Node Exporter Full** (ID: 1860)
   - Complete host metrics
   
2. **Docker Container & Host** (ID: 179)
   - Container resource usage
   
3. **Traefik 2.x** (ID: 12250)
   - Reverse proxy metrics
   
4. **Loki Dashboard** (ID: 13639)
   - Log volume and queries
   
5. **Pi-hole Exporter** (ID: 10176)
   - DNS statistics

**Import Steps**:
1. Grafana → Dashboards → Import
2. Enter dashboard ID
3. Select Prometheus as datasource
4. Click "Import"

### From JSON Files

Save dashboards to `monitoring/grafana/dashboards/orion/`:

```bash
# Download dashboard JSON
wget https://grafana.com/api/dashboards/1860/revisions/latest/download \
  -O monitoring/grafana/dashboards/orion/node-exporter.json

# Restart Grafana to pick up new dashboard
docker compose restart grafana
```

## Scrape Targets

### Current Targets (CoreSrv)

| Job Name           | Target            | Metrics                          |
|--------------------|-------------------|----------------------------------|
| prometheus         | localhost:9090    | Prometheus self-monitoring       |
| coresrv-node       | node-exporter:9100| Host metrics (CPU, RAM, disk)    |
| coresrv-cadvisor   | cadvisor:8080     | Container metrics                |

### Pi DNS Targets

| Job Name           | Target               | Metrics                       |
|--------------------|----------------------|-------------------------------|
| pi-dns-node        | 192.168.8.240:9100   | Host metrics                  |
| pihole             | 192.168.8.240:9617   | Pi-hole DNS statistics        |
| unbound            | 192.168.8.240:9167   | Unbound DNS metrics           |

### Pi NetSec Targets

| Job Name           | Target               | Metrics                       |
|--------------------|----------------------|-------------------------------|
| pi-netsec-node     | 192.168.8.241:9100   | Host metrics                  |

**Note**: Update IPs in `monitoring/prometheus/prometheus.yml` to match your network

## Storage & Retention

### Prometheus

- **Path**: `${MONITORING_ROOT}/prometheus/data`
- **Retention**: 15 days (configurable via PROMETHEUS_RETENTION_TIME)
- **Estimated Size**: ~1-5GB depending on scrape frequency and target count
- **Cleanup**: Automatic (handled by Prometheus retention)

### Loki

- **Path**: `${MONITORING_ROOT}/loki/`
- **Retention**: 7 days (168h)
- **Estimated Size**: ~500MB-2GB depending on log volume
- **Cleanup**: Automatic via compactor

### Grafana

- **Path**: `${MONITORING_ROOT}/grafana/data`
- **Contents**: Dashboards, users, preferences, datasources
- **Estimated Size**: ~100-500MB
- **Backup**: Included in backup.sh script

## Alerting (Future)

### TODO: Configure Alertmanager

```yaml
# Add to prometheus.yml
alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093
```

### Example Alert Rules

```yaml
# monitoring/prometheus/rules/alerts.yml
groups:
  - name: host
    rules:
      - alert: HighCPU
        expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        
      - alert: HighMemory
        expr: (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100 < 10
        for: 5m
```

## Troubleshooting

### Prometheus Not Scraping Targets

**Check target status**:
```bash
# Open Prometheus UI
https://prometheus.local

# Navigate to: Status → Targets
# Look for red/down targets
```

**Common issues**:
1. **Target unreachable**: Check firewall rules, verify IP addresses
2. **Exporter not running**: Start exporter service on target
3. **Wrong port**: Verify port numbers in prometheus.yml

### Grafana Dashboard Shows No Data

**Check datasource connection**:
1. Grafana → Configuration → Data Sources → Prometheus
2. Click "Test" button
3. Should show "Data source is working"

**Check time range**:
- Ensure time range covers when data was collected
- Try "Last 1 hour" or "Last 5 minutes"

### Loki Logs Not Appearing

**Verify Promtail is running**:
```bash
docker logs promtail
# Should see: "Successfully connected to Loki"
```

**Check log labels**:
```logql
# List all available labels
{job=~".+"}

# Check specific label values
{container_name=~".+"}
```

### High Disk Usage

**Check Prometheus data**:
```bash
du -sh ${MONITORING_ROOT}/prometheus/data
```

**Reduce retention**:
Edit `env/.env.monitoring`:
```bash
PROMETHEUS_RETENTION_TIME=7d  # Reduce from 15d to 7d
```

**Check Loki data**:
```bash
du -sh ${MONITORING_ROOT}/loki
```

**Reduce Loki retention**:
Edit `monitoring/loki/config.yml`:
```yaml
limits_config:
  retention_period: 72h  # Reduce from 168h (7d) to 72h (3d)
```

## Performance Tuning

### Reduce Prometheus Scrape Frequency

Edit `monitoring/prometheus/prometheus.yml`:
```yaml
global:
  scrape_interval: 30s  # Increase from 15s to 30s
```

### Reduce Log Volume

Add filters to Promtail:
```yaml
pipeline_stages:
  - match:
      selector: '{job="docker"} |~ "debug"'
      action: drop
```

### Limit Metrics Collected

Disable unused cAdvisor metrics:
```yaml
command:
  - '--disable_metrics=percpu,sched,tcp,udp,disk,diskIO,accelerator'
```

## Security

### Access Control

- All monitoring services protected by Authelia SSO
- Traefik routes require authentication via `secure-chain@file` middleware
- Loki ingestion port (3100) only exposed on LAN (optional)

### Network Segmentation

- Monitoring services on `orion_monitoring` network
- Isolated from public internet
- Only accessible via Traefik reverse proxy

### Secrets Management

- Grafana admin credentials in `.env.monitoring`
- Never commit secrets to git
- Use `openssl rand -hex 32` to generate secure passwords

## References

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/grafana/latest/)
- [Loki Documentation](https://grafana.com/docs/loki/latest/)
- [Promtail Configuration](https://grafana.com/docs/loki/latest/clients/promtail/)
- [cAdvisor GitHub](https://github.com/google/cadvisor)
- [Node Exporter GitHub](https://github.com/prometheus/node_exporter)

---

**Last Updated**: 2025-11-23  
**Maintained By**: Orion Home Lab Team
