# DNS Pi Exporters Deployment Guide

This directory contains example configurations for deploying Prometheus exporters on the DNS Pi (192.168.8.240).

## Overview

The exporters allow CoreSrv's Prometheus to scrape metrics from the DNS Pi services:

- **pihole_exporter**: Pi-hole DNS filtering statistics
- **unbound_exporter**: Unbound recursive DNS metrics
- **node_exporter**: Host-level metrics (CPU, RAM, disk, network)

## Prerequisites

1. **DNS Pi Stack Running**: Pi-hole and Unbound deployed via docker-compose
2. **Network Access**: CoreSrv must be able to reach DNS Pi on ports 9100, 9167, 9617
3. **Unbound Remote Control**: Unbound must have remote-control enabled (see below)

## Quick Start

### Step 1: Prepare Unbound Configuration

Unbound requires remote-control to be enabled for the exporter to scrape statistics.

Add to your Unbound configuration file (usually `unbound.conf`):

```yaml
server:
  # Enable extended statistics for detailed metrics
  extended-statistics: yes
  # Don't accumulate statistics over time
  statistics-cumulative: no

remote-control:
  # Enable remote control
  control-enable: yes
  # Listen on all interfaces (or 0.0.0.0 for Docker)
  control-interface: 0.0.0.0
  # Control port (default 8953)
  control-port: 8953
  
  # For TLS (recommended):
  # Generate certs with: unbound-control-setup
  # server-key-file: "/etc/unbound/unbound_server.key"
  # server-cert-file: "/etc/unbound/unbound_server.pem"
  # control-key-file: "/etc/unbound/unbound_control.key"
  # control-cert-file: "/etc/unbound/unbound_control.pem"
```

Alternatively, use Unix socket (simpler):

```yaml
remote-control:
  control-enable: yes
  control-interface: /run/unbound.ctl
```

Restart Unbound after configuration changes:
```bash
docker-compose restart unbound_primary
```

### Step 2: Add Exporters to docker-compose.yml

Copy the service definitions from `exporters-docker-compose.example.yml` to your DNS Pi's `docker-compose.yml` file.

**Important**: Adjust the following to match your setup:

1. **Network names**: Replace `dns_net` with your actual Docker network name
2. **Container names**: Replace `pihole_primary`, `pihole_secondary`, `unbound_primary` with your actual names
3. **Pi-hole password**: Set `PIHOLE_PASSWORD` environment variable or use `PIHOLE_API_TOKEN`
4. **Unbound connection**: Choose TCP+TLS or Unix socket based on your Unbound setup
5. **Volume names**: Match your existing volume names for `unbound_config`, etc.

### Step 3: Deploy Exporters

From your DNS Pi docker-compose directory:

```bash
# Pull latest exporter images
docker-compose pull pihole_exporter unbound_exporter dns_node_exporter

# Start exporters
docker-compose up -d pihole_exporter unbound_exporter dns_node_exporter

# Check logs
docker-compose logs -f pihole_exporter
docker-compose logs -f unbound_exporter
docker-compose logs -f dns_node_exporter
```

### Step 4: Verify Metrics Endpoints

Test that metrics are being exported:

```bash
# Pi-hole metrics
curl http://localhost:9617/metrics

# Unbound metrics
curl http://localhost:9167/metrics

# Node metrics
curl http://localhost:9100/metrics
```

You should see Prometheus-formatted metrics output.

### Step 5: Configure Firewall (if using UFW)

Allow CoreSrv to scrape metrics:

```bash
# Replace <CORESRV_IP> with your CoreSrv IP address
sudo ufw allow from <CORESRV_IP> to any port 9100
sudo ufw allow from <CORESRV_IP> to any port 9167
sudo ufw allow from <CORESRV_IP> to any port 9617
```

### Step 6: Verify in CoreSrv Prometheus

1. Navigate to CoreSrv Prometheus: `https://prometheus.local/targets`
2. Look for `pi-dns` job
3. Targets should show as "UP"
4. If "DOWN", check:
   - Network connectivity: `ping 192.168.8.240`
   - Firewall rules
   - Exporter container status: `docker ps`

## Exporter Details

### pihole_exporter (Port 9617)

**Purpose**: Exports Pi-hole statistics for both primary and secondary instances

**Metrics include**:
- Queries per second
- Blocked queries percentage
- Domains on blocklist
- Cache statistics
- DNS query types

**Configuration**:
- Single exporter scrapes multiple Pi-hole instances
- Uses Pi-hole API with password/token authentication
- Scrapes every 15 seconds

### unbound_exporter (Port 9167)

**Purpose**: Exports Unbound recursive DNS resolver metrics

**Metrics include**:
- Query rate and types
- Cache hit/miss ratios
- Response times
- DNSSEC validation stats
- Memory usage
- Thread statistics

**Configuration**:
- Connects to Unbound control interface
- Supports TCP+TLS or Unix socket
- Requires extended-statistics enabled in Unbound

### node_exporter (Port 9100)

**Purpose**: Exports host-level metrics for the DNS Pi hardware

**Metrics include**:
- CPU usage and load average
- Memory usage (RAM, swap)
- Disk I/O and space
- Network traffic
- System uptime
- Temperature (Raspberry Pi specific)

**Configuration**:
- Runs in host network mode
- Mounts `/proc`, `/sys`, `/` for system access
- Standard Prometheus node_exporter

## Troubleshooting

### pihole_exporter Issues

**Problem**: Exporter shows "Authentication failed"
- **Solution**: Check `PIHOLE_PASSWORD` or `PIHOLE_API_TOKEN` is correct
- Verify Pi-hole web interface is accessible: `http://pihole_primary`

**Problem**: Only one Pi-hole being scraped
- **Solution**: Check `PIHOLE_HOSTNAME` includes both instances separated by comma
- Verify both Pi-hole containers are running and healthy

### unbound_exporter Issues

**Problem**: "Connection refused" errors
- **Solution**: Verify Unbound remote-control is enabled
- Check `control-interface` and `control-port` in Unbound config
- Ensure exporter can reach Unbound: `docker exec unbound_exporter ping unbound_primary`

**Problem**: TLS certificate errors
- **Solution**: Verify certificate paths in exporter command match Unbound config
- Regenerate certs with `unbound-control-setup` if needed
- Consider using Unix socket instead for simplicity

**Problem**: No metrics or empty response
- **Solution**: Verify `extended-statistics: yes` in Unbound config
- Restart Unbound after config changes
- Check Unbound logs: `docker logs unbound_primary`

### node_exporter Issues

**Problem**: Host metrics look wrong or missing
- **Solution**: Verify host network mode is used
- Check volume mounts for `/proc`, `/sys`, `/`
- Ensure `pid: host` is set

**Problem**: Permission denied errors
- **Solution**: Run container with appropriate privileges
- May need `--privileged` flag for some metrics (avoid if possible)

### General Issues

**Problem**: Prometheus can't scrape targets
- **Check network connectivity**: `ping 192.168.8.240` from CoreSrv
- **Check firewall**: Verify ports 9100, 9167, 9617 are allowed
- **Check DNS**: Ensure DNS Pi IP is correct in Prometheus config
- **Check exporter status**: `docker ps` on DNS Pi

**Problem**: Metrics show in Prometheus but no data
- **Check time range**: Metrics may take 15-30 seconds to appear
- **Check labels**: Verify Prometheus job labels match
- **Check retention**: Default is 7 days

## Example docker-compose.yml Integration

Here's how your complete DNS Pi `docker-compose.yml` might look:

```yaml
version: '3.8'

services:
  # Existing Pi-hole and Unbound services
  pihole_primary:
    # ... your Pi-hole config ...
  
  pihole_secondary:
    # ... your Pi-hole config ...
  
  unbound_primary:
    # ... your Unbound config ...
  
  # NEW: Exporters for Prometheus
  pihole_exporter:
    container_name: pihole_exporter
    image: ekofr/pihole-exporter:latest
    restart: unless-stopped
    depends_on:
      - pihole_primary
      - pihole_secondary
    networks:
      - dns_net
    ports:
      - "9617:9617"
    environment:
      PIHOLE_PROTOCOL: "http"
      PIHOLE_HOSTNAME: "pihole_primary,pihole_secondary"
      PIHOLE_PORT: "80"
      PIHOLE_PASSWORD: "${PIHOLE_WEBPASSWORD}"
      INTERVAL: "15s"
      PORT: "9617"
  
  unbound_exporter:
    container_name: unbound_exporter
    image: rsprta/unbound_exporter:latest
    restart: unless-stopped
    depends_on:
      - unbound_primary
    networks:
      - dns_net
    ports:
      - "9167:9167"
    command:
      - "-unbound.host=unix:///run/unbound.ctl"
      - "-web.listen-address=:9167"
    volumes:
      - unbound_run:/run
  
  dns_node_exporter:
    container_name: dns_node_exporter
    image: prom/node-exporter:latest
    restart: unless-stopped
    network_mode: "host"
    pid: "host"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--path.rootfs=/rootfs'

networks:
  dns_net:
    name: dns_net

volumes:
  unbound_run:
```

## Verification Checklist

- [ ] Unbound has `extended-statistics: yes` and `remote-control` enabled
- [ ] Exporters added to `docker-compose.yml` with correct network/container names
- [ ] Pi-hole password/token configured in exporter environment
- [ ] Exporters started: `docker-compose up -d`
- [ ] All exporters running: `docker ps | grep exporter`
- [ ] Metrics endpoints accessible locally (curl localhost:9100/9167/9617)
- [ ] Firewall allows CoreSrv to scrape (if using UFW)
- [ ] CoreSrv Prometheus shows targets as "UP" (https://prometheus.local/targets)
- [ ] Grafana shows metrics (https://grafana.local)

## Integration with CoreSrv

CoreSrv's Prometheus is already configured to scrape these exporters. The configuration in `monitoring/prometheus/prometheus.yml` includes:

```yaml
- job_name: "pi-dns"
  static_configs:
    - targets:
        - "192.168.8.240:9617" # pihole_exporter
        - "192.168.8.240:9167" # unbound_exporter
```

No changes needed on CoreSrv side - just deploy the exporters and they'll be automatically scraped.

## Grafana Dashboards

Recommended dashboards to import in CoreSrv Grafana:

1. **Pi-hole Exporter** (ID: 10176)
   - Complete Pi-hole statistics
   
2. **Unbound Exporter** (ID: 11705)
   - DNS resolver metrics
   
3. **Node Exporter Full** (ID: 1860)
   - Host metrics

Import via: Grafana → Dashboards → Import → Enter dashboard ID

## References

- Pi-hole Exporter: https://github.com/eko/pihole-exporter
- Unbound Exporter: https://github.com/letsencrypt/unbound_exporter
- Node Exporter: https://github.com/prometheus/node_exporter
- CoreSrv Documentation: `docs/REMOTE-LOGS.md`, `monitoring/README.md`
- Prometheus Configuration: `monitoring/prometheus/prometheus.yml`

---

**Last Updated**: 2025-11-23  
**For**: DNS Pi (192.168.8.240) - rpi-ha-dns-stack repository
