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

<br>

## Prometheus

See the example at
[prometheus/prometheus_example.yaml](prometheus/prometheus_example.yaml)

<br>

## Simulated values

The included `Cyber_Power_Systems_EC850LCD_simulation.dev` file serves example metrics on a `TIMER` loop / outage scenario

* normal → on battery →
draining → **OB LB** (low battery) → recovery → back to baseline
