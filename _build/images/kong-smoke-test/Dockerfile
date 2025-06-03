ARG KONG_IMAGE_NAME
ARG KONG_IMAGE_TAG
FROM ${KONG_IMAGE_NAME}:${KONG_IMAGE_TAG} AS builder

USER root

ARG KONG_PLUGIN_NAME
ARG KONG_PLUGIN_ROCKSPEC_FILE

RUN dnf install -y gcc m4 --setopt=install_weak_deps=False \
  && dnf clean all

WORKDIR /plugin
COPY . .

# Install from .rockspec
RUN luarocks make ${KONG_PLUGIN_ROCKSPEC_FILE}

FROM ${KONG_IMAGE_NAME}:${KONG_IMAGE_TAG}

ENV KONG_LOG_LEVEL=debug

ENV KONG_NGINX_WORKER_PROCESSES=1

# Add the Lua files (.lua)
COPY --from=builder /usr/local/share/lua/5.1 /usr/local/share/lua/5.1

# Add the compiled libraries (.so)
COPY --from=builder /usr/local/lib/lua/5.1 /usr/local/lib/lua/5.1

# Add the Luarocks manifest
COPY --from=builder /usr/local/lib/luarocks/rocks-5.1 /usr/local/lib/luarocks/rocks-5.1
