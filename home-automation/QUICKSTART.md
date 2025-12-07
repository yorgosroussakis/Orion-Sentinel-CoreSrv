# Home Automation Quick Setup Guide

## Prerequisites

- Docker and Docker Compose installed
- Orion-Sentinel-CoreSrv repository cloned
- Core services running (Traefik + Authelia)

## Optional Hardware

- **Zigbee USB Coordinator** (e.g., Sonoff Zigbee 3.0 USB Dongle Plus) - ~€20
- **P1 USB Cable** (for Dutch smart meters) - ~€15

## Quick Start (5 Minutes)

### 1. Configure Environment

```bash
# Copy example environment file
cp env/.env.home-automation.example env/.env.home-automation

# Edit configuration
vim env/.env.home-automation
```

**Minimal required settings**:
```bash
TZ=Europe/Amsterdam
CONFIG_ROOT=/srv/orion-sentinel-core/config
PUID=1000
PGID=1000
```

**If using Zigbee**:
```bash
ZIGBEE_DEVICE=/dev/ttyACM0  # Check with: ls -l /dev/ttyACM*
```

**If using DSMR Reader**:
```bash
DSMR_SERIAL_PORT=/dev/ttyUSB0  # Check with: ls -l /dev/ttyUSB*
DSMR_DB_PASSWORD=generate_random_password_here
DSMR_PASSWORD=choose_admin_password_here
```

### 2. Create Configuration Directories

```bash
# Create directories
sudo mkdir -p /srv/orion-sentinel-core/config/{homeassistant,mosquitto/config,zigbee2mqtt/data,mealie,dsmr}

# Copy Mosquitto config
sudo cp home-automation/mosquitto/mosquitto.conf.example \
  /srv/orion-sentinel-core/config/mosquitto/config/mosquitto.conf

# Copy Zigbee2MQTT config (if using Zigbee)
sudo cp home-automation/zigbee2mqtt/configuration.yaml.example \
  /srv/orion-sentinel-core/config/zigbee2mqtt/data/configuration.yaml

# Set ownership
sudo chown -R $USER:$USER /srv/orion-sentinel-core/config
```

### 3. Start Services

```bash
# Start all home automation services
docker compose --profile home-automation up -d

# Or start selectively (without Zigbee/DSMR)
docker compose up -d homeassistant mosquitto mealie

# Check status
docker compose ps
```

### 4. Access Services

| Service | URL | Initial Login |
|---------|-----|---------------|
| Home Assistant | https://ha.local | Create on first visit |
| Zigbee2MQTT | https://zigbee.local | No auth by default |
| Mealie | https://mealie.local | admin@local / changeme |
| DSMR Reader | https://energy.local | admin / admin |

**Note**: Add these to `/etc/hosts` on your client machine:
```bash
sudo bash -c 'cat >> /etc/hosts << EOF
192.168.x.x ha.local
192.168.x.x zigbee.local
192.168.x.x mealie.local
192.168.x.x energy.local
EOF'
```
(Replace `192.168.x.x` with your CoreSrv IP)

### 5. Initial Configuration

#### Home Assistant
1. Navigate to https://ha.local
2. Create admin account
3. Set location and timezone
4. Complete onboarding wizard
5. Go to Settings → Devices & Services → Add Integration → MQTT
6. Configure MQTT:
   - Broker: `mosquitto`
   - Port: `1883`
   - Leave user/pass empty (or use MQTT_USER/MQTT_PASSWORD if set)

#### Zigbee2MQTT (if using)
1. Navigate to https://zigbee.local
2. Click "Permit join (All)"
3. Put Zigbee device in pairing mode
4. Device appears in UI
5. Rename device with friendly name
6. Device auto-appears in Home Assistant

#### Mealie
1. Navigate to https://mealie.local
2. Log in: admin@local / changeme
3. **Change password immediately**
4. Create your household
5. Try importing a recipe (paste URL)

#### DSMR Reader (if using)
1. Connect P1 cable to smart meter
2. Navigate to https://energy.local
3. Log in: admin / admin
4. **Change password immediately**
5. Verify serial port settings
6. Wait for data (~5 minutes)

## Verify Everything Works

### Check Container Status
```bash
docker compose ps
# All containers should be "Up" or "Up (healthy)"
```

### Check Logs
```bash
# Home Assistant
docker compose logs homeassistant | tail -50

# Mosquitto
docker compose logs mosquitto | tail -50

# Zigbee2MQTT
docker compose logs zigbee2mqtt | tail -50
```

### Test MQTT
```bash
# Subscribe to all topics
docker compose exec mosquitto mosquitto_sub -h localhost -t '#' -v

# In another terminal, publish test message
docker compose exec mosquitto mosquitto_pub -h localhost -t test/message -m "Hello MQTT"
```

### Access Monitoring
- **Grafana**: https://grafana.local
  - Check for Home Assistant, MQTT metrics
- **Loki (via Grafana Explore)**: Filter by `{container_name="homeassistant"}`
- **Uptime Kuma**: https://status.local
  - Add monitors for new services

## Common Issues

### Container Won't Start
```bash
# Check logs
docker compose logs <service-name>

# Restart specific service
docker compose restart <service-name>

# Recreate service
docker compose up -d --force-recreate <service-name>
```

### Device Not Found (Zigbee/DSMR)
```bash
# List USB devices
ls -l /dev/ttyACM* /dev/ttyUSB*

# Check persistent device paths
ls -l /dev/serial/by-id/

# Update .env.home-automation with correct device path
# Then restart: docker compose restart zigbee2mqtt dsmr
```

### Can't Access Web UI
```bash
# Check Traefik is running
docker compose ps traefik

# Check Traefik logs
docker compose logs traefik | grep ha.local

# Verify DNS/hosts file
ping ha.local

# Check firewall
sudo ufw status
```

### MQTT Not Working
```bash
# Test broker directly
docker compose exec mosquitto mosquitto_sub -h localhost -t test -v

# Check Mosquitto logs
docker compose logs mosquitto

# Verify config
cat /srv/orion-sentinel-core/config/mosquitto/config/mosquitto.conf
```

## Next Steps

### Install HACS (Home Assistant Community Store)
```bash
docker compose exec homeassistant bash
wget -O - https://get.hacs.xyz | bash -
exit
docker compose restart homeassistant
```

Then in Home Assistant:
1. Settings → Devices & Services → Add Integration
2. Search "HACS"
3. Follow authentication

### Add Popular Integrations
- **System Monitor** - CPU, RAM, disk usage
- **Speedtest** - Internet speed
- **Weather** - OpenWeatherMap or Met.no
- **Google Cast** - Chromecast devices
- **Jellyfin** - Media player integration
- **Mobile App** - Presence detection, notifications

### Create Automations
Check `home-automation/README.md` for automation examples:
- Welcome home (lights, climate)
- Night mode (turn off lights)
- Energy alerts (high usage)
- Media notifications

### Configure Homepage Dashboard
```bash
# Copy example configs
sudo cp maintenance/homepage/services.yml.example \
  /srv/orion-sentinel-core/config/homepage/services.yml

sudo cp maintenance/homepage/widgets.yml.example \
  /srv/orion-sentinel-core/config/homepage/widgets.yml

sudo cp maintenance/homepage/bookmarks.yml.example \
  /srv/orion-sentinel-core/config/homepage/bookmarks.yml

# Restart Homepage
docker compose restart homepage
```

Navigate to https://home.local to see your dashboard!

## Resources

- **Home Automation README**: `home-automation/README.md`
- **Mealie Guide**: `home-automation/mealie/README.md`
- **DSMR Guide**: `home-automation/dsmr/README.md`
- **Environment Config**: `env/.env.home-automation.example`

## Support

If you encounter issues:
1. Check logs: `docker compose logs <service>`
2. Review documentation in `home-automation/` directory
3. Check official docs:
   - Home Assistant: https://www.home-assistant.io/docs/
   - Zigbee2MQTT: https://www.zigbee2mqtt.io/
   - Mealie: https://docs.mealie.io/

---

**Setup time**: ~5-10 minutes (without hardware setup)  
**First automation**: ~30 minutes  
**Full customization**: Ongoing adventure! 🚀
