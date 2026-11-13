# dockerize

Build and run any Node project as a Docker container, from its own folder, with one command.

```bash
cd my-app
dockerize deploy
```

- **Static mode** (Vite and other front-end apps): builds the project, then serves the output with nginx.
- **Node mode** (Express, Fastify, Next, socket.io, …): runs the `build` script if there is one, then `start`.
- **Your own Dockerfile**: if the project has one, dockerize builds that instead (use it for anything that needs more,
  like two processes in one container).

It needs nothing added to the project. Everything it creates is named and labelled after the project, and it never
touches containers, images or volumes that belong to anything else.

## Install

One file, no dependencies beyond `bash`, Docker, and `node` or `jq` (to read package.json).

```bash
curl -fsSL https://raw.githubusercontent.com/n3rdw1z4rd/dockerize/main/dockerize | bash -s -- install
```

That puts `dockerize` in `~/.local/bin` (most distros already have that on your `PATH`; if not, the installer tells
you the line to add). Options:

```bash
# somewhere else
curl -fsSL https://raw.githubusercontent.com/n3rdw1z4rd/dockerize/main/dockerize | bash -s -- install --to /usr/local/bin
# a specific version (any tag or branch)
curl -fsSL https://raw.githubusercontent.com/n3rdw1z4rd/dockerize/main/dockerize | bash -s -- install --ref v1.2.0
```

`DOCKERIZE_INSTALL_DIR` sets the default folder. Later:

```bash
dockerize self-update      # replace this copy with the latest (or: --ref v1.2.0)
dockerize uninstall        # remove it (containers, images and volumes are left alone)
```

Or just copy the `dockerize` file anywhere on your `PATH` and `chmod +x` it.

## Use

Run it from the project folder (or point it at one with `-C path`).

| command | what it does |
| --- | --- |
| `deploy` / `update` | build the image and (re)start the container, then prune this project's old images |
| `start` | start the container from the last built image |
| `stop` | stop and remove the container (the image is kept) |
| `restart` | restart the running container |
| `logs` | follow the container's logs |
| `status` | this project's container and images |
| `clean` | remove this project's container and all of its images (volumes are kept) |
| `config` | show the settings dockerize worked out, without doing anything |
| `eject` | write the generated Dockerfile (and nginx.conf) into the project to customise; dockerize uses them from then on |

| option | default | |
| --- | --- | --- |
| `-C, --dir PATH` | `.` | project folder |
| `-n, --name NAME` | package.json `name` | container / image name (made Docker-safe: `@scope/My App` → `scope-my-app`) |
| `-p, --port PORT` | 5173 | host port to publish |
| `-m, --mode MODE` | detected | `static` or `node` |
| `--app-port PORT` | 3000 | port a node-mode app listens on inside the container |
| `--out-dir DIR` | `dist` | build output in static mode |
| `--node IMAGE` | `node:lts-alpine` | Node base image |
| `--network NET` | | attach to a Docker network (e.g. the one your reverse proxy is on) |
| `--bind ADDR` | all interfaces | publish on one address only, e.g. `127.0.0.1` behind a proxy |
| `--no-publish` | | don't publish a port (use with `--network`) |
| `-v, --volume SPEC` | | `name:/path` (a Docker volume called `<project>-name`) or `/host/path:/path`; repeatable |
| `--env-file PATH` | | give the container the variables in this file when it starts (relative to the project); repeatable. See [Secrets and environment variables](#secrets-and-environment-variables) |
| `-e, --env KEY=VALUE` | | set one variable in the container; `-e KEY` passes this shell's value through; repeatable |

### Settings in package.json

So you don't repeat flags on every deploy:

```json
{
  "dockerize": {
    "port": 6666,
    "volumes": ["data:/data"]
  }
}
```

Keys: `name`, `port`, `mode`, `appPort`, `outDir`, `node`, `network`, `bind`, `publish`, `assets`, `containerPort`,
`volumes`, `envFile` (a path or a list). Command-line options beat package.json, which beats the defaults; volumes
and env files from the command line are added to package.json's.

### Secrets and environment variables

A node-mode build copies the project into the image, so a `.env` in the folder ends up inside it, readable by anyone
who has the image. For anything secret (API keys, passwords), point dockerize at the file instead:

```json
{
  "dockerize": { "envFile": ".env" }
}
```

Then, in node mode:

- the variables are given to the container when it starts (`docker run --env-file`), not built into the image;
- `.env` and every `.env.*` file (except `.env.example`), and the env files you named, are left out of the build;
- a missing env file stops the deploy instead of starting the app without its settings.

The file is Docker's env-file format: one `KEY=value` per line, `#` comments on their own lines, and no quotes
(they become part of the value). Edit it, then `dockerize start` (or `deploy`) to apply; `restart` keeps the old
values. `config` lists env files and variable names, never values.

Without `envFile`, nothing changes from earlier versions: `.env` is still copied in (some apps rely on it), and
`deploy` warns that it is. Static mode is unaffected either way: Vite reads `.env` while it builds, and those values
end up in the public JavaScript, so never put secrets there. With your own Dockerfile, list the env file in
`.dockerignore` (dockerize warns if you don't).

### How it decides

- **Mode:** a `start` script that isn't Vite → node; otherwise a `vite` dependency or a `build` script → static.
- **Package manager:** from the lockfile (pnpm, yarn, npm); `npm ci` when there's a lockfile.
- **Container port:** static → 80 (nginx); node → `appPort`; your own Dockerfile → `containerPort`, else its last
  `EXPOSE`.
- **Static assets:** an `assets/` folder (or the `assets` list) is copied next to the build output.
- **Builds** run from a clean copy of the project (no `node_modules`, `.git` or old build output), so nothing needs to be
  added to the project. A project Dockerfile builds from the project folder itself, so give it a `.dockerignore`.

### Safety

- Containers run with `--restart unless-stopped` and are checked a few seconds after starting; if one won't stay up,
  you get its last log lines and a non-zero exit.
- A port already used by another container (or anything else on the host) stops the deploy before it starts.
- Everything is labelled `dockerize.app=<name>`; `clean` and image pruning only ever touch that label.
- Named volumes are never removed by dockerize (`docker volume rm <project>-<name>` if you mean it).

## Examples

```bash
dockerize deploy --port 6666                 # a Vite game on :6666
dockerize deploy --bind 127.0.0.1 -p 8080    # only reachable through a reverse proxy on the same host
dockerize deploy --network proxy --no-publish  # reachable as http://<name>:<port> on the "proxy" network
dockerize deploy -v data:/data               # keep /data across deploys
dockerize deploy --env-file .env             # secrets reach the container, not the image
dockerize deploy -e LOG_LEVEL=debug          # one-off variable
dockerize logs
```

## Develop

```bash
tests/smoke.sh     # no Docker needed: detection, settings, install / uninstall
tests/docker.sh    # deploys fixtures for real on :6666 and :6667, then cleans up
shellcheck dockerize
```

CI runs all three on every push. Versions follow [semver](https://semver.org); see [CHANGELOG.md](CHANGELOG.md).
To release: bump `VERSION` in the script, add a CHANGELOG entry, tag `vX.Y.Z`.

## License

MIT
