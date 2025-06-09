
ARG PLATFORM
FROM lncm/berkeleydb:db-4.8.30.NC-${PLATFORM} AS berkeleydb


FROM alpine:3.21 AS bitcoin-core

COPY --from=berkeleydb /opt /opt

# Install Bitcoin Core build dependencies
RUN sed -i 's/http:\/\/dl-cdn.alpinelinux.org/https:\/\/alpine.global.ssl.fastly.net/g' /etc/apk/repositories && \
  apk --no-cache add \
    autoconf \
    automake \
    boost-dev \
    build-base \
    clang \
    file \
    libevent-dev \
    libressl \
    libtool \
    linux-headers \
    sqlite-dev \
    zeromq-dev

# Copy Bitcoin Core source
ADD ./bitcoin /bitcoin
WORKDIR /bitcoin

# Configure and build Bitcoin Core
ENV BITCOIN_PREFIX=/opt/bitcoin

RUN ./autogen.sh
RUN ./configure \
    LDFLAGS="-L$(ls -d /opt/db*/lib)" \
    CPPFLAGS="-I$(ls -d /opt/db*/include)" \
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

RUN make -j$(nproc) && make install && strip ${BITCOIN_PREFIX}/bin/*

# --- 🧩 Stage 3: Final runtime image ---
FROM alpine:3.21

# Metadata
LABEL maintainer.0="João Fonseca (@joaopaulofonseca)" \
      maintainer.1="Pedro Branco (@pedrobranco)" \
      maintainer.2="Rui Marinho (@ruimarinho)" \
      maintainer.3="Aiden McClelland (@dr-bonez)"

# Install runtime deps: Bitcoin, Python3, Flask, etc.
RUN sed -i 's/http:\/\/dl-cdn.alpinelinux.org/https:\/\/alpine.global.ssl.fastly.net/g' /etc/apk/repositories && \
  apk --no-cache add \
    bash \
    curl \
    libevent \
    libzmq \
    sqlite-dev \
    tini \
    yq \
    python3 \
    py3-pip \
    py3-requests \
    py3-flask \
    py3-yaml

# Environment setup
ARG ARCH
ENV BITCOIN_DATA=/root/.bitcoin
ENV BITCOIN_PREFIX=/opt/bitcoin
ENV PATH=${BITCOIN_PREFIX}/bin:$PATH

# Copy Bitcoin Core binaries from builder
COPY --from=bitcoin-core /opt /opt

# Copy bitcoind-manager and entry scripts
COPY ./manager/target/${ARCH}-unknown-linux-musl/release/bitcoind-manager \
     ./docker_entrypoint.sh \
     ./actions/reindex.sh \
     ./actions/reindex_chainstate.sh \
     ./check-rpc.sh \
     ./check-synced.sh \
     /usr/local/bin/

RUN chmod +x /usr/local/bin/bitcoind-manager \
             /usr/local/bin/*.sh

# Copy Flask app
COPY ./bitcoin-stats.py /opt/app/bitcoin-stats.py
COPY ./index.html /opt/app/templates/index.html
COPY ./bitcoin.png /opt/app/static/bitcoin.png

WORKDIR /opt/app

# Expose ports: RPC, P2P, and Flask dashboard
EXPOSE 8332 8333 5006

# Start everything via entrypoint
ENTRYPOINT ["/usr/local/bin/docker_entrypoint.sh"]
