# SHUTDOWN_PROFILE=systemd — halt via systemd on the host.
# For hosts where you'd rather go through systemd than sysvinit's shutdown.
do_shutdown() {
  reason="$1"
  nsenter -t 1 -m -u -i -n -p -- systemctl poweroff
}
