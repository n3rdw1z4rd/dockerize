#!/usr/bin/env bash
# End-to-end with a real Docker daemon: deploy a fixture, hit it, check status, clean up.
# Run: tests/docker.sh   (uses host port 6666 and leaves nothing behind)
set -euo pipefail
cd "$(dirname "$0")/.."
D="$PWD/dockerize"
F="$PWD/tests/fixtures/custom-dockerfile"
trap '"$D" clean -C "$F" >/dev/null 2>&1 || true' EXIT

"$D" deploy -C "$F"
curl -fsS "http://localhost:6666/" | grep -qi nginx && echo "ok   served on :6666"
"$D" status -C "$F" | grep -q 'custom' && echo "ok   status lists it"
"$D" restart -C "$F" && echo "ok   restart"
"$D" stop -C "$F" && ! docker ps -q --filter name=^custom$ | grep -q . && echo "ok   stop"
"$D" clean -C "$F" && ! docker images -q custom | grep -q . && echo "ok   clean"
