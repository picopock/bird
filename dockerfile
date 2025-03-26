ARG BIRD_VERSION

# 从构建参数获取 bird 版本
FROM debian:bookworm-slim AS builder

ARG BIRD_VERSION

RUN apt update \
  && apt install -y make curl build-essential bison m4 flex libncurses5-dev libreadline-dev libssh-dev pkg-config \ 
  && curl -O -L -C - https://bird.network.cz/download/bird-${BIRD_VERSION}.tar.gz \
  && tar -zxvf bird-${BIRD_VERSION}.tar.gz \
  && mv bird-${BIRD_VERSION} /bird \
  && cd /bird \
  && ./configure --prefix=/ --bindir=/ \
  && make \
  && mv doc/bird.conf.example bird.conf \
  && chmod +x bird birdc

FROM debian:bookworm-slim 

LABEL author=picopock<picopock@163.com>

COPY --from=builder /bird/bird /bird/birdc /bird/bird.conf /usr/bin/

RUN apt update \ 
  && apt install -y libssh-4 \
  && mkdir /etc/bird \
  && mv /usr/bin/bird.conf /etc/bird/

EXPOSE 179

STOPSIGNAL SIGQUIT

ENTRYPOINT [ "bird", "-c", "/etc/bird/bird.conf", "-d" ]