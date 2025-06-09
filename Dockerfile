# From https://github.com/ruimarinho/docker-bitcoin-core

# Build stage for BerkeleyDB
ARG PLATFORM

FROM lncm/berkeleydb:db-4.8.30.NC-${PLATFORM} AS berkeleydb

# Build stage for Bitcoin Core
FROM alpine:3.21 AS bitcoin-core

COPY --from=berkeleydb /opt /opt

RUN sed -i 's/http\:\/\/dl-cdn.alpinelinux.org/https\:\/\/alpine.global.ssl.fastly.net/g' /etc/apk/repositories
RUN apk --no-cache add \
        autoconf \
        automake \
        boost-dev \
        build-base \
        clang \
        chrpath \
        file \
        gnupg \
        libevent-dev \
        libressl \
        libtool \
        linux-headers \
        sqlite-dev \
        zeromq-dev

ADD ./bitcoin /bitcoin

ENV BITCOIN_PREFIX=/opt/bitcoin

WORKDIR /bitcoin

RUN ./autogen.sh
RUN ./configure LDFLAGS=-L`ls -d /opt/db*`/lib/ CPPFLAGS=-I`ls -d /opt/db*`/include/ \
  CXXFLAGS="-O1" \
  CXX=clang++ CC=clang \
  --prefix=${BITCOIN_PREFIX} \
  --disable-man \
  --disable-tests \
  --disable-bench \
  --disable-ccache \
  --with-gui=no \
  --with-utils \
  --with-libs \
  --with-sqlite=yes \
  --with-daemon
RUN make -j$(nproc)
RUN make install
RUN strip ${BITCOIN_PREFIX}/bin/*

# Final image
FROM alpine:3.21

LABEL maintainer.0="João Fonseca (@joaopaulofonseca)" \
  maintainer.1="Pedro Branco (@pedrobranco)" \
  maintainer.2="Rui Marinho (@ruimarinho)" \
  maintainer.3="Aiden McClelland (@dr-bonez)"

RUN sed -i 's/http\:\/\/dl-cdn.alpinelinux.org/https\:\/\/alpine.global.ssl.fastly.net/g' /etc/apk/repositories
RUN apk --no-cache add \
  bash \
  curl \
  libevent \
  libzmq \
  sqlite-dev \
  tini \
  yq \
  python3 \
  py3-pip \
  py3-requests

RUN rm -rf /var/cache/apk/*

ARG ARCH

ENV BITCOIN_DATA=/root/.bitcoin
ENV BITCOIN_PREFIX=/opt/bitcoin
ENV PATH=${BITCOIN_PREFIX}/bin:$PATH

COPY --from=bitcoin-core /opt /opt

COPY ./manager/target/${ARCH}-unknown-linux-musl/release/bitcoind-manager \
     ./docker_entrypoint.sh \
     ./actions/reindex.sh \
     ./actions/reindex_chainstate.sh \
     ./check-rpc.sh \
     ./check-synced.sh \
     /usr/local/bin/

RUN chmod a+x /usr/local/bin/bitcoind-manager \
    /usr/local/bin/*.sh

# -------------------------------
# 🟡 Add Python Flask Dashboard
# -------------------------------
COPY ./bitcoin-stats.py /opt/app/bitcoin-stats.py
COPY ./index.html /opt/app/templates
COPY ./bitcoin.png /opt/app/static

WORKDIR /opt/app

RUN pip3 install Flask requests

EXPOSE 8332 8333 5006

# -------------------------------
# 🟢 Run bitcoind-manager and Flask
# -------------------------------
CMD bitcoind-manager & python3 /opt/app/bitcoin-stats.py
