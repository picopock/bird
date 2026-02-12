#!/bin/bash
set -euo pipefail

BIRD_CONF="/etc/bird/bird.conf"
BIRD_CTL="/var/run/bird/bird.ctl"
BIRD_EXAMPLE_CONF="/etc/bird/bird.conf.example"
BIRD_VERSION=${BIRD_VERSION:-3.0.1}

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [BIRD-${BIRD_VERSION}] $1"
}

trap 'log "Stopping BIRD gracefully..."; if birdc -s "${BIRD_CTL}" show status >/dev/null 2>&1; then birdc -s "${BIRD_CTL}" down 2>/dev/null; fi; exit 0' SIGTERM SIGINT SIGQUIT

if [ ! -f "${BIRD_CONF}" ]; then
    log "WARNING: ${BIRD_CONF} not found, using example config"
    cp "${BIRD_EXAMPLE_CONF}" "${BIRD_CONF}"
    cat >> "${BIRD_CONF}" << EOF

control socket "${BIRD_CTL}" allow localhost;
log syslog all;
EOF
fi

log "Checking BIRD config syntax"
if ! bird -c "${BIRD_CONF}" -p; then
    log "ERROR: BIRD config syntax error! Check ${BIRD_CONF}"
    exit 1
fi

log "Starting BIRD (user: $(id -un))"
exec bird -c "${BIRD_CONF}" -f -s "${BIRD_CTL}"