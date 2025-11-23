# Orion Sentinel Home Lab Topology

## Overview

The Orion Sentinel home lab consists of multiple nodes working together to provide comprehensive DNS, security monitoring, media services, and observability. The CoreSrv (Dell mini-PC) acts as the central **Single Pane of Glass (SPoG)** that can operate standalone or integrate with external Pi nodes.

## Deployment Modes

### Standalone Mode

In standalone mode, only the CoreSrv runs on the Dell mini-PC. This provides:

**Core Services:**
- **Traefik**: Reverse proxy with automatic HTTPS
- **Authelia**: Single Sign-On (SSO) authentication for all services
- **Loki**: Centralized log aggregation
- **Promtail**: Log collection from Docker containers
- **Prometheus**: Metrics collection and time-series database
- **Grafana**: Visualization and dashboards
- **Uptime Kuma**: Service uptime monitoring
- **Node Exporter**: Host-level metrics (CPU, RAM, disk, network)
- **cAdvisor**: Docker container metrics

**Application Services:**
- **Media Stack**: Jellyfin, Sonarr, Radarr, Prowlarr, Bazarr, Jellyseerr, qBittorrent (with VPN)
- **Nextcloud**: Personal cloud storage and collaboration
- **SearXNG**: Privacy-respecting metasearch engine
- **Homepage**: Dashboard and service portal
- **Watchtower**: Automatic container updates
- **Autoheal**: Automatic container health recovery

**Access:**
All services are accessible via local `.local` domains through Traefik and protected by Authelia SSO.

**Limitations:**
- No external Pi monitoring
- No Pi-hole/Unbound metrics
- No network security monitoring from Suricata/IDS
- Prometheus will show Pi scrape targets as "down" (this is expected and tolerated)
- Traefik routes `dns.local` and `security.local` will return 503 Service Unavailable

### Integrated Mode

In integrated mode, the CoreSrv connects to and monitors external Raspberry Pi nodes:

**Additional Components:**

1. **DNS Pi (192.168.8.240)** - High-Availability DNS Stack
   - Pi-hole (primary and secondary): DNS filtering and ad blocking
   - Unbound (primary and secondary): Recursive DNS resolver
   - Keepalived: Virtual IP for HA failover
   - **Exporters for CoreSrv:**
     - `pihole_exporter` (port 9617): Pi-hole statistics
     - `unbound_exporter` (port 9167): Unbound DNS metrics
     - `node_exporter` (port 9100): Host metrics
   - **Log Shipping:**
     - Promtail sends Docker logs to CoreSrv Loki

2. **NetSec Pi (192.168.8.241)** - Network Security Monitoring
   - Suricata: IDS/IPS for threat detection
   - AI Pipeline: Machine learning for anomaly detection
   - Custom NSM tools
   - **Exporters for CoreSrv:**
     - `node_exporter` (port 9100): Host metrics
   - **Log Shipping:**
     - Promtail sends Docker logs and security events to CoreSrv Loki

**Benefits of Integrated Mode:**
- Unified observability across all infrastructure
- Centralized dashboards in Grafana showing all nodes
- Log correlation across DNS, security, and application layers
- Remote Pi UI access via Traefik reverse proxy:
  - `https://dns.local` → DNS Pi admin interface
  - `https://security.local` → NetSec AI stack interface
- Complete home lab monitoring from single pane of glass

**Network Requirements:**
- CoreSrv and Pi nodes must be on the same LAN or connected via VPN/routing
- Firewall rules allowing CoreSrv to scrape Pi exporters (ports 9100, 9167, 9617)
- Loki port 3100 accessible from Pi nodes for log shipping (optional, can be LAN-only)

## Architecture Diagrams

### Standalone Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    CoreSrv (Dell mini-PC)                    │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Traefik + Authelia (SSO & Reverse Proxy)            │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Grafana    │  │  Prometheus  │  │     Loki     │      │
│  │ Dashboards   │  │   Metrics    │  │     Logs     │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Jellyfin   │  │  Nextcloud   │  │   SearXNG    │      │
│  │ Media Server │  │ Cloud Storage│  │    Search    │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  *arr Stack (Sonarr, Radarr, Prowlarr, etc.)         │  │
│  │  qBittorrent + VPN                                    │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Integrated Architecture

```
                    ┌─────────────────────────────────────┐
                    │     CoreSrv (Dell mini-PC)          │
                    │     Single Pane of Glass            │
                    │                                     │
                    │  ┌─────────────────────────────┐   │
                    │  │ Traefik + Authelia          │   │
                    │  │ Reverse Proxy + SSO         │   │
                    │  └─────────────────────────────┘   │
                    │                                     │
                    │  ┌──────────┐  ┌──────────┐       │
                    │  │Prometheus│  │  Loki    │       │
                    │  │  Scrapes │  │Aggregates│       │
                    │  │  Metrics │  │   Logs   │       │
                    │  └─────┬────┘  └────┬─────┘       │
                    │        │            │             │
                    │  ┌─────▼────────────▼─────┐       │
                    │  │      Grafana            │       │
                    │  │   Unified Dashboards    │       │
                    │  └─────────────────────────┘       │
                    │                                     │
                    │  + Media Stack, Cloud, Search...   │
                    └─────────────────────────────────────┘
                            ▲              ▲
                            │              │
                    Metrics & Logs    Metrics & Logs
                            │              │
                            │              │
        ┌───────────────────┴──┐       ┌──┴─────────────────┐
        │   DNS Pi (8.240)     │       │ NetSec Pi (8.241)  │
        │                      │       │                    │
        │  ┌────────────────┐  │       │  ┌──────────────┐ │
        │  │ Pi-hole        │  │       │  │ Suricata IDS │ │
        │  │ Unbound        │  │       │  │ AI Pipeline  │ │
        │  │ Keepalived HA  │  │       │  │ NSM Tools    │ │
        │  └────────────────┘  │       │  └──────────────┘ │
        │                      │       │                    │
        │  Exporters:          │       │  Exporters:        │
        │  - pihole_exporter   │       │  - node_exporter   │
        │  - unbound_exporter  │       │                    │
        │  - node_exporter     │       │  Promtail → CoreSrv│
        │                      │       │                    │
        │  Promtail → CoreSrv  │       │                    │
        └──────────────────────┘       └────────────────────┘
```

## Service Ports

### CoreSrv Services

| Service         | Internal Port | External Port | Protocol | Access          |
|-----------------|---------------|---------------|----------|-----------------|
| Traefik (HTTP)  | 80            | 80            | HTTP     | Redirect to 443 |
| Traefik (HTTPS) | 443           | 443           | HTTPS    | Public          |
| Prometheus      | 9090          | -             | HTTP     | Traefik reverse proxy |
| Grafana         | 3000          | -             | HTTP     | Traefik reverse proxy |
| Loki            | 3100          | 3100 (opt)    | HTTP     | Internal / LAN  |
| Node Exporter   | 9100          | 9100          | HTTP     | Host network    |
| cAdvisor        | 8080          | 8081          | HTTP     | Internal        |
| Authelia        | 9091          | -             | HTTP     | Traefik reverse proxy |

### DNS Pi Services (External)

| Service           | Port | Protocol | Scraped By      |
|-------------------|------|----------|-----------------|
| pihole_exporter   | 9617 | HTTP     | CoreSrv Prometheus |
| unbound_exporter  | 9167 | HTTP     | CoreSrv Prometheus |
| node_exporter     | 9100 | HTTP     | CoreSrv Prometheus |
| Promtail (Loki)   | 3100 | HTTP     | Pushes to CoreSrv Loki |

### NetSec Pi Services (External)

| Service           | Port | Protocol | Scraped By      |
|-------------------|------|----------|-----------------|
| node_exporter     | 9100 | HTTP     | CoreSrv Prometheus |
| Promtail (Loki)   | 3100 | HTTP     | Pushes to CoreSrv Loki |

## Switching Between Modes

### Running Standalone

Simply deploy CoreSrv without the Pi nodes:

```bash
# Start core services
./orionctl.sh up-core

# Start with monitoring
./orionctl.sh up-observability

# Start everything
./orionctl.sh up-full
```

Prometheus will show Pi targets as "down" - this is expected and does not affect CoreSrv operation.

### Enabling Integrated Mode

1. **Deploy DNS Pi** (separate repository: `rpi-ha-dns-stack`)
   - Deploy Pi-hole, Unbound, and exporters
   - Configure Promtail to push logs to CoreSrv Loki
   - See `agents/pi-dns/promtail-config.example.yml`

2. **Deploy NetSec Pi** (separate repository: `Orion-sentinel-netsec-ai`)
   - Deploy Suricata, AI pipeline, and exporters
   - Configure Promtail to push logs to CoreSrv Loki
   - See `agents/pi-netsec/promtail-config.example.yml`

3. **Configure Firewall** (on Pi nodes if using UFW)
   ```bash
   # Allow CoreSrv to scrape Prometheus exporters
   sudo ufw allow from <CORESRV_IP> to any port 9100
   sudo ufw allow from <CORESRV_IP> to any port 9167
   sudo ufw allow from <CORESRV_IP> to any port 9617
   ```

4. **Verify Connectivity**
   - Check Prometheus targets: `https://prometheus.local/targets`
   - Check Grafana for Pi metrics: `https://grafana.local`
   - Check Loki for Pi logs: Explore → Loki → `{host="pi-dns"}`

## Data Flow

### Metrics Collection

```
Pi Exporters → Prometheus (CoreSrv) → Grafana (CoreSrv) → User
     ↓                                        ↑
  :9100, :9167, :9617              Query via PromQL
```

### Log Aggregation

```
Pi Promtail → Loki (CoreSrv) → Grafana (CoreSrv) → User
     ↓                                    ↑
  Push :3100                    Query via LogQL
```

### Service Access

```
User → Traefik (CoreSrv) → Authelia SSO → Service
                    ↓
                dns.local → DNS Pi (if deployed)
                security.local → NetSec Pi (if deployed)
```

## Troubleshooting

### Standalone Mode Issues

**Problem**: Prometheus shows Pi targets as down
- **Solution**: This is expected. Pi targets are optional external dependencies.

**Problem**: `dns.local` or `security.local` return 503 errors
- **Solution**: This is expected when Pi nodes are not deployed. Routes are configured but backends are unavailable.

### Integrated Mode Issues

**Problem**: Prometheus cannot scrape Pi targets
- **Check**: Network connectivity: `ping 192.168.8.240`
- **Check**: Firewall rules on Pi nodes
- **Check**: Exporters are running on Pi: `curl http://192.168.8.240:9617/metrics`

**Problem**: No logs from Pi in Loki
- **Check**: Promtail is running on Pi: `docker ps | grep promtail`
- **Check**: Promtail can reach Loki: `curl http://<CORESRV_IP>:3100/ready`
- **Check**: Promtail logs: `docker logs promtail`

**Problem**: Cannot access `dns.local` or `security.local`
- **Check**: Pi nodes are reachable from CoreSrv
- **Check**: Pi services are running and accessible
- **Check**: DNS resolution for `*.local` domains

## References

- CoreSrv Setup Guide: `docs/SETUP-CoreSrv.md`
- Remote Logs Configuration: `docs/REMOTE-LOGS.md`
- Monitoring Stack Details: `monitoring/README.md`
- Backup and Restore: `docs/BACKUP-RESTORE.md`
- Runbooks: `docs/RUNBOOKS.md`

---

**Last Updated**: 2025-11-23  
**Maintained By**: Orion Home Lab Team
