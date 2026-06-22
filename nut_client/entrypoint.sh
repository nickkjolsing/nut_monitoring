#! /bin/sh -e

# Creates poweroff script, creates nut conf files, changes permissions

mkdir -p /run/nut && chown nut:nut /run/nut

cat > /etc/nut/poweroff.sh <<'EOF'
#! /bin/sh
logger -t nut-client "power event '$1' -> powering off host"
nsenter -t 1 -m -u -i -n -p -- /sbin/shutdown -h now
EOF
chmod +x /etc/nut/poweroff.sh

cat > /etc/nut/upsmon.conf <<EOF
MONITOR ups@${PRIMARY_HOST} 1 upssecondary ${NUT_SECONDARY_PASSWORD} secondary
MINSUPPLIES 1
SHUTDOWNCMD "/etc/nut/poweroff.sh lowbatt"
NOTIFYCMD /usr/sbin/upssched
RUN_AS_USER root
POLLFREQ 5
POLLFREQALERT 5
NOTIFYFLAG ONBATT  SYSLOG+EXEC
NOTIFYFLAG ONLINE  SYSLOG+EXEC
NOTIFYFLAG LOWBATT SYSLOG
NOTIFYFLAG FSD     SYSLOG
NOTIFYFLAG COMMBAD SYSLOG
NOTIFYFLAG COMMOK  SYSLOG
NOTIFYFLAG NOCOMM  SYSLOG
EOF

# Timed shutdown: start a timer on battery, cancel it when power returns
cat > /etc/nut/upssched.conf <<EOF
CMDSCRIPT /etc/nut/poweroff.sh
PIPEFN /run/nut/upssched.pipe
LOCKFN /run/nut/upssched.lock
AT ONBATT * START-TIMER onbatt ${ONBATT_SHUTDOWN_DELAY:-300}
AT ONLINE * CANCEL-TIMER onbatt
EOF

chown root:nut /etc/nut/upsmon.conf /etc/nut/upssched.conf
chmod 640 /etc/nut/upsmon.conf /etc/nut/upssched.conf

exec upsmon -F
