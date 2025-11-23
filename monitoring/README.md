# Monitoring Stack: Prometheus + Grafana + Loki + Promtail + Uptime Kuma

## Overview

The monitoring stack provides comprehensive observability across the entire Orion home lab (CoreSrv + Pi DNS + Pi NetSec):

- **Prometheus** - Metrics collection and time-series database
- **Grafana** - Dashboards and visualization
- **Loki** - Log aggregation and querying
- **Promtail** - Log collection from Docker containers
- **Uptime Kuma** - Uptime monitoring and status pages

## What Lives Here

```
monitoring/
├── prometheus/
│   ├── prometheus.yml     # Prometheus configuration and scrape targets
│   └── rules/             # Alert rules (future)
├── grafana/
│   └── provisioning/      # Datasources and dashboards
│       ├── datasources/   # Auto-configure Prometheus, Loki
│       └── dashboards/    # Pre-configured dashboard JSONs
├── loki/
│   └── config.yml         # Loki configuration
├── promtail/
│   └── config.yml         # Promtail log collection config
└── README.md              # This file
```

## Services

### Prometheus

**Purpose:** Time-series metrics database and monitoring system

**Key Features:**
- Scrapes metrics from exporters across all nodes
- Powerful query language (PromQL)
- Built-in alerting (with Alertmanager)
- Efficient time-series storage

**Access:**
- Web UI: `https://prometheus.local` (protected by Authelia)

**Scrape Targets:**

```yaml
# CoreSrv targets
- node_exporter:9100      # Host metrics (CPU, RAM, disk, network)
- cadvisor:8080           # Container metrics
- traefik:8082            # Traefik metrics

# Pi DNS targets (Pi 5 #1)
- pi-dns:9100             # node_exporter
- pi-dns:9617             # pihole_exporter
- pi-dns:9167             # unbound_exporter

# Pi NetSec targets (Pi 5 #2)
- pi-netsec:9100          # node_exporter
- pi-netsec:XXXX          # Orion Sentinel metrics (custom)
```

**Configuration:**
- Main config: `monitoring/prometheus/prometheus.yml`
- Retention: 15 days (configurable in `.env.monitoring`)
- Scrape interval: 15 seconds

### Grafana

**Purpose:** Visualization and dashboards for metrics and logs

**Key Features:**
- Beautiful, customizable dashboards
- Unified view of metrics (Prometheus) and logs (Loki)
- Alerting and notifications
- User management and permissions

**Access:**
- Web UI: `https://grafana.local` (protected by Authelia)
- Default credentials: admin / (set in `.env.monitoring`)

**Pre-configured Datasources:**
- Prometheus (http://prometheus:9090)
- Loki (http://loki:3100)

**Recommended Dashboards:**

Import these popular dashboards (via ID or JSON):

1. **Node Exporter Full** (ID: 1860)
   - Comprehensive host metrics
   - CPU, RAM, disk, network I/O

2. **Docker Container & Host Metrics** (ID: 179)
   - Container resource usage
   - Per-container CPU/RAM/network

3. **Traefik 2.x** (ID: 12250)
   - Request rates, response times
   - HTTP status codes

4. **Loki Logs Dashboard** (ID: 13639)
   - Unified log viewer
   - Filter by container, service, level

5. **Pi-hole Exporter** (ID: 10176)
   - DNS queries, blocked ads
   - Top clients and domains

### Loki

**Purpose:** Log aggregation system (like Prometheus, but for logs)

**Key Features:**
- Cost-effective log storage (indexes metadata, not content)
- Powerful log queries (LogQL)
- Integration with Grafana
- Label-based log organization

**Access:**
- No direct UI (use Grafana for queries)
- API: http://loki:3100 (internal only)

**Configuration:**
- Config: `monitoring/loki/config.yml`
- Retention: 30 days (configurable)
- Storage: Local filesystem

**Log Labels:**
- `job` - Promtail job name
- `container_name` - Docker container name
- `service` - Service name from compose
- `level` - Log level (info, warn, error) if parsed

### Promtail

**Purpose:** Log collection agent that ships logs to Loki

**Key Features:**
- Scrapes Docker container logs
- Applies labels to logs
- Parses structured logs (JSON)
- Sends to Loki for storage

**Configuration:**
- Config: `monitoring/promtail/config.yml`
- Source: Docker socket (`/var/run/docker.sock`)
- Targets: All containers with Docker labels

**How It Works:**

```
Docker Containers
    ↓
Promtail (reads /var/run/docker.sock)
    ↓
Loki (stores logs with labels)
    ↓
Grafana (queries and displays)
```

### Uptime Kuma

**Purpose:** Uptime monitoring and status page

**Key Features:**
- Monitor HTTP(S), TCP, Ping, DNS, etc.
- Multi-user support
- Status pages (public or private)
- Notifications (email, Slack, Discord, etc.)

**Access:**
- Web UI: `https://status.local` (protected by Authelia)

**Monitors to Configure:**

**CoreSrv Services:**
- Jellyfin (https://jellyfin.local)
- Jellyseerr (https://requests.local)
- Nextcloud (https://cloud.local)
- SearXNG (https://search.local)
- Grafana (https://grafana.local)
- Homepage (https://home.local)

**Pi DNS Services:**
- Pi-hole web UI
- DNS resolution (DNS query check)
- Unbound status

**Pi NetSec Services:**
- Orion Sentinel UI
- Metrics endpoint

**External Checks:**
- Internet connectivity (1.1.1.1, 8.8.8.8)
- Public DNS resolution

## Monitoring Flow

```
┌─────────────┐  Metrics   ┌────────────┐  Scrape   ┌─────────────┐
│  Exporters  │───────────>│ Prometheus │<──────────│  Grafana    │
│ (all nodes) │            │            │  Query    │ Dashboards  │
└─────────────┘            └────────────┘           └─────────────┘

┌─────────────┐   Logs     ┌────────────┐  Query    ┌─────────────┐
│  Containers │───────────>│   Loki     │<──────────│  Grafana    │
│ (CoreSrv)   │ Promtail   │            │           │ Log Viewer  │
└─────────────┘            └────────────┘           └─────────────┘

┌─────────────┐  HTTP/Ping ┌────────────┐  View     ┌─────────────┐
│  Services   │───────────>│ Uptime Kuma│───────────│ Status Page │
│ (all nodes) │  Checks    │            │           │             │
└─────────────┘            └────────────┘           └─────────────┘
```

## Initial Setup

### 1. Start Monitoring Stack

```bash
docker compose --profile monitoring up -d
```

### 2. Configure Prometheus Targets

Edit `monitoring/prometheus/prometheus.yml`:

```yaml
scrape_configs:
  # CoreSrv node exporter (add this first)
  - job_name: 'coresrv-node'
    static_configs:
      - targets: ['node-exporter:9100']
        labels:
          node: 'coresrv'

  # CoreSrv Docker containers
  - job_name: 'coresrv-cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']
        labels:
          node: 'coresrv'

  # Traefik metrics
  - job_name: 'traefik'
    static_configs:
      - targets: ['traefik:8082']

  # Pi DNS node (add after setting up exporters on Pi)
  - job_name: 'pi-dns-node'
    static_configs:
      - targets: ['192.168.1.10:9100']  # Adjust IP
        labels:
          node: 'pi-dns'

  # Pi-hole exporter
  - job_name: 'pihole'
    static_configs:
      - targets: ['192.168.1.10:9617']  # Adjust IP
        labels:
          node: 'pi-dns'

  # Add more targets as needed
```

Reload Prometheus:

```bash
docker compose restart prometheus
```

### 3. Access Grafana

1. Navigate to `https://grafana.local`
2. Login with admin credentials (from `.env.monitoring`)
3. Verify datasources are configured (should be auto-provisioned)

### 4. Import Dashboards

In Grafana:
1. Go to Dashboards → Import
2. Enter dashboard ID (e.g., 1860 for Node Exporter Full)
3. Select Prometheus datasource
4. Click "Import"

Repeat for all recommended dashboards.

### 5. Configure Uptime Kuma

1. Navigate to `https://status.local`
2. Create admin account (first time only)
3. Add monitors (see list above)
4. Configure notifications (Settings → Notifications)
5. (Optional) Create status page for sharing

## Querying Metrics (PromQL)

### Useful Prometheus Queries

**CPU Usage by Container:**
```promql
rate(container_cpu_usage_seconds_total{name!=""}[5m]) * 100
```

**Memory Usage by Container:**
```promql
container_memory_usage_bytes{name!=""} / 1024 / 1024
```

**Disk Usage:**
```promql
(node_filesystem_size_bytes - node_filesystem_free_bytes) / node_filesystem_size_bytes * 100
```

**Network I/O:**
```promql
rate(node_network_receive_bytes_total[5m])
rate(node_network_transmit_bytes_total[5m])
```

**HTTP Request Rate (Traefik):**
```promql
rate(traefik_service_requests_total[5m])
```

## Querying Logs (LogQL)

### Useful Loki Queries

**All logs from Jellyfin:**
```logql
{container_name="jellyfin"}
```

**Error logs across all containers:**
```logql
{job="docker"} |= "error"
```

**Logs from media services:**
```logql
{container_name=~"sonarr|radarr|jellyfin"}
```

**Filter by time and parse JSON:**
```logql
{container_name="authelia"} | json | level="error"
```

## Alerting (TODO)

Future setup for alerting:

1. **Prometheus Alertmanager:**
   - Disk space < 10%
   - Service down > 5 minutes
   - High CPU/RAM usage

2. **Grafana Alerts:**
   - Dashboard-based alerts
   - Notifications to email, Slack, etc.

3. **Uptime Kuma Notifications:**
   - Already built-in
   - Configure in UI per monitor

## Troubleshooting

### Prometheus Not Scraping Targets

```bash
# Check Prometheus logs
docker compose logs prometheus

# Check target status in UI
# Navigate to https://prometheus.local/targets

# Common issues:
# - Exporter not running
# - Incorrect IP/port
# - Firewall blocking
```

### Grafana Dashboards Not Loading Data

```bash
# Check datasource connection
# Grafana → Configuration → Data Sources → Test

# Verify Prometheus has data
# https://prometheus.local/graph
# Query: up

# Check time range in dashboard (upper-right corner)
```

### Loki Not Receiving Logs

```bash
# Check Promtail logs
docker compose logs promtail

# Verify Promtail can reach Loki
docker compose exec promtail wget -O- http://loki:3100/ready

# Check Loki logs
docker compose logs loki
```

### High Disk Usage

```bash
# Check Prometheus data size
du -sh /srv/orion-sentinel-core/monitoring/prometheus/

# Reduce retention in .env.monitoring
PROMETHEUS_RETENTION_TIME=7d

# Restart Prometheus
docker compose restart prometheus
```

## TODO

- [ ] Add node_exporter and cAdvisor to CoreSrv
- [ ] Configure Prometheus scrape jobs for Pi DNS and Pi NetSec
- [ ] Import recommended Grafana dashboards
- [ ] Set up Alertmanager for critical alerts
- [ ] Configure Uptime Kuma monitors for all services
- [ ] Create custom dashboard for 3-node overview
- [ ] Set up notification channels (email, Slack)
- [ ] Configure log retention policies
- [ ] Add alert rules for disk space, memory, CPU
- [ ] Document backup procedure for Grafana dashboards

## References

- Prometheus: https://prometheus.io/docs/
- Grafana: https://grafana.com/docs/
- Loki: https://grafana.com/docs/loki/
- Promtail: https://grafana.com/docs/loki/latest/clients/promtail/
- Uptime Kuma: https://github.com/louislam/uptime-kuma
- PromQL Cheat Sheet: https://promlabs.com/promql-cheat-sheet/
- LogQL Cheat Sheet: https://grafana.com/docs/loki/latest/logql/

---

**Last Updated:** 2025-11-23  
**Maintained By:** Orion Home Lab Team
