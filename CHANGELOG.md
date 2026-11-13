# Changelog

## 1.4.0

- `--env-file PATH` and `"envFile"` in package.json: the container gets the file's variables when it starts, so
  secrets stay out of the image. In node mode, `.env` and `.env.*` (except `.env.example`) and the named files are
  then left out of the build. A missing env file stops the deploy.
- `-e KEY=VALUE` (or `-e KEY` to pass the shell's value through) sets single variables.
- `config` shows env files and variable names (never values).
- Without either, behaviour is unchanged; node-mode `deploy` now warns when a `.env` is being copied into the image.
- Static mode is unchanged (Vite still reads `.env` at build time); env options only warn there.

## 1.3.0

- The project's git commit (read on the host: the build only gets a copy of the files, not `.git`) is passed to the
  build as `GIT_COMMIT` (`--build-arg`, and `ARG` / `ENV` in the generated Dockerfiles), so a build can stamp its
  version with it. `config` shows it. Without git, it's empty.
- Static mode's nginx always re-checks `/version.json`, like `index.html`, so an app's version file is never stale.

## 1.2.0

- `install`, `self-update` and `uninstall` commands. Install with
  `curl -fsSL https://raw.githubusercontent.com/n3rdw1z4rd/dockerize/main/dockerize | bash -s -- install`
  (to `~/.local/bin`, or `--to DIR`, any version with `--ref`).
- Tests (`tests/smoke.sh`, `tests/docker.sh`) and CI with shellcheck.

## 1.1.0

- Volumes: `-v name:/path` (a Docker volume called `<project>-name`) or `-v /host/path:/path`, and `"volumes"` in
  package.json. `config` and `deploy` show them; `clean` keeps them.

## 1.0.0

- `deploy`, `update`, `start`, `stop`, `restart`, `logs`, `status`, `clean`, `config`, `eject`.
- Static mode (nginx) and node mode, auto-detected; the project's own Dockerfile when it has one.
- Settings in package.json under `"dockerize"`.
