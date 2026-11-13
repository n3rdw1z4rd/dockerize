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

# Env files: variables reach the running container, .env files stay out of the image.
expect() { # expect <name> <command...>: prints ok, or fails the run
  local name=$1; shift
  if "$@"; then echo "ok   $name"; else echo "FAIL $name"; exit 1; fi
}
has() { grep -q "$2" <<<"$1"; }

E="$PWD/tests/fixtures/env-app"
OLD="$(mktemp -d)"
trap '"$D" clean -C "$F" >/dev/null 2>&1 || true; "$D" clean -C "$E" >/dev/null 2>&1 || true; "$D" clean -C "$OLD" >/dev/null 2>&1 || true; rm -rf "$OLD"' EXIT

"$D" deploy -C "$E" -e DEMO_EXTRA=from-cli
out="$(curl -fsS "http://localhost:6667/")"
expect "env file reaches the container"   has "$out" '"secret":"from-env-file"'
expect "-e reaches the container"         has "$out" '"extra":"from-cli"'
expect ".env kept out of the image"       has "$out" '"envInImage":false'
expect ".env.local kept out of the image" has "$out" '"envLocalInImage":false'
expect ".env.example still copied"        has "$out" '"exampleInImage":true'
expect "secret not in image history"      bash -c '! docker history --no-trunc env-app:latest | grep -q from-env-file'
"$D" restart -C "$E" >/dev/null && sleep 2
expect "variables survive restart"        has "$(curl -fsS "http://localhost:6667/")" '"secret":"from-env-file"'
"$D" clean -C "$E" >/dev/null

# Without envFile, nothing changes: .env is copied in as before (with a warning).
cp -r "$E/." "$OLD/"
node -e 'const f=process.argv[1],p=require(f);delete p.dockerize.envFile;p.name="env-app-old";require("fs").writeFileSync(f,JSON.stringify(p))' "$OLD/package.json"
warnings="$("$D" deploy -C "$OLD" 2>&1 >/dev/null)"
expect "warns about .env without envFile" has "$warnings" 'copied into the image'
expect ".env still copied without envFile (unchanged)" has "$(curl -fsS "http://localhost:6667/")" '"envInImage":true'
