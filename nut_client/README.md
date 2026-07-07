# NUT secondary client

Runs on client machines looking to shutdown via primary server messages

## Setup

```bash
cp .env.example .env        # setup env values
docker compose up -d --build
docker logs -f nut-client   # watch ONBATT / ONLINE / poweroff
```

## Env Values

* `PRIMARY_HOST` must be running `nut-upsd` and have port `3493/tcp` open
* `ONBATT_SHUTDOWN_DELAY` in `.env` is the on-battery shutoff timer
* `NUT_SECONDARY_PASSWORD` must match `[upssecondary]` defined in primary server's `upsd.users` file
* `SHUTDOWN_GRACE` seconds to wait before the host actually powers off (0 = immediate)
* `DRY_RUN` set `true` to log the shutdown instead of powering off the host (testing)
* `SHUTDOWN_PROFILE` selects *how* this client halts (see below)
* `DEBUG_LEVEL` is the `upsmon` log verbosity (0 off, 1 login/poll/state, 2+ noisy)

## Customizing the shutdown (different client types)

The actual halt is pluggable so different machines (a Linux NAS, a host that
needs services stopped first, an appliance shut down over SSH, ...) can each shut
down their own way without forking the image.

`SHUTDOWN_PROFILE` picks a **driver**, and optional `pre.sh`/`post.sh` **hooks**
run around it for quiescing. Bundled profiles: `default` (built-in `nsenter`
halt), `systemd`, `truenas`, `hexos`, `ssh`. To add your own, drop a `<name>.sh` defining
`do_shutdown` into [shutdown.d/](shutdown.d/) and set `SHUTDOWN_PROFILE=<name>`.

You can either edit `shutdown.d/` and rebuild (`docker compose up -d --build`),
or bind-mount your own dir over it (uncomment the `volumes:` block in
`docker-compose.yaml`). Full contract and examples in
[shutdown.d/README.md](shutdown.d/README.md).