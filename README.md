# Network UPS Tools (NUT) Monitoring

NUT server (`upsd`) with server/client shutdown + Prometheus exporter and Grafana dashboard for a **CyberPower EC850LCD**

Supports two modes:

- **Simulation** (default) → the `dummy-ups` driver replays the bundled `.dev`
  dump on a loop. No UPS hardware required
- **Hardware** → the `usbhid-ups` driver talks to a real USB UPS connected to server

<br>

## How to Setup and Use

1. Copy and adapt `.env.example` (choose sim or hw config)

2. Pick a mode in `docker-compose.yaml` under `nut-upsd` → `volumes`. Simulation mode is uncommented by default

3. *For server / client shutdown capability* → create the configs, then open `3493/tcp` inbound from the clients (not required for exporter capabilities):

   ```bash
   cd nut_server
   cp upsd.users.example  upsd.users     # add primary and client logins
   cp upsmon.conf.example upsmon.conf    # primary config
   ```

4. Bring up via Docker

5. Check it's working

   ```bash
   curl -s 'localhost:9199/ups_metrics?ups=ups'
   ```

<br>

> For real hardware, edit `ups.conf.hw` and set the `driver`, `vendorid`, and
`productid` for your UPS (`lsusb` / `nut-scanner -U`)

<br>

## Simulation and Hardware Configs

| | Simulation | Hardware |
|---|---|---|
| Driver config | `ups.conf.sim` (`dummy-ups`) | `ups.conf.hw` (`usbhid-ups`) |
| Selected by | uncomment Simulation block in `docker-compose.yaml` | uncomment Hardware block in `docker-compose.yaml` |
| USB passthrough | none | uncomment the `devices:` block |

<br>

## Clients

**On each client:** follow [nut_client/README.md](nut_client/README.md)

Different client types can halt their own way (a Linux NAS, a host that must stop
services first, an appliance shut down over SSH) via pluggable shutdown drivers +
hooks — see [nut_client/shutdown.d/README.md](nut_client/shutdown.d/README.md).

<br>

Test the forced-shutdown broadcast from the primary:

```bash
docker exec nut-upsd upsmon -c fsd         # broadcast FSD
docker logs -f nut-upsd                    # watch the primary's events
```

> The primary server itself won't shut down, it will just log by default. Controlled via `SHUTDOWNCMD` in 
[upsmon.conf.example](nut_server/upsmon.conf.example)

> **Connected clients will shut down** unless they set
`DRY_RUN=true` in their `.env` ([nut_client/README.md](nut_client/README.md))

> **With primary shutdown enabled (below), an FSD test powers off the primary
and cycles the UPS output**, which reboots everything plugged into it.

<br>

## Primary shutdown

`upsmon` runs inside the `nut-upsd` container, so a plain `/sbin/shutdown`
can't reach the host (it isn't even in the image). In hardware mode, point
`SHUTDOWNCMD` at [primary-shutdown.sh](nut_server/primary-shutdown.sh) and give
the service the host's pid namespace:

```yaml
# docker-compose.override.yaml
services:
  nut-upsd:
    pid: host
    privileged: true
    volumes:
      - ./primary-shutdown.sh:/etc/nut/local/primary-shutdown.sh:ro
      # ...plus the hardware-mode mounts
```

```
# upsmon.conf
SHUTDOWNCMD "/etc/nut/local/primary-shutdown.sh"
```

```
# upsd.users, under [upsmon]
instcmds = shutdown.return
```

When the UPS goes critical (on battery + LB, or FSD) and the clients have had
`HOSTSYNC` seconds to log out, the script:

1. sends `shutdown.return`, so the UPS cuts its output `offdelay` seconds later
   and turns it back on when mains returns. Without it, hosts that powered off
   stay off if the power comes back before the battery is flat. They need BIOS
   "restore on AC power loss" set to power on.
2. powers off the host via `nsenter … systemctl poweroff`.

Set `KILLPOWER=0` on the service to skip step 1.

[ups.conf.hw](nut_server/ups.conf.hw) sets when that happens: `ignorelb` with
`override.battery.charge.low = 20` makes LB (and so the primary's shutdown) come
at 20 % charge instead of the UPS's own 10 %, and `offdelay`/`ondelay` leave
time for the primary to power off before the output drops.

The image's entrypoint copies `/etc/nut/local/*` only on a container's first
start, so apply config changes with `docker compose up -d --force-recreate`.

<br>

## Prometheus

See the example at
[prometheus/prometheus_example.yaml](prometheus/prometheus_example.yaml)

<br>

## Simulated values

The included `Cyber_Power_Systems_EC850LCD_simulation.dev` file serves example metrics on a `TIMER` loop / outage scenario

* normal → on battery →
draining → **OB LB** (low battery) → recovery → back to baseline
