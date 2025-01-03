ARG KONG_IMAGE_NAME
ARG KONG_IMAGE_TAG
FROM ${KONG_IMAGE_NAME}:${KONG_IMAGE_TAG} AS builder

USER root

# The arg/env variable is already defined in the base image. Due to a buildah bug
# the variable KONG_VERSION can't be used and will always be an empty string.
ARG KONG_TARGET_VERSION
ARG KONG_PLUGIN_NAME
ARG KONG_PLUGIN_VERSION
ARG KONG_PLUGIN_REVISION
ARG PONGO_KONG_VERSION
ARG PONGO_ARCHIVE
ARG STYLUA_VERSION
ARG EMMY_LUA_DEBUGGER_VERSION

COPY kong-plugin-${KONG_PLUGIN_NAME}-${KONG_PLUGIN_VERSION}-${KONG_PLUGIN_REVISION}.rockspec /kong-plugin-${KONG_PLUGIN_NAME}-${KONG_PLUGIN_VERSION}-${KONG_PLUGIN_REVISION}.rockspec
COPY _build/images/kong-plugin-testing-0.1.0-0.rockspec /kong-plugin-testing-0.1.0-0.rockspec

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN dnf install -y cmake gcc m4 git --setopt=install_weak_deps=False \
  && curl -sSf -L https://github.com/Kong/kong-pongo/archive/refs/heads/master.tar.gz | tar xfvz - -C / --strip-components 3 kong-pongo-master/kong-versions/"${PONGO_KONG_VERSION}" \
  && echo 'database = off' >> /kong/spec/kong_tests.conf \
  # Install stylua
  && curl -sSf -L "https://github.com/JohnnyMorganz/StyLua/releases/download/v${STYLUA_VERSION}/stylua-linux-x86_64.zip" -o /tmp/stylua-linux-x86_64.zip \
  # Download and compile EmmyLuaDebugger
  && curl -sSf -L "https://github.com/EmmyLua/EmmyLuaDebugger/archive/refs/tags/${EMMY_LUA_DEBUGGER_VERSION}.zip" -o /tmp/emmylua-debugger.zip \
  && unzip /tmp/emmylua-debugger.zip -d /tmp \
  && mkdir /tmp/EmmyLuaDebugger-${EMMY_LUA_DEBUGGER_VERSION}/build \
  && cd /tmp/EmmyLuaDebugger-${EMMY_LUA_DEBUGGER_VERSION}/build \
  && cmake .. -DCMAKE_BUILD_TYPE=Release -DEMMY_CORE_VERSION=${EMMY_LUA_DEBUGGER_VERSION} \
  && cmake --build . --config Release \
  # Install package dependencies defined in the plugin rockspec file.
  && luarocks build /kong-plugin-${KONG_PLUGIN_NAME}-${KONG_PLUGIN_VERSION}-${KONG_PLUGIN_REVISION}.rockspec --only-deps OPENSSL_DIR=/usr/local/kong CRYPTO_DIR=/usr/local/kong \
  # Install package dependencies used for unit and integration tests.
  && luarocks build /kong-plugin-testing-0.1.0-0.rockspec --only-deps OPENSSL_DIR=/usr/local/kong CRYPTO_DIR=/usr/local/kong \
  && unzip /tmp/stylua-linux-x86_64.zip -d /usr/local/bin \
  && cp /tmp/EmmyLuaDebugger-${EMMY_LUA_DEBUGGER_VERSION}/build/emmy_core/emmy_core.so /usr/local/lib/lua/5.1 \
  && rm -rf /var/tmp/*

FROM ${KONG_IMAGE_NAME}:${KONG_IMAGE_TAG}

ENV LUA_PATH="/kong-plugin/?.lua;/kong-plugin/?/init.lua;;"
ENV KONG_LOG_LEVEL=debug
ENV KONG_PREFIX=/kong-plugin/servroot
ENV KONG_TEST_PREFIX=/kong-plugin/servroot

ENV PATH="/kong/bin:${PATH}"

COPY --from=builder /etc/yum.repos.d/ubi.repo /etc/yum.repos.d/ubi.repo

USER root

# Install hostname and netstat for kong spec testing helper
RUN dnf install -y net-tools hostname --setopt=install_weak_deps=False \
  && dnf clean all \
  && rm -rf /var/cache/dnf

USER kong

# Add the Kong spec installation
COPY --from=builder /kong /kong

# Add binaries from luarocks installation
COPY --from=builder /usr/local/bin /usr/local/bin

# Add the Lua files (.lua)
COPY --from=builder /usr/local/share/lua/5.1 /usr/local/share/lua/5.1

# Add the compiled libraries (.so)
COPY --from=builder /usr/local/lib/lua/5.1 /usr/local/lib/lua/5.1

# Add the Luarocks manifest
COPY --from=builder /usr/local/lib/luarocks/rocks-5.1 /usr/local/lib/luarocks/rocks-5.1

WORKDIR /kong
