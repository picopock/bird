ARG BIRD_VERSION=3.0.1

FROM debian:trixie-slim AS builder

ARG BIRD_VERSION

RUN apt update \
  && apt install -y --no-install-recommends \
      ca-certificates \
      make curl build-essential bison m4 flex \
      libncurses5-dev libreadline-dev libssh-dev pkg-config \
  && rm -rf /var/lib/apt/lists/*

RUN BIRD_VERSION="${BIRD_VERSION:-3.0.1}"; \
    if [ -z "${BIRD_VERSION}" ] || ! echo "${BIRD_VERSION}" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then \
        echo "WARNING: Invalid BIRD_VERSION, fallback to 3.0.1"; \
        BIRD_VERSION=3.0.1; \
    fi && \
    export BIRD_VERSION && \
    export BIRD_TAR="bird-${BIRD_VERSION}.tar.gz" && \
    export BIRD_URL="https://bird.network.cz/download/${BIRD_TAR}" && \
    curl -fsSL -O "${BIRD_URL}" && \
    ( curl -fsSL -O "${BIRD_URL}.sha256" 2>/dev/null && \
      ( echo "Verifying ${BIRD_TAR}..." && sha256sum -c "${BIRD_TAR}.sha256" ) || ( echo "ERROR: Checksum failed!" && exit 1 ) \
    ) || echo "WARNING: Checksum file not found, skip verification" && \
    tar -zxf "${BIRD_TAR}" -C /tmp && \
    mv "/tmp/bird-${BIRD_VERSION}" /bird && \
    rm -rf "${BIRD_TAR}" "${BIRD_TAR}.sha256" /tmp/*

RUN cd /bird \
  && ./configure \
        --prefix=/usr \
        --sysconfdir=/etc/bird \
        --runstatedir=/var/run/bird \
        --disable-doc \
        --disable-debug \
  && make -j$(nproc) \
  && chmod +x /bird/bird /bird/birdc

FROM debian:trixie-slim

ARG BIRD_VERSION=3.0.1
ENV BIRD_VERSION=${BIRD_VERSION}
LABEL author=picopock<picopock@163.com> \
      description="Lightweight BIRD BGP/OSPF Routing Daemon (containerized)" \
      bird.version="${BIRD_VERSION}" \
      maintainer="pico"

COPY --from=builder /bird/bird /bird/birdc /usr/sbin/
COPY --from=builder /bird/doc/bird.conf.example /etc/bird/bird.conf.example
COPY entrypoint.sh /usr/local/bin/

RUN apt update \
    && apt install -y --no-install-recommends \
        libcap2-bin \
        libssh-4 libreadline8 libncurses6 \
        iproute2 bash net-tools \
    && groupadd -r bird && useradd -r -g bird -d /var/run/bird -s /sbin/nologin bird \
    && mkdir -p /etc/bird /var/run/bird \
    && chown -R bird:bird /etc/bird /var/run/bird \
    && chmod 770 /var/run/bird \
    && ln -s /usr/sbin/birdc /usr/bin/birdc \
    && ln -s /usr/sbin/bird /usr/bin/bird \
    && setcap cap_net_raw,cap_net_admin+ep /usr/sbin/bird \
    && apt-get remove -y --purge libcap2-bin \
    && apt-get autoremove -y --purge \
    && rm -rf /var/lib/apt/lists/* \
    && chmod +x /usr/local/bin/entrypoint.sh \
    && chown bird:bird /usr/local/bin/entrypoint.sh

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD birdc -s /var/run/bird/bird.ctl show status >/dev/null 2>&1 || exit 1

EXPOSE 179/tcp
VOLUME ["/etc/bird", "/var/run/bird"]

USER bird

STOPSIGNAL SIGQUIT

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]