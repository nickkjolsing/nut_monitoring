# Network UPS Tools (NUT) Monitoring

NUT server (`upsd`) + Prometheus exporter for a **CyberPower EC850LCD**

Supports two modes:

- **Simulation** (default) → the `dummy-ups` driver replays the bundled `.dev`
  dump on a loop. No UPS hardware required
- **Hardware** → the `usbhid-ups` driver talks to a real USB UPS connected to server

<br>

## How to Use

1. Copy and adapt `.env.example` (choose sim or hw config)


2. Pick a mode in `docker-compose.yaml` under `nut-upsd` → `volumes`. Simulation mode is uncommented by default.

3. Bring up via Docker

4. Check it's working

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

## Prometheus

See the example at
[prometheus/prometheus.yml](prometheus/prometheus.yaml)

<br>

## Simulated values

The included `.dev` serves example metrics on a `TIMER` loop / outage scenario

* normal → on battery →
draining → **OB LB** (low battery) → recovery → back to baseline
