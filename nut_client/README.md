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