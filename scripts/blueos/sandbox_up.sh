#!/usr/bin/env bash
# Raise BlueOS and the operator's extensions in the session sandbox
# (TABOO 0.029): every module we write about the ROV is real BlueOS code,
# and BlueOS is brought up in each session and in the hourly cycle.
#
#     bash scripts/blueos/sandbox_up.sh            # core + extensions
#     bash scripts/blueos/sandbox_up.sh --status   # only probe and log
#
# The sandbox has no IPv6, so the core's nginx dies on "listen [::]";
# the script drops those lines inside the container, and run-service
# restarts nginx by itself.  Extensions are run from local images when
# they exist (built from their own repos), so a Docker Hub rate limit on
# the core never stops a module from being checked.
set -u

CORE_IMAGE="${BLUEOS_CORE_IMAGE:-bluerobotics/blueos-core:1.4.0}"
STATE=/tmp/blueos
LOG_DIR="$(cd "$(dirname "$0")/../.." && pwd)/build/blueos"
LOG="$LOG_DIR/sandbox_up_$(date -u +%Y-%m-%d).log"
# Extension name, local image and host port, one per line.
EXTENSIONS="tides leonidy431/tides:dev 9050
volumetric leonidy431/volumetric-display:dev 9060"

mkdir -p "$LOG_DIR" "$STATE"/{config,logs,etc,usr_blueos}
say() { echo "$(date -u +%H:%M:%SZ) $*" | tee -a "$LOG"; }

# Docker's daemon is not started by the sandbox image itself.
if ! docker version >/dev/null 2>&1; then
    (dockerd >"$STATE/dockerd.log" 2>&1 &)
    for _ in $(seq 1 30); do
        docker version >/dev/null 2>&1 && break
        sleep 1
    done
fi
docker version >/dev/null 2>&1 || { say "dockerd did not start"; exit 1; }

if [ "${1:-}" != "--status" ]; then
    if ! docker image inspect "$CORE_IMAGE" >/dev/null 2>&1; then
        say "pulling $CORE_IMAGE"
        docker pull "$CORE_IMAGE" >>"$LOG" 2>&1 \
            || say "core pull failed (rate limit or disk); extensions only"
    fi
    if docker image inspect "$CORE_IMAGE" >/dev/null 2>&1 \
        && [ -z "$(docker ps -q -f name=^blueos-core$)" ]; then
        docker rm -f blueos-core >/dev/null 2>&1
        docker run -d --name blueos-core --network host --privileged \
            -v /var/run/docker.sock:/var/run/docker.sock \
            -v "$STATE/config:/root/.config" \
            -v "$STATE/logs:/var/logs/blueos" \
            -v "$STATE/etc:/etc/blueos" \
            -v "$STATE/usr_blueos:/usr/blueos" \
            "$CORE_IMAGE" >>"$LOG" 2>&1
        say "core started"
    fi
    while read -r name image port; do
        [ -z "$name" ] && continue
        if docker image inspect "$image" >/dev/null 2>&1; then
            docker rm -f "ext-$name" >/dev/null 2>&1
            docker run -d --name "ext-$name" --restart unless-stopped \
                -p "$port:$port" "$image" >>"$LOG" 2>&1
            say "extension $name started on $port"
        else
            say "extension $name: no local image $image (build it from"
            say "  its repo first); skipped"
        fi
    done <<<"$EXTENSIONS"
fi

# nginx needs the IPv6 listens removed every time the core starts.
if [ -n "$(docker ps -q -f name=^blueos-core$)" ]; then
    docker exec blueos-core sh -c "grep -rl 'listen \[::\]' \
        /home/pi/tools/nginx/ | xargs -r sed -i '/listen \[::\]/d'"
    for _ in $(seq 1 90); do
        curl -s -m 3 -o /dev/null http://127.0.0.1/ && break
        sleep 2
    done
    say "core UI: $(curl -s -m 5 -o /dev/null -w '%{http_code}' \
        http://127.0.0.1/)"
    say "core services: $(curl -s -m 10 \
        http://127.0.0.1/helper/v1.0/web_services \
        | python3 -c 'import json,sys; print(", ".join(
            s["title"] for s in json.load(sys.stdin)))' 2>/dev/null)"
fi
while read -r name image port; do
    [ -z "$name" ] && continue
    say "extension $name register_service: $(curl -s -m 5 \
        "http://127.0.0.1:$port/register_service" | head -c 300)"
done <<<"$EXTENSIONS"
say "log: $LOG"
