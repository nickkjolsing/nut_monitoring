# SHUTDOWN_PROFILE=ssh — shut down a REMOTE host over SSH.
#
# Use this when the target can't run this container itself (a locked-down
# appliance NAS, a switch, etc.). Run the nut-client container anywhere that can
# reach both the NUT primary and the target; pid:host/privileged are NOT needed
# for this profile.
#
# Requires the `openssh-client` package in the image and these env vars in .env:
#   SSH_TARGET   user@host of the machine to power off       (required)
#   SSH_KEY      path to a mounted private key               (default /etc/nut/ssh_key)
#   SSH_PORT     ssh port                                    (default 22)
#   SSH_CMD      command to run on the target                (default: sudo poweroff)
#
# Mount the key read-only, e.g. in docker-compose volumes:
#   - ./id_nut:/etc/nut/ssh_key:ro
do_shutdown() {
  reason="$1"
  target="${SSH_TARGET:?SSH_TARGET not set}"
  key="${SSH_KEY:-/etc/nut/ssh_key}"
  port="${SSH_PORT:-22}"
  cmd="${SSH_CMD:-sudo poweroff}"
  /etc/nut/nutlog crit shutdown "ssh poweroff" "target=$target" "reason=$reason"
  ssh -i "$key" -p "$port" \
      -o BatchMode=yes -o StrictHostKeyChecking=accept-new \
      -o ConnectTimeout=10 \
      "$target" "$cmd"
}
