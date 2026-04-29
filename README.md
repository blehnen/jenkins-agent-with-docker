# jenkins-agent-with-docker

Jenkins inbound agent (JDK 21) with the Docker CLI baked in.

Companion image to
[`jenkins-with-docker`](https://github.com/blehnen/jenkins-with-docker) —
that one is the **controller**, this one is the **build agent**.

## Why a docker-enabled agent

When a Jenkinsfile uses
```groovy
agent { docker { image 'mcr.microsoft.com/dotnet/sdk:10.0' } }
```
the `docker pull` and `docker run` commands execute on whatever Jenkins
node the stage runs on — **not** on the controller. If your cloud agent
template uses an image without a docker client (the default
`jenkins/inbound-agent`), builds fail with `docker: not found` even when
the controller has docker installed.

This image is `jenkins/inbound-agent:jdk21` plus `docker-ce-cli`. It
talks to the host's docker daemon via a mounted socket — Docker-out-of-
Docker pattern, same as the controller.

## Image

```
blehnen74/jenkins-agent-with-docker:weekly             # tracks main, JDK 21
blehnen74/jenkins-agent-with-docker:latest             # alias for :weekly
blehnen74/jenkins-agent-with-docker:weekly-YYYYMMDD    # weekly rebuild snapshot
blehnen74/jenkins-agent-with-docker:vX.Y.Z             # tagged release
```

Multi-arch: `linux/amd64`, `linux/arm64`.

## Usage in Jenkins (Docker Cloud plugin)

In the cloud template:

| Field | Value |
|---|---|
| Docker Image | `blehnen74/jenkins-agent-with-docker:weekly` |
| Mounts | `/var/run/docker.sock:/var/run/docker.sock` |
| Extra group GIDs | host's docker socket GID (commonly `281` on Unraid) |
| User | leave blank or `jenkins` (controller-spawned, not Unraid-overridden) |

If the agent runs under an Unraid uid override (uid 99 / nobody), that's
fine — the supplementary group from "Extra group GIDs" works regardless
of the run-as user, the same way `--group-add` works on the controller.

Find the host's docker-socket GID with:

```bash
stat -c '%g' /var/run/docker.sock
```

## Verifying

After the cloud template is updated, trigger a no-op pipeline that runs
`sh 'docker version'` from inside an `agent { docker { image '...' } }`
block. You should see both `Client:` and `Server:` blocks. Server-side
info means the mounted socket is reachable from inside the agent
container.

## Build cadence

The publish workflow runs:
- on every push to `main` (rebuilds with current upstream inbound-agent),
- weekly on Monday 06:00 UTC (catches upstream / CVE patches),
- on `v*` tags (semver pinning for consumers who want stability).

## Updating the base

`Dockerfile` is pinned to `jenkins/inbound-agent:jdk21`. To change JDK
or pin a specific upstream tag, edit the `FROM` line and push to `main`.
Tag a `v*` release if you want a stable pin published.
