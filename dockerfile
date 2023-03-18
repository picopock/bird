FROM debian:bullseye-slim as builder

ENV VERSION 2.0.12

RUN apt update \
  && apt install -y gcc make autoconf flex bison libncurses-dev libreadline-dev curl \
  && curl -O -L https://bird.network.cz/download/bird-${VERSION}.tar.gz \
  && tar -zxvf bird-${VERSION}.tar.gz \
  && mv bird-${VERSION} /bird \
  && cd /bird \
  && ./configure --prefix=/ --bindir=/ \
  && make \
  && mv doc/bird.conf.example bird.conf \
  && chmod +x bird birdc

FROM alpine:latest

MAINTAINER Picopock <picopock@163.com>

COPY --from=builder /bird/bird /bird/birdc /bird/bird.conf /usr/sbin/
RUN apk add gcompat \
  && mkdir /etc/bird \
  && mv /usr/sbin/bird.conf /etc/bird/

EXPOSE 179

STOPSIGNAL SIGQUIT

ENTRYPOINT [ "bird", "-c", "/etc/bird/bird.conf", "-d" ]