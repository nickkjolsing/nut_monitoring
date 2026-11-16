# SHUTDOWN_PROFILE=truenas — clean power-off for a TrueNAS SCALE host.
#
# Asks the TrueNAS middleware to shut down (midclt), which stops apps and VMs
# and exports the pools before powering off, the same as the UI's Power → Shut
# Down. Newer SCALE releases take a reason argument and older ones don't, so
# both forms are tried, then a plain `systemctl poweroff` if midclt isn't there.
#
# Don't use `shutdown -p`: that's a BSD (TrueNAS CORE) flag. SCALE is Debian +
# systemd, whose shutdown rejects it.
do_shutdown() {
  reason="$1"
  host() { nsenter -t 1 -m -u -i -n -p -- "$@"; }
  if host sh -c 'command -v midclt' >/dev/null 2>&1; then
    if host midclt call system.shutdown "UPS: $reason" >/dev/null 2>&1 \
       || host midclt call system.shutdown >/dev/null 2>&1; then
      /etc/nut/nutlog crit shutdown "middleware shutdown requested" "reason=$reason"
      return 0
    fi
    /etc/nut/nutlog warn shutdown "midclt shutdown failed, using systemctl" "reason=$reason"
  fi
  host systemctl poweroff
}
