# syntax=docker/dockerfile:1

ARG BASE_IMAGE=ubuntu:24.04
ARG AWS_CLI_IMAGE=amazon/aws-cli:2.27.0
ARG BWS_VERSION=1.0.0
ARG VERSION=dev
ARG GIT_COMMIT=unknown
ARG BUILD_DATE=unknown
ARG LICENSE=AGPL-3.0-or-later

FROM ${BASE_IMAGE} AS bws
ARG BWS_VERSION
ARG TARGETARCH
# Only the checksummed release binary is copied from this builder stage.
# hadolint ignore=DL3008
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      unzip \
 && rm -rf /var/lib/apt/lists/* \
 && case "${TARGETARCH}" in \
      amd64) \
        bws_arch=x86_64; \
        bws_sha256=9077fb7b336a62abc8194728fea8753afad8b0baa3a18723fc05fc02fdb53568 \
        ;; \
      arm64) \
        bws_arch=aarch64; \
        bws_sha256=20a3dcb9e3ce7716a1dc3c0e1c76cea9d5e2bf75094cbb5aad54ced4304929cb \
        ;; \
      *) \
        echo "Unsupported BWS architecture: ${TARGETARCH}" >&2; \
        exit 1 \
        ;; \
    esac \
 && bws_archive="bws-${bws_arch}-unknown-linux-gnu-${BWS_VERSION}.zip" \
 && curl --fail --location --silent --show-error \
      "https://github.com/bitwarden/sdk-sm/releases/download/bws-v${BWS_VERSION}/${bws_archive}" \
      --output "/tmp/${bws_archive}" \
 && printf '%s  %s\n' "${bws_sha256}" "/tmp/${bws_archive}" \
      > /tmp/bws.sha256 \
 && sha256sum --check --status /tmp/bws.sha256 \
 && unzip -p "/tmp/${bws_archive}" bws > /usr/local/bin/bws \
 && chmod 0755 /usr/local/bin/bws \
 && rm "/tmp/${bws_archive}"

FROM ${AWS_CLI_IMAGE} AS awscli

FROM ${BASE_IMAGE}

ARG BASE_IMAGE
ARG VERSION
ARG GIT_COMMIT
ARG BUILD_DATE
ARG LICENSE

ENV APP_VERSION="${VERSION}" \
    APP_BASE_IMAGE="${BASE_IMAGE}" \
    APP_COMMIT="${GIT_COMMIT}" \
    APP_BUILD_DATE="${BUILD_DATE}" \
    HOME=/home/bwx \
    BWX_CONFIG_DIR=/home/bwx/.config/bwx \
    BWX_CACHE_DIR=/home/bwx/.cache/bwx

LABEL org.opencontainers.image.title="bwx" \
      org.opencontainers.image.description="Bitwarden Secrets Manager lifecycle CLI" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${GIT_COMMIT}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.source="https://github.com/1121citrus/bwx" \
      org.opencontainers.image.vendor="1121 Citrus" \
      org.opencontainers.image.licenses="${LICENSE}"

# hadolint ignore=DL3005,DL3008
RUN apt-get update \
 && apt-get upgrade -y \
 && apt-get install -y --no-install-recommends \
      bash \
      ca-certificates \
      curl \
      jq \
      openssl \
      passwd \
 && rm -rf /var/lib/apt/lists/* \
 && useradd --create-home --uid 10001 --shell /usr/sbin/nologin bwx

COPY --from=bws /usr/local/bin/bws /usr/local/bin/bws
COPY --from=awscli /usr/local/aws-cli /usr/local/aws-cli
RUN ln -s /usr/local/aws-cli/v2/current/bin/aws /usr/local/bin/aws
COPY --chown=10001:10001 bin/ /opt/bwx/bin/
COPY --chown=10001:10001 include/ /opt/bwx/include/
COPY --chown=10001:10001 lib/ /opt/bwx/lib/
COPY --chown=10001:10001 version.txt /opt/bwx/

RUN ln -s /opt/bwx/bin/bwx /usr/local/bin/bwx \
 && install -d -o bwx -g bwx -m 0700 \
      /home/bwx/.config/bwx \
      /home/bwx/.cache/bwx

USER 10001:10001
WORKDIR /workspace
ENTRYPOINT ["bwx"]
