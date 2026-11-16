#! /bin/sh
# SHUTDOWNCMD for the primary upsmon (hardware mode). It runs inside the
# nut-upsd container, so it powers off the HOST through nsenter, which needs
# `pid: host` + `privileged: true` on the service (see README, "Primary
# shutdown"). A plain `/sbin/shutdown` doesn't exist in the container, and even
# if it did it would only stop the container.
#
# upsmon calls this once the UPS is critical (on battery + low battery, or FSD)
# and the secondaries have had HOSTSYNC seconds to log out. Steps:
#   1. tell the UPS to cut its output after ups.delay.shutdown seconds and
#      turn it back on when mains returns (shutdown.return). Without this, a
#      host that powered off stays off if the power comes back before the
#      battery runs flat: it never sees the power transition its BIOS
#      "restore on AC power loss" setting waits for.
#   2. power off the host with systemd.
# KILLPOWER=0 in the service's environment skips step 1.

log() { echo "nut-primary level=$1 event=$2 msg=\"$3\""; }
host() { nsenter -t 1 -m -u -i -n -p -- "$@"; }

# upsmon exits after calling this, and Docker restarts the container while the
# host is still going down. Don't re-send the UPS command each time: every
# shutdown.return restarts the UPS's off-delay countdown.
case "$(host systemctl is-system-running 2>/dev/null)" in
  stopping)
    log info shutdown "host is already shutting down"
    exit 0
    ;;
esac

# The MONITOR line holds the primary login, which is also allowed to send
# shutdown.return (instcmds in upsd.users).
read -r ups user pass <<EOF
$(awk '$1 == "MONITOR" { print $2, $4, $5; exit }' /etc/nut/upsmon.conf)
EOF

if [ "${KILLPOWER:-1}" = "1" ]; then
  delay=$(upsc "$ups" ups.delay.shutdown 2>/dev/null)
  if upscmd -u "$user" -p "$pass" "$ups" shutdown.return; then
    log crit killpower "UPS output goes off in ${delay:-?}s and comes back when mains returns"
  else
    log error killpower "shutdown.return failed; if mains returns before the battery is flat, hosts stay off"
  fi
fi

log crit shutdown "powering off the host"
host systemctl poweroff
