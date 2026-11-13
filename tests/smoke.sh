#!/usr/bin/env bash
# Smoke tests that need no Docker: settings detection, the generated files, and install / uninstall.
# Run: tests/smoke.sh
set -euo pipefail
cd "$(dirname "$0")/.."
D="$PWD/dockerize"
F="$PWD/tests/fixtures"
pass=0 fail=0
check() { # check <name> <command...>: passes if the command succeeds
  local name=$1; shift
  if "$@" >/dev/null 2>&1; then pass=$((pass + 1)); echo "ok   $name"
  else fail=$((fail + 1)); echo "FAIL $name"; fi
}
has() { grep -qE "$2" <<<"$1"; } # has <text> <regex>

cfg="$("$D" config -C "$F/static-app")"
check "static: name is docker-safe"   has "$cfg" 'name +demo-static-app'
check "static: mode detected"         has "$cfg" 'mode +static'
check "static: port from package"     has "$cfg" 'host port +5174'
check "static: named volume prefixed" has "$cfg" 'volumes +demo-static-app-data:/data'
check "static: --port beats package"  has "$("$D" config -C "$F/static-app" --port 7000)" 'host port +7000'
check "static: -v adds a volume"      has "$("$D" config -C "$F/static-app" -v /srv/x:/x)" '/srv/x:/x'

T="$(mktemp -d)"; cp -r "$F/static-app/." "$T/"; "$D" eject -C "$T" >/dev/null
# shellcheck disable=SC2016 # a literal $GIT_COMMIT is what the Dockerfile should contain
check "static: GIT_COMMIT reaches the build" grep -q 'ENV GIT_COMMIT=\$GIT_COMMIT' "$T/Dockerfile"
check "static: version.json never cached"   grep -q 'location = /version.json' "$T/nginx.conf"
rm -rf "$T"

cfg="$("$D" config -C "$F/node-app")"
check "node: mode detected"           has "$cfg" 'mode +node'
check "node: app port default"        has "$cfg" 'container +port 3000'

cfg="$("$D" config -C "$F/custom-dockerfile")"
check "custom: uses its Dockerfile"   has "$cfg" "dockerfile +project's own"
check "custom: port from EXPOSE"      has "$cfg" 'container +port 8080'

cfg="$("$D" config -C "$F/env-app")"
check "env: envFile from package"     has "$cfg" 'env files +\.env'
check "env: no vars by default"       has "$cfg" 'env vars +none'
check "env: --env-file adds a file"   has "$("$D" config -C "$F/env-app" --env-file .env.local)" 'env files +\.env \.env\.local'
cfg="$("$D" config -C "$F/env-app" -e A=hidden-value -e B)"
check "env: -e shows names"           has "$cfg" 'env vars +A B'
check "env: -e never shows values"    bash -c "! grep -q hidden-value <<<'$cfg'"
check "env: missing file is refused"  bash -c "! '$D' config -C '$F/env-app' --env-file nope.env"
check "env: bad -e is refused"        bash -c "! '$D' config -C '$F/env-app' -e '1BAD=x'"
check "env: none set by default"      has "$("$D" config -C "$F/node-app")" 'env files +none'
check "env: static mode warns"        has "$("$D" config -C "$F/static-app" -e X=1 2>&1)" 'no effect'

check "bad volume is refused"         bash -c "! '$D' config -C '$F/static-app' -v nonsense"
check "unknown command is refused"    bash -c "! '$D' frobnicate"
check "version prints"                has "$("$D" version)" '^[0-9]+\.[0-9]+\.[0-9]+$'

tmp="$(mktemp -d)"
check "install to a folder"           "$D" install --to "$tmp/bin"
check "installed copy runs"           "$tmp/bin/dockerize" version
check "uninstall removes it"          bash -c "'$D' uninstall --to '$tmp/bin' && [[ ! -e '$tmp/bin/dockerize' ]]"
rm -rf "$tmp"

echo "$pass passed, $fail failed"
((fail == 0))
