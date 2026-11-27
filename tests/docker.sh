#!/usr/bin/env bash
# End-to-end with a real Docker daemon: deploy a fixture, hit it, check status, clean up.
# Then env files, and a compose project.
# Run: tests/docker.sh   (uses host ports 6666, 6667 and 6668, and leaves nothing behind)
set -euo pipefail
cd "$(dirname "$0")/.."
D="$PWD/dockerize"
F="$PWD/tests/fixtures/custom-dockerfile"
trap '"$D" clean -C "$F" >/dev/null 2>&1 || true' EXIT

expect() { # expect <name> <command...>: prints ok, or fails the run
  local name=$1; shift
  if "$@"; then echo "ok   $name"; else echo "FAIL $name"; exit 1; fi
}
has() { grep -q "$2" <<<"$1"; }
none() { [[ -z "$("$@")" ]]; } # none <command...>: it prints nothing
# (output is read whole, then searched: grep -q stops reading early, which pipefail counted as a failure)

"$D" deploy -C "$F"
expect "served on :6666"  has "$(curl -fsS "http://localhost:6666/")" 'nginx'
expect "status lists it"  has "$("$D" status -C "$F")" 'custom'
expect "restart"          "$D" restart -C "$F"
"$D" stop -C "$F" >/dev/null
expect "stop"             none docker ps -q --filter 'name=^custom$'
"$D" clean -C "$F" >/dev/null
expect "clean"            none docker images -q custom

# Env files: variables reach the running container, .env files stay out of the image.

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

# A compose project: deploy is docker compose up -d --build, run from the compose file's folder, and a rebuild
# leaves no old image of its own behind.
C="$PWD/tests/fixtures/compose-app"
trap '"$D" clean -C "$F" >/dev/null 2>&1 || true; "$D" clean -C "$E" >/dev/null 2>&1 || true; "$D" clean -C "$OLD" >/dev/null 2>&1 || true; rm -rf "$OLD"; sed -i "s/compose fixture, again/compose fixture/" "$C/Dockerfile"; "$D" clean -C "$C" >/dev/null 2>&1 || true' EXIT
"$D" clean -C "$OLD" >/dev/null 2>&1 || true
"$D" deploy -C "$C"
expect "compose: served on :6668"            has "$(curl -fsS "http://localhost:6668/")" 'compose fixture'
expect "compose: status lists its service"   has "$("$D" status -C "$C")" 'web'
sed -i 's/compose fixture/compose fixture, again/' "$C/Dockerfile"
"$D" update -C "$C"
expect "compose: update rebuilt it"          has "$(curl -fsS "http://localhost:6668/")" 'again'
expect "compose: no old image of its own left behind" none docker images -q --filter dangling=true --filter label=com.docker.compose.project=compose-app
expect "compose: restart"                    "$D" restart -C "$C"
"$D" stop -C "$C" >/dev/null
expect "compose: stop"                       none docker ps -q --filter label=com.docker.compose.project=compose-app
"$D" clean -C "$C" >/dev/null
expect "compose: clean"                      none docker images -q --filter label=com.docker.compose.project=compose-app
echo "all passed"
