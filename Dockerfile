# jenkins-agent-with-docker
#
# Jenkins inbound agent (JDK 25) + Docker CLI baked in. Companion to
# blehnen74/jenkins-with-docker — that image is the controller, this is
# the build agent.
#
# Why an agent image needs docker: when a Jenkinsfile uses
# `agent { docker { image '...' } }`, the docker invocation runs on
# whatever node Jenkins picks for the stage, NOT on the controller.
# The agent has to be able to call `docker pull` / `docker run` against
# a daemon. Without a docker client on the agent, builds fail with
# `docker: not found` even when the controller has docker.
#
# Runtime requirements (set by the consumer via the Jenkins cloud
# template, not the image):
#   --group-add <docker-socket-gid>   e.g. `--group-add 281` on Unraid;
#                                     supplementary group for the mounted
#                                     docker.sock regardless of run-as user.
#   -v /var/run/docker.sock:/var/run/docker.sock
#
# In Jenkins (Docker Cloud plugin):
#   - Container settings → Mounts: add `/var/run/docker.sock` host-to-container
#   - Container settings → Extra group GIDs: add the host's docker.sock GID

FROM jenkins/inbound-agent:jdk25

USER root

# Docker CE CLI from Docker's official apt repo. Client only — the daemon
# lives on the host and is reached via the mounted socket.
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg; \
    install -m 0755 -d /etc/apt/keyrings; \
    curl -fsSL https://download.docker.com/linux/debian/gpg \
        | gpg --dearmor -o /etc/apt/keyrings/docker.gpg; \
    chmod a+r /etc/apt/keyrings/docker.gpg; \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" \
        > /etc/apt/sources.list.d/docker.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends docker-ce-cli; \
    rm -rf /var/lib/apt/lists/*; \
    docker --version

USER jenkins
