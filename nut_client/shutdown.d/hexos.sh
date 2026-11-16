# SHUTDOWN_PROFILE=hexos — clean power-off for a HexOS NAS host.
#
# HexOS is TrueNAS SCALE underneath, so it shuts down the same way as the
# `truenas` profile: through the TrueNAS middleware, which stops apps and VMs
# and exports the pools before powering off. See truenas.sh for the details and
# the fallbacks.
#
# Don't use `shutdown -p`: that's a BSD flag. SCALE is Debian + systemd, whose
# shutdown rejects it ("invalid option -- 'p'"), and on 2026-11-16 that left
# the NAS running on battery.
# Sourced by poweroff.sh, which sets driverdir.
. "${driverdir:-/etc/nut/shutdown.d}/truenas.sh"
