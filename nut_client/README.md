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
* `DEBUG_LEVEL` is the `upsmon` log verbosity (0 off, 1 login/poll/state, 2+ noisy)