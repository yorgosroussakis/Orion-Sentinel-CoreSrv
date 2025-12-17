# Netdata Monitoring Stack

Real-time performance monitoring for the Orion-Sentinel-CoreSrv system.

## Overview

Netdata provides:
- 📊 **Real-time metrics** - 1-second granularity for all metrics
- 🐳 **Container monitoring** - Docker container resource usage
- 💻 **Host monitoring** - CPU, RAM, disk, network at host level
- 🔔 **Health alerts** - Built-in alerting for common issues
- 🌐 **Web dashboard** - Responsive UI accessible via Traefik
- 🔒 **Privacy-first** - No cloud dependency, data stays local

## Quick Start

### 1. Copy Environment File

```bash
cd stacks/observability/netdata
cp .env.example .env
nano .env
```

### 2. Configure

Edit `.env` and set:
- `NETDATA_HOSTNAME` - Hostname displayed in dashboard (e.g., `coresrv-netdata`)
- `NETDATA_DOMAIN` - Domain for access (e.g., `netdata.orion.lan`)

Optional: Configure Netdata Cloud (see [Netdata Cloud Setup](#netdata-cloud-optional))

### 3. Create Storage Directories

```bash
sudo mkdir -p /srv/orion/internal/observability/netdata/{config,lib,cache}
sudo chown -R 1000:1000 /srv/orion/internal/observability/netdata
```

### 4. Deploy

**Option A: Using deploy script (recommended)**
```bash
# From repository root
./scripts/deploy.sh netdata
```

**Option B: Using docker compose directly**
```bash
# Ensure networks exist first
docker network create orion_proxy 2>/dev/null || true
docker network create orion_observability 2>/dev/null || true

# Deploy Netdata
docker compose -f stacks/observability/netdata/compose.yml up -d
```

### 5. Access Netdata

Open in your browser:
```
https://netdata.orion.lan
```

Or edit the compose file using:
```bash
sudo nano /home/runner/work/Orion-Sentinel-CoreSrv/Orion-Sentinel-CoreSrv/stacks/observability/netdata/compose.yml
```

## URLs & Access

| Service | URL | Description |
|---------|-----|-------------|
| **Netdata Dashboard** | `https://netdata.orion.lan` | Main monitoring dashboard |
| **API** | `https://netdata.orion.lan/api/v1/info` | REST API endpoint |

## Features

### Host Metrics
- CPU usage per core
- Memory and swap usage
- Disk I/O and space
- Network traffic
- System load and processes

### Container Metrics
- Per-container CPU and memory
- Network traffic per container
- Disk I/O per container
- Container lifecycle events

### Built-in Alerts
- High CPU usage
- Low disk space
- Memory pressure
- Network saturation
- Container restarts

## Configuration

### Access Configuration Files

Configuration files are stored in:
```
/srv/orion/internal/observability/netdata/config/
```

To edit the main configuration:
```bash
sudo nano /srv/orion/internal/observability/netdata/config/netdata.conf
```

### Common Configuration Tasks

#### Adjust Metrics Retention

Edit `netdata.conf`:
```bash
sudo nano /srv/orion/internal/observability/netdata/config/netdata.conf
```

Find and modify:
```ini
[db]
    # Retention in seconds (3600 = 1 hour, 7200 = 2 hours)
    dbengine disk space = 256
    dbengine multihost disk space = 256
```

#### Disable Specific Collectors

To disable a collector (e.g., to reduce overhead):
```bash
sudo nano /srv/orion/internal/observability/netdata/config/python.d.conf
```

Set to `no` for collectors you don't need.

#### Configure Alerts

Custom alert configuration:
```bash
sudo nano /srv/orion/internal/observability/netdata/config/health_alarm_notify.conf
```

Restart after changes:
```bash
docker compose -f stacks/observability/netdata/compose.yml restart
```

## Netdata Cloud (Optional)

Netdata Cloud adds:
- ☁️ Remote access from anywhere
- 📱 Mobile access
- 👥 Team collaboration
- 🔔 Alert notifications (email, Slack, etc.)
- 📊 Multiple nodes in one dashboard

### Setup Netdata Cloud

1. **Sign up** at https://app.netdata.cloud (free for personal use)

2. **Get claim token**:
   - In Netdata Cloud, click "Add Nodes"
   - Select "Docker"
   - Copy the claim token

3. **Configure** in `.env`:
   ```bash
   sudo nano /home/runner/work/Orion-Sentinel-CoreSrv/Orion-Sentinel-CoreSrv/stacks/observability/netdata/.env
   ```
   
   Set:
   ```env
   NETDATA_CLAIM_TOKEN=your-token-here
   NETDATA_CLAIM_ROOMS=your-space-id-here
   ```

4. **Restart Netdata**:
   ```bash
   docker compose -f stacks/observability/netdata/compose.yml restart
   ```

5. **Verify** in Netdata Cloud - your node should appear in a few moments

### Disable Netdata Cloud

To disable cloud and keep Netdata local-only:

1. Edit `.env`:
   ```bash
   NETDATA_CLAIM_TOKEN=
   ```

2. Restart:
   ```bash
   docker compose -f stacks/observability/netdata/compose.yml restart
   ```

## Security

### Add Authentication (Recommended)

By default, Netdata is accessible via Traefik with security headers. To add authentication:

1. **Option A: Add Authelia middleware** (if Authelia is deployed)
   
   Edit the compose file:
   ```bash
   sudo nano /home/runner/work/Orion-Sentinel-CoreSrv/Orion-Sentinel-CoreSrv/stacks/observability/netdata/compose.yml
   ```
   
   Change the middleware line to:
   ```yaml
   - "traefik.http.routers.netdata.middlewares=security-headers@file,authelia@file"
   ```

2. **Option B: Basic Auth**
   
   Create htpasswd file:
   ```bash
   sudo apt-get install apache2-utils
   htpasswd -c /srv/orion/internal/appdata/traefik/dynamic/.htpasswd admin
   ```
   
   Add middleware in Traefik dynamic config.

### Network Security

- Netdata container connects to `orion_proxy` (for Traefik) and `orion_observability` networks
- Does not expose ports directly to host
- All access is via Traefik HTTPS

### Host Access Security

- All host mounts are **read-only**
- Docker socket is **read-only**
- Runs with minimal capabilities (`SYS_PTRACE`, `SYS_ADMIN`)
- Cannot modify host system or containers

## Monitoring & Alerts

### View Container Metrics

1. Open Netdata dashboard
2. Navigate to "Applications" → "Docker containers"
3. See per-container CPU, memory, network, disk usage

### View Host Metrics

1. Navigate to "System Overview"
2. See CPU, memory, disk, network for entire host

### Configure Custom Alerts

Create alert config:
```bash
sudo mkdir -p /srv/orion/internal/observability/netdata/config/health.d
sudo nano /srv/orion/internal/observability/netdata/config/health.d/custom.conf
```

Example alert:
```
alarm: high_cpu_usage
   on: system.cpu
   lookup: average -3m unaligned of user,system
   units: %
   every: 10s
   warn: $this > 80
   crit: $this > 95
   info: CPU usage is high
```

## Integration with Other Services

### Prometheus Integration

Netdata can export metrics to Prometheus (already running in Orion stack):

1. Edit Prometheus config:
   ```bash
   sudo nano /srv/orion/internal/observability/prometheus/prometheus.yml
   ```

2. Add Netdata scrape target:
   ```yaml
   scrape_configs:
     - job_name: 'netdata'
       metrics_path: '/api/v1/allmetrics'
       params:
         format: ['prometheus']
       static_configs:
         - targets: ['orion_netdata:19999']
   ```

3. Restart Prometheus:
   ```bash
   docker compose -f stacks/observability/stack.yaml restart prometheus
   ```

### Grafana Integration

Import Netdata metrics into Grafana:

1. Use Prometheus as data source (see above)
2. Import Netdata dashboard from Grafana.com
3. Dashboard ID: 14900 (Netdata System Overview)

## Troubleshooting

### Container Won't Start

Check logs:
```bash
docker compose -f stacks/observability/netdata/compose.yml logs
```

Common issues:
- **Permission denied**: Ensure storage directories exist and have correct ownership
  ```bash
  sudo chown -R 1000:1000 /srv/orion/internal/observability/netdata
  ```
- **Network not found**: Create networks:
  ```bash
  docker network create orion_proxy
  docker network create orion_observability
  ```

### Can't Access Dashboard

1. Check Netdata is running:
   ```bash
   docker compose -f stacks/observability/netdata/compose.yml ps
   ```

2. Check Traefik can reach it:
   ```bash
   curl -I http://localhost:19999
   ```

3. Check Traefik configuration:
   ```bash
   docker logs orion_traefik | grep netdata
   ```

4. Verify DNS:
   ```bash
   ping netdata.orion.lan
   ```

### High CPU/Memory Usage

1. Check collector status:
   ```bash
   docker exec orion_netdata netdatacli get-info
   ```

2. Disable unnecessary collectors (see [Configuration](#configuration))

3. Reduce metrics retention:
   ```ini
   [db]
       dbengine disk space = 128  # Reduce from default 256MB
   ```

### Metrics Not Showing

1. Verify Netdata can access Docker socket:
   ```bash
   docker exec orion_netdata ls -la /var/run/docker.sock
   ```

2. Check for errors in logs:
   ```bash
   docker compose -f stacks/observability/netdata/compose.yml logs | grep -i error
   ```

## Maintenance

### Update Netdata

1. Pull latest image:
   ```bash
   docker compose -f stacks/observability/netdata/compose.yml pull
   ```

2. Restart with new image:
   ```bash
   docker compose -f stacks/observability/netdata/compose.yml up -d
   ```

### Backup Configuration

```bash
# Backup Netdata config and data
sudo tar -czf netdata-backup-$(date +%Y%m%d).tar.gz \
  /srv/orion/internal/observability/netdata/
```

### Reset Netdata

To start fresh:
```bash
# Stop Netdata
docker compose -f stacks/observability/netdata/compose.yml down

# Remove data (WARNING: Deletes all historical metrics)
sudo rm -rf /srv/orion/internal/observability/netdata/{lib,cache}/*

# Keep config
# sudo rm -rf /srv/orion/internal/observability/netdata/config/*  # Optional

# Restart
docker compose -f stacks/observability/netdata/compose.yml up -d
```

## Resources

- **Official Documentation**: https://learn.netdata.cloud/docs
- **Docker Hub**: https://hub.docker.com/r/netdata/netdata
- **GitHub**: https://github.com/netdata/netdata
- **Community**: https://community.netdata.cloud

## Performance

Netdata resource usage (typical):
- **CPU**: 0.5-2% average
- **Memory**: 50-150MB
- **Disk**: 256MB for metrics (configurable)
- **Network**: Minimal (only for cloud sync if enabled)

## Next Steps

1. **Add Authentication**: Protect Netdata with Authelia or basic auth
2. **Configure Alerts**: Set up custom health alerts
3. **Integrate with Prometheus**: Export metrics for long-term storage
4. **Create Grafana Dashboards**: Visualize Netdata metrics in Grafana
5. **Enable Cloud** (optional): Access remotely via Netdata Cloud

---

**Need help?** Check the [main documentation](../../../docs/quality-gates.md) or [troubleshooting guide](../../../docs/RUNBOOKS.md).
