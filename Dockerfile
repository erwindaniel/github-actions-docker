# docker build --tag runner-image .

# docker run \
#  --detach \
#  --env ORGANIZATION=<YOUR-GITHUB-ORGANIZATION> \
#  --env ACCESS_TOKEN=<YOUR-GITHUB-ACCESS-TOKEN> \
#  --name runner \
#  runner-image


# base
# ...existing code...
FROM ubuntu:22.04

# set the github runner version
ARG RUNNER_VERSION="2.329.0"
ARG OC_CHANNEL="latest"
ARG HELM_INSTALL_SCRIPT="https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3"
ARG YQ_VERSION="latest"
ARG TKN_VERSION="latest"

ENV DEBIAN_FRONTEND=noninteractive

# update the base packages and add a non-sudo user
RUN apt-get update -y && apt-get upgrade -y && useradd -m docker

# install python and the packages the your code depends on along with jq so we can parse JSON
# add additional packages as necessary
RUN apt-get update -y && apt-get install -y --no-install-recommends \
    ca-certificates curl gnupg2 lsb-release tar gzip jq git sudo libc6 \
    python3 python3-venv unzip procps && \
    rm -rf /var/lib/apt/lists/*


# cd into the user directory, download and unzip the github actions runner
RUN cd /home/docker && mkdir actions-runner && cd actions-runner \
    && curl -O -L https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz \
    && tar xzf ./actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz

# install some additional dependencies
RUN chown -R docker ~docker && /home/docker/actions-runner/bin/installdependencies.sh

# ---------------------------
# Install oc, argocd, helm, tkn, yq
# ---------------------------
RUN set -eux; \
    # oc (OpenShift client) - from mirror.openshift.com (contains oc binary)
    OC_TMPDIR="$(mktemp -d)"; \
    curl -fsSL "https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${OC_CHANNEL}/openshift-client-linux.tar.gz" -o "${OC_TMPDIR}/oc.tar.gz"; \
    tar -C "${OC_TMPDIR}" -xzf "${OC_TMPDIR}/oc.tar.gz"; \
    mv "${OC_TMPDIR}/oc" /usr/local/bin/oc; \
    chmod +x /usr/local/bin/oc; \
    rm -rf "${OC_TMPDIR}"; \
    \
    # argocd CLI
    curl -fsSL -o /usr/local/bin/argocd "https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64"; \
    chmod +x /usr/local/bin/argocd; \
    \
    # helm (use official installer script)
    curl -fsSL "${HELM_INSTALL_SCRIPT}" | bash; \
    \
    # yq (mikefarah)
    if [ "${YQ_VERSION}" = "latest" ]; then \
      curl -fsSL -o /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64"; \
    else \
      curl -fsSL -o /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64"; \
    fi; \
    chmod +x /usr/local/bin/yq;  \
    # s2i (robust download: try GitHub API, fallback to generic download URL)
    S2I_ASSET_URL=$(curl -sS https://api.github.com/repos/openshift/source-to-image/releases/latest | jq -r '.assets[]?.browser_download_url' | grep -Ei 'source-to-image.*(linux.*amd64|linux_amd64|linux-x86_64)' | head -n1 || true); \
    if [ -z "$S2I_ASSET_URL" ]; then S2I_ASSET_URL="https://github.com/openshift/source-to-image/releases/latest/download/s2i"; fi; \
    echo "Downloading s2i from: ${S2I_ASSET_URL}"; \
    if printf '%s' "${S2I_ASSET_URL}" | grep -E '\.tar\.gz$|\.tgz$' >/dev/null 2>&1; then \
      curl -fsSL -o /tmp/s2i.tar.gz "${S2I_ASSET_URL}"; \
      tar -C /tmp -xzf /tmp/s2i.tar.gz; \
      S2I_BIN=$(find /tmp -type f -name 's2i' -perm /111 | head -n1 || true); \
      if [ -n "${S2I_BIN}" ]; then mv "${S2I_BIN}" /usr/local/bin/s2i && chmod +x /usr/local/bin/s2i; else echo "s2i binary not found inside archive" && exit 1; fi; \
      rm -f /tmp/s2i.tar.gz; \
    else \
      curl -fsSL -o /usr/local/bin/s2i "${S2I_ASSET_URL}"; chmod +x /usr/local/bin/s2i; \
    fi;
# copy over the start.sh script
COPY start.sh start.sh

# make the script executable
RUN chmod +x start.sh

# since the config and run script for actions are not allowed to be run by root,
# set the user to "docker" so all subsequent commands are run as the docker user
USER docker

# set the entrypoint to the start.sh script
ENTRYPOINT ["./start.sh"]