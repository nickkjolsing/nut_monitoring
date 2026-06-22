#! /bin/sh -e

# Generates the NUT client config + helper scripts, then runs upsmon.
# All logs we emit use logfmt via /etc/nut/nutlog, e.g.:
#   nut-client level=warn event=onbatt msg="on battery" host=ups@host delay=300s

mkdir -p /run/nut && chown nut:nut /run/nut

echo $$ > /run/nut/main.pid

# --- logfmt helper: nutlog <level> <event> <msg> [key=val ...] ---------------
cat > /etc/nut/nutlog <<'EOF'
#! /bin/sh
level=$1; event=$2; msg=$3; shift 3
extra=
[ "$#" -gt 0 ] && extra=" $*"
line=$(printf 'nut-client level=%s event=%s msg="%s"%s' "$level" "$event" "$msg" "$extra")
main=$(cat /run/nut/main.pid 2>/dev/null)
{ [ -n "$main" ] && echo "$line" >> "/proc/$main/fd/1" 2>/dev/null; } || echo "$line"
EOF
chmod +x /etc/nut/nutlog

# --- shutdown action (shared by the FSD path and the charge watcher) ----------
cat > /etc/nut/poweroff.sh <<'EOF'
#! /bin/sh
reason="${1:-unknown}"
# DRY_RUN=true → log instead of halting the host (testing)
if [ "${DRY_RUN:-false}" = "true" ]; then
  /etc/nut/nutlog warn dryrun "would power off host" "reason=$reason"
  exit 0
fi
# SHUTDOWN_GRACE → seconds to wait before the halt begins
grace="${SHUTDOWN_GRACE:-0}"
if [ "$grace" -gt 0 ] 2>/dev/null; then
  /etc/nut/nutlog crit shutdown "powering off host" "reason=$reason" "grace=${grace}s"
  sleep "$grace"
fi
/etc/nut/nutlog crit shutdown "halting now" "reason=$reason"
nsenter -t 1 -m -u -i -n -p -- /sbin/shutdown -h now
EOF
chmod +x /etc/nut/poweroff.sh

# --- NOTIFYCMD: log every upsmon event in logfmt ------------------------------
cat > /etc/nut/notify.sh <<'EOF'
#! /bin/sh
host="${UPSNAME:-?}"
case "$NOTIFYTYPE" in
  ONLINE)   /etc/nut/nutlog info online   "power restored"               "host=$host" ;;
  ONBATT)   /etc/nut/nutlog warn onbatt   "on battery"                   "host=$host" "delay=${ONBATT_SHUTDOWN_DELAY:-300}s" ;;
  LOWBATT)  /etc/nut/nutlog crit lowbatt  "battery critical (OB LB)"     "host=$host" ;;
  FSD)      /etc/nut/nutlog crit fsd      "forced shutdown from primary" "host=$host" ;;
  COMMOK)   /etc/nut/nutlog info comm     "communications established"   "host=$host" ;;
  COMMBAD)  /etc/nut/nutlog warn comm     "communications lost"          "host=$host" ;;
  NOCOMM)   /etc/nut/nutlog warn comm     "UPS unreachable"              "host=$host" ;;
  REPLBATT) /etc/nut/nutlog warn battery  "replace battery"              "host=$host" ;;
  SHUTDOWN) /etc/nut/nutlog crit shutdown "system shutdown in progress"  "host=$host" ;;
  *)        /etc/nut/nutlog info notify   "${NOTIFYTYPE:-unknown}"       "host=$host" ;;
esac
EOF
chmod +x /etc/nut/notify.sh

# --- charge watcher: starts the shutdown countdown once battery hits a % ------
# Polls the primary's battery.charge. While on battery, once charge drops to
# SHUTDOWN_START_CHARGE it starts an ONBATT_SHUTDOWN_DELAY countdown (logging
# every poll), then runs poweroff.sh. Power returning cancels it. The UPS's own
# LOWBATT/FSD path stays as a hard floor and can fire sooner.
cat > /etc/nut/charge-watch.sh <<'EOF'
#! /bin/sh
ups="ups@${PRIMARY_HOST}"
poll="${CHARGE_POLL:-30}"
threshold="${SHUTDOWN_START_CHARGE:-100}"
delay="${ONBATT_SHUTDOWN_DELAY:-300}"
deadline=0   # 0 = not counting; else epoch second to power off at
fired=0      # 1 = already triggered this outage (so DRY_RUN doesn't re-fire)

/etc/nut/nutlog info watch "charge watcher started" \
  "ups=$ups" "start_charge=${threshold}%" "delay=${delay}s" "poll=${poll}s"

while :; do
  sleep "$poll"
  status=$(upsc "$ups" ups.status 2>/dev/null)
  [ -z "$status" ] && continue   # can't reach upsd this cycle -> keep state, retry
  charge=$(upsc "$ups" battery.charge 2>/dev/null)
  case " $status " in *" OB "*) on_batt=1 ;; *) on_batt=0 ;; esac

  if [ "$on_batt" -eq 0 ]; then
    if [ "$deadline" -ne 0 ] || [ "$fired" -eq 1 ]; then
      /etc/nut/nutlog info online "power restored, shutdown countdown cancelled" "charge=${charge}%"
    fi
    deadline=0; fired=0
    continue
  fi

  [ "$fired" -eq 1 ] && continue   # already fired (DRY_RUN); wait for power to return

  if [ "$deadline" -eq 0 ]; then
    # not counting yet -> start the countdown once charge reaches the threshold
    if [ -n "$charge" ] && [ "$charge" -le "$threshold" ] 2>/dev/null; then
      deadline=$(( $(date +%s) + delay ))
      /etc/nut/nutlog warn threshold "battery ${charge}% <= ${threshold}%, starting shutdown countdown" \
        "charge=${charge}%" "delay=${delay}s"
    fi
    continue
  fi

  remaining=$(( deadline - $(date +%s) ))
  if [ "$remaining" -le 0 ]; then
    /etc/nut/poweroff.sh charge
    fired=1; deadline=0
  else
    /etc/nut/nutlog info countdown "on battery" "charge=${charge}%" "remaining=${remaining}s"
  fi
done
EOF
chmod +x /etc/nut/charge-watch.sh

cat > /etc/nut/upsmon.conf <<EOF
MONITOR ups@${PRIMARY_HOST} 1 upssecondary ${NUT_SECONDARY_PASSWORD} secondary
MINSUPPLIES 1
SHUTDOWNCMD "/etc/nut/poweroff.sh lowbatt"
NOTIFYCMD /etc/nut/notify.sh
RUN_AS_USER root
POLLFREQ 5
POLLFREQALERT 5
NOTIFYFLAG ONLINE   EXEC
NOTIFYFLAG ONBATT   EXEC
NOTIFYFLAG LOWBATT  EXEC
NOTIFYFLAG FSD      EXEC
NOTIFYFLAG COMMOK   EXEC
NOTIFYFLAG COMMBAD  EXEC
NOTIFYFLAG NOCOMM   EXEC
NOTIFYFLAG REPLBATT EXEC
NOTIFYFLAG SHUTDOWN EXEC
EOF

chown root:nut /etc/nut/upsmon.conf
chmod 640 /etc/nut/upsmon.conf

# --- startup summary ----------------------------------------------------------
/etc/nut/nutlog info startup "nut-client starting" "host=ups@${PRIMARY_HOST}" \
  "start_charge=${SHUTDOWN_START_CHARGE:-100}%" "delay=${ONBATT_SHUTDOWN_DELAY:-300}s" \
  "grace=${SHUTDOWN_GRACE:-0}s" "dry_run=${DRY_RUN:-false}"
if [ "${DRY_RUN:-false}" != "true" ]; then
  /etc/nut/nutlog warn startup "DRY_RUN off, a real shutdown WILL power off this host"
fi

# Background charge watcher (gates the on-battery countdown on battery %)
/etc/nut/charge-watch.sh &

# DEBUG_LEVEL in .env (0 = off, 1 = login/poll/state, 2+ = protocol noise)
# upsmon takes repeated -D, so build "-DD.." from the level
debug=
level=0
while [ "$level" -lt "${DEBUG_LEVEL:-0}" ]; do
  debug="D$debug"
  level=$((level + 1))
done

exec upsmon -F ${debug:+-$debug}
