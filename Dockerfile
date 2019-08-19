FROM ubuntu:bionic
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get -y update \
    && \
    apt-get install -y --no-install-recommends \
    kmod \
    iproute2 \
    net-tools \
    strongswan \
    xl2tpd \
    && \
    rm -rf /var/lib/apt/lists/*

COPY ./entrypoint.sh /entrypoint.sh
RUN chmod 755 /entrypoint.sh

CMD ["/entrypoint.sh"]