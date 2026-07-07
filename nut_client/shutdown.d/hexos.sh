# SHUTDOWN_PROFILE=hexos — clean power-off for a HexOS NAS host.
#
# HexOS is TrueNAS SCALE-based (Debian + systemd + OpenZFS), so the halt itself
# is the same as `truenas`/`systemd`. The HexOS-specific part is quiescing:
# apps run as plain Docker containers (not jails/k3s), so stopping them and
# letting ZFS pools flush belongs in pre.sh, e.g.:
#   nsenter -t 1 -m -u -i -n -p -- docker stop $(nsenter -t 1 -m -u -i -n -p -- docker ps -q)
#   nsenter -t 1 -m -u -i -n -p -- sync
# `-p` powers the machine off rather than halting it.
do_shutdown() {
  reason="$1"
  nsenter -t 1 -m -u -i -n -p -- /sbin/shutdown -p now
}
