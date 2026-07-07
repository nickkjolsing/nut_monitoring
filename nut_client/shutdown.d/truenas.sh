# SHUTDOWN_PROFILE=truenas — clean power-off for a TrueNAS / Linux NAS host.
#
# Quiescing (stopping VMs/jails/apps, exporting pools) belongs in pre.sh so it
# runs inside the abort/grace window; this driver just performs the final halt.
# `-p` powers the machine off rather than halting it.
do_shutdown() {
  reason="$1"
  nsenter -t 1 -m -u -i -n -p -- /sbin/shutdown -p now
}
