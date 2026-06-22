#! /bin/sh -e

# Generates the NUT client config + helper scripts, then runs upsmon.
# All logs we emit use logfmt via /etc/nut/nutlog, e.g.:
#   nut-client level=warn event=onbatt msg="on battery" host=ups@host delay=300s

mkdir -p /run/nut && chown nut:nut /run/nut

# --- logfmt helper: nutlog <level> <event> <msg> [key=val ...] ---------------
cat > /etc/nut/nutlog <<'EOF'
#! /bin/sh
level=$1; event=$2; msg=$3; shift 3
extra=
[ "$#" -gt 0 ] && extra=" $*"
printf 'nut-client level=%s event=%s msg="%s"%s\n' "$level" "$event" "$msg" "$extra"
EOF
chmod +x /etc/nut/nutlog

# --- shutdown action (shared by the FSD path and the on-battery timer) --------
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

# --- NOTIFYCMD: log every upsmon event (logfmt), then hand off to upssched ----
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
exec /usr/sbin/upssched
EOF
chmod +x /etc/nut/notify.sh

# --- upssched CMDSCRIPT: timer name arrives as $1 -----------------------------
cat > /etc/nut/upssched-cmd.sh <<'EOF'
#! /bin/sh
case "$1" in
  onbatt) /etc/nut/poweroff.sh onbatt ;;
  tick-*) /etc/nut/nutlog info countdown "on battery" "remaining=${1#tick-}s" ;;
  *)      /etc/nut/nutlog info timer "${1:-unknown}" ;;
esac
EOF
chmod +x /etc/nut/upssched-cmd.sh

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

# --- on-battery timers: real shutdown + every-30s countdown milestones --------
# Milestones are derived from ONBATT_SHUTDOWN_DELAY so they always track .env
{
  echo "CMDSCRIPT /etc/nut/upssched-cmd.sh"
  echo "PIPEFN /run/nut/upssched.pipe"
  echo "LOCKFN /run/nut/upssched.lock"
  echo "AT ONBATT * START-TIMER onbatt ${ONBATT_SHUTDOWN_DELAY:-300}"
  echo "AT ONLINE * CANCEL-TIMER onbatt"
  delay=${ONBATT_SHUTDOWN_DELAY:-300}
  t=30
  while [ "$t" -lt "$delay" ]; do
    remaining=$((delay - t))
    echo "AT ONBATT * START-TIMER tick-${remaining} ${t}"
    echo "AT ONLINE * CANCEL-TIMER tick-${remaining}"
    t=$((t + 30))
  done
} > /etc/nut/upssched.conf

chown root:nut /etc/nut/upsmon.conf /etc/nut/upssched.conf
chmod 640 /etc/nut/upsmon.conf /etc/nut/upssched.conf

# --- startup summary ----------------------------------------------------------
/etc/nut/nutlog info startup "nut-client starting" "host=ups@${PRIMARY_HOST}" \
  "delay=${ONBATT_SHUTDOWN_DELAY:-300}s" "grace=${SHUTDOWN_GRACE:-0}s" "dry_run=${DRY_RUN:-false}"
if [ "${DRY_RUN:-false}" != "true" ]; then
  /etc/nut/nutlog warn startup "DRY_RUN off, a real shutdown WILL power off this host"
fi

# DEBUG_LEVEL in .env (0 = off, 1 = login/poll/state, 2+ = protocol noise)
# upsmon takes repeated -D, so build "-DD.." from the level
debug=
level=0
while [ "$level" -lt "${DEBUG_LEVEL:-0}" ]; do
  debug="D$debug"
  level=$((level + 1))
done

exec upsmon -F ${debug:+-$debug}
