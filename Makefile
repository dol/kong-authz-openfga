include plugin.properties

PLUGIN_FILES = $(shell find kong -type f -name '*.lua')

KONG_IMAGE_TAG := $(KONG_VERSION)-rhel@sha256:$(KONG_IMAGE_HASH)

ROCKSPEC_DEV_FILE := kong-plugin-$(KONG_PLUGIN_NAME)-dev-0.rockspec
ROCKSPEC_RELEASE_FILE := kong-plugin-$(KONG_PLUGIN_NAME)-$(KONG_PLUGIN_VERSION)-$(KONG_PLUGIN_REVISION).rockspec
ROCK_RELEASE_FILE := kong-plugin-$(KONG_PLUGIN_NAME)-$(KONG_PLUGIN_VERSION)-$(KONG_PLUGIN_REVISION).all.rock

SERVROOT_PATH := servroot

TEST_RESULTS_PATH := test-results

# Overwrite if you want to use `docker` with sudo
DOCKER ?= docker

_docker_is_podman = $(shell $(DOCKER) --version | grep podman 2>/dev/null)

# Set default run flags:
# - allocate a pseudo-tty
# - remove container on exit
# - set username/UID to executor
DOCKER_USER ?= $$(id -u)
DOCKER_USER_OPT = $(if $(_docker_is_podman),--userns keep-id,--user $(DOCKER_USER))
DOCKER_RUN_FLAGS_TTY ?= --tty
DOCKER_RUN_FLAGS ?= --rm --interactive $(DOCKER_RUN_FLAGS_TTY) $(DOCKER_USER_OPT)

DOCKER_MOUNT_IN_CONTAINER := /kong-plugin

DOCKER_NO_CACHE :=

BUILDKIT_PROGRESS :=

# Busted runtime profile
BUSTED_RUN_PROFILE := default
BUSTED_FILTER :=

# Busted exclude tags
BUSTED_EXCLUDE_TAGS := postgres
BUSTED_NO_KEEP_GOING := false
BUSTED_COVERAGE := false
BUSTED_EMMY_DEBUGGER := false

BUSTED_EMMY_DEBUGGER_ENABLED_ARGS =

BUSTED_ARGS = --config-file $(DOCKER_MOUNT_IN_CONTAINER)/.busted --run '$(BUSTED_RUN_PROFILE)' --exclude-tags='$(BUSTED_EXCLUDE_TAGS)' --filter '$(BUSTED_FILTER)'
ifneq ($(BUSTED_NO_KEEP_GOING), false)
	BUSTED_ARGS += --no-keep-going
endif

ifneq ($(BUSTED_COVERAGE), false)
	BUSTED_ARGS += --coverage
endif

ifneq ($(BUSTED_EMMY_DEBUGGER), false)
	BUSTED_EMMY_DEBUGGER_ENABLED_ARGS = -e BUSTED_EMMY_DEBUGGER='/usr/local/lib/lua/5.1/emmy_core.so'
endif

KONG_SMOKE_TEST_DEPLOYMENT_PATH := _build/deployment/kong-smoke-test

CONTAINER_CI_KONG_TOOLING_IMAGE_PATH := _build/images/kong-tooling
CONTAINER_CI_KONG_SMOKE_TEST_IMAGE_PATH := _build/images/kong-smoke-test

CONTAINER_CI_NETWORK_NAME := kong-plugin-$(KONG_PLUGIN_NAME)-ci
CONTAINER_CI_KONG_TOOLING_IMAGE_NAME := kong.localhost/kong-plugin-$(KONG_PLUGIN_NAME)-dev-kong-tooling:0.1.0
CONTAINER_CI_KONG_SMOKE_TEST_IMAGE_NAME := kong.localhost/kong-plugin-$(KONG_PLUGIN_NAME)-dev-kong-smoke-test:0.1.0

CONTAINER_CI_REDIS_NAME := kong-plugin-$(KONG_PLUGIN_NAME)-redis
CONTAINER_CI_REDIS_RUN := $(DOCKER) run --rm -d \
	--network='$(CONTAINER_CI_NETWORK_NAME)' \
	--name='$(CONTAINER_CI_REDIS_NAME)' \
	'$(REDIS_IMAGE_NAME):$(REDIS_IMAGE_TAG)'

CONTAINER_CI_POSTGRES_NAME := kong-plugin-$(KONG_PLUGIN_NAME)-postgres
CONTAINER_CI_POSTGRES_RUN := $(DOCKER) run --rm -d \
	-e POSTGRES_USER='kong' \
	-e POSTGRES_PASSWORD='kong' \
	--network='$(CONTAINER_CI_NETWORK_NAME)' \
	--name='$(CONTAINER_CI_POSTGRES_NAME)' \
	'$(POSTGRES_IMAGE_NAME):$(POSTGRES_IMAGE_TAG)' \
	postgres -c 'max_connections=100'

CONTAINER_CI_OPENFGA_NAME := kong-plugin-$(KONG_PLUGIN_NAME)-openfga

CONTAINER_CI_OPENFGA_MIGRATION := $(DOCKER) run $(DOCKER_RUN_FLAGS) \
	-e OPENFGA_DATASTORE_ENGINE=sqlite \
	-e OPENFGA_DATASTORE_URI=file:/data/openfga.sqlite \
	-v '$(PWD)/spec/stub/:/data' \
	--network='$(CONTAINER_CI_NETWORK_NAME)' \
	--name='$(CONTAINER_CI_OPENFGA_NAME)-migration' \
	'$(OPENFGA_IMAGE_NAME):$(OPENFGA_IMAGE_TAG)' \
	migrate --verbose

CONTAINER_CI_OPENFGA_RUN := $(DOCKER) run -d $(DOCKER_RUN_FLAGS) \
	-p 8080:8080 \
	-p 8081:8081 \
	-p 3000:3000 \
	-p 2112:2112 \
	-e OPENFGA_DATASTORE_ENGINE=sqlite \
	-e OPENFGA_DATASTORE_URI=file:/data/openfga.sqlite \
	-e OPENFGA_DATASTORE_MAX_OPEN_CONNS=100 \
	-e OPENFGA_PLAYGROUND_ENABLED=true \
	-v '$(PWD)/spec/stub:/data' \
	--network='$(CONTAINER_CI_NETWORK_NAME)' \
	--name='$(CONTAINER_CI_OPENFGA_NAME)' \
	'$(OPENFGA_IMAGE_NAME):$(OPENFGA_IMAGE_TAG)' \
	run

CONTAINER_CI_OPENFGA_DATA_IMPORT := $(DOCKER) run --rm \
	-e FGA_API_URL='http://$(CONTAINER_CI_OPENFGA_NAME):8080' \
	-v '$(PWD)/$(KONG_SMOKE_TEST_DEPLOYMENT_PATH)/openfga:/openfga' \
	--network='$(CONTAINER_CI_NETWORK_NAME)' \
	--name='$(CONTAINER_CI_OPENFGA_NAME)-data-import' \
	'$(OPENFGA_IMAGE_NAME):$(OPENFGA_IMAGE_TAG)' \
	fga store create --name "Github" --model /openfga/model.fga -v

CONTAINER_CI_OPENFGA_DATA_IMPORT_SHELL := $(DOCKER) run --rm -it \
	-e FGA_API_URL='http://$(CONTAINER_CI_OPENFGA_NAME):8080' \
	-v '$(PWD)/$(KONG_SMOKE_TEST_DEPLOYMENT_PATH)/openfga:/openfga' \
	--network='$(CONTAINER_CI_NETWORK_NAME)' \
	--name='$(CONTAINER_CI_OPENFGA_NAME)-data-import' \
	'$(OPENFGA_CLI_IMAGE_NAME):$(OPENFGA_CLI_IMAGE_TAG)'

CONTAINER_CI_KONG_TOOLING_BUILD = DOCKER_BUILDKIT=1 BUILDKIT_PROGRESS=$(BUILDKIT_PROGRESS) $(DOCKER) build \
	-f '$(CONTAINER_CI_KONG_TOOLING_IMAGE_PATH)/Dockerfile' \
	$(DOCKER_NO_CACHE) \
	-t '$(CONTAINER_CI_KONG_TOOLING_IMAGE_NAME)' \
	--build-arg KONG_IMAGE_NAME='$(KONG_IMAGE_NAME)' \
	--build-arg KONG_IMAGE_TAG='$(KONG_IMAGE_TAG)' \
	--build-arg KONG_TARGET_VERSION='$(KONG_VERSION)' \
	--build-arg KONG_PLUGIN_NAME='$(KONG_PLUGIN_NAME)' \
	--build-arg PONGO_KONG_VERSION='$(PONGO_KONG_VERSION)' \
	--build-arg PONGO_ARCHIVE='$(PONGO_ARCHIVE)' \
	--build-arg STYLUA_VERSION='$(STYLUA_VERSION)' \
	--build-arg EMMY_LUA_DEBUGGER_VERSION='$(EMMY_LUA_DEBUGGER_VERSION)' \
	.

CONTAINER_CI_KONG_SMOKE_TEST_BUILD = DOCKER_BUILDKIT=1 BUILDKIT_PROGRESS=$(BUILDKIT_PROGRESS) $(DOCKER) build \
	-f '$(CONTAINER_CI_KONG_SMOKE_TEST_IMAGE_PATH)/Dockerfile' \
	$(DOCKER_NO_CACHE) \
	-t '$(CONTAINER_CI_KONG_SMOKE_TEST_IMAGE_NAME)' \
	--build-arg KONG_IMAGE_NAME='$(KONG_IMAGE_NAME)' \
	--build-arg KONG_IMAGE_TAG='$(KONG_IMAGE_TAG)' \
	--build-arg KONG_PLUGIN_NAME='$(KONG_PLUGIN_NAME)' \
	--build-arg KONG_PLUGIN_ROCKSPEC_FILE='$(ROCKSPEC_DEV_FILE)' \
	.

CONTAINER_CI_KONG_RUN := MSYS_NO_PATHCONV=1 $(DOCKER) run $(DOCKER_RUN_FLAGS) \
	-v '$(PWD):$(DOCKER_MOUNT_IN_CONTAINER)' \
	'$(KONG_IMAGE_NAME):$(KONG_IMAGE_TAG)'

CONTAINER_CI_KONG_TOOLING_RUN := MSYS_NO_PATHCONV=1 $(DOCKER) run $(DOCKER_RUN_FLAGS) \
	-p 9966:9966 \
	-e KONG_SPEC_TEST_REDIS_HOST='$(CONTAINER_CI_REDIS_NAME)' \
	-e KONG_SPEC_TEST_LIVE_HOSTNAME='$(CONTAINER_CI_OPENFGA_NAME)' \
	-e KONG_LICENSE_PATH=$(DOCKER_MOUNT_IN_CONTAINER)/kong-license.json \
	-e KONG_DNS_ORDER='LAST,A,SRV' \
	-e BUSTED_EMMY_DEBUGGER_HOST='0.0.0.0' \
	-e BUSTED_EMMY_DEBUGGER_PORT='9966' \
	-e BUSTED_EMMY_DEBUGGER_SOURCE_PATH='/usr/local/share/lua/5.1/kong/plugins:/usr/local/share/lua/5.1/kong/enterprise_edition' \
	-e BUSTED_EMMY_DEBUGGER_SOURCE_PATH_MAPPING='$(DOCKER_MOUNT_IN_CONTAINER);$(PWD):/usr/local/share/lua/5.1;$(PWD)/.luarocks:/usr/local/openresty/lualib;$(PWD)/.luarocks' \
	$(BUSTED_EMMY_DEBUGGER_ENABLED_ARGS) \
	--network='$(CONTAINER_CI_NETWORK_NAME)' \
	-v '$(PWD):$(DOCKER_MOUNT_IN_CONTAINER)' \
	-v '$(PWD)/_build/debugger/emmy_debugger.lua:/usr/local/share/lua/5.1/kong/tools/emmy_debugger.lua' \
	-v '$(PWD)/_build/debugger/busted:/kong/bin/busted' \
	'$(CONTAINER_CI_KONG_TOOLING_IMAGE_NAME)'

CONTAINER_CI_KONG_SMOKE_TEST_RUN_SERVER_NAME = kong-plugin-$(KONG_PLUGIN_NAME)-smoke-test
CONTAINER_CI_KONG_SMOKE_TEST_RUN_SERVER := MSYS_NO_PATHCONV=1 $(DOCKER) run $(DOCKER_RUN_FLAGS) \
	-p 8000:8000 \
	-p 8443:8443 \
	-p 8010:8010 \
	-p 8001:8001 \
	-p 8002:8002 \
	-e KONG_ANONYMOUS_REPORTS=off \
	-e KONG_LOG_LEVEL=debug \
	-e KONG_PLUGINS='bundled,$(KONG_PLUGIN_NAME)' \
	-e KONG_DATABASE=off \
	-e KONG_VITALS=off \
	-e KONG_NGINX_HTTP_INCLUDE=/kong/smoke-test.nginx.conf \
	-e KONG_DECLARATIVE_CONFIG=/kong/kong.yaml \
	-e KONG_LICENSE_PATH=$(DOCKER_MOUNT_IN_CONTAINER)/kong-license.json \
	-e "KONG_ADMIN_LISTEN=0.0.0.0:8001" \
	-e KONG_ADMIN_GUI_URL=http://localhost:8002/ \
	--env-file .env \
	--network='$(CONTAINER_CI_NETWORK_NAME)' \
	-v '$(PWD)/$(KONG_SMOKE_TEST_DEPLOYMENT_PATH)/kong/smoke-test.nginx.conf:/kong/smoke-test.nginx.conf' \
	-v '$(PWD)/$(KONG_SMOKE_TEST_DEPLOYMENT_PATH)/kong/kong.local.yaml:/kong/kong.yaml' \
	--name '$(CONTAINER_CI_KONG_SMOKE_TEST_RUN_SERVER_NAME)' \
	'$(CONTAINER_CI_KONG_SMOKE_TEST_IMAGE_NAME)'

CONTAINER_CI_KONG_SMOKE_TEST_RUN_TEST := MSYS_NO_PATHCONV=1 $(DOCKER) run $(DOCKER_RUN_FLAGS) \
	--env-file .env \
	-v '$(PWD)/$(KONG_SMOKE_TEST_DEPLOYMENT_PATH)/script/smoke-test.sh:/smoke-test.sh' \
	--network='$(CONTAINER_CI_NETWORK_NAME)' \
	--entrypoint=/smoke-test.sh \
	docker.io/redhat/ubi9-minimal:9.5-1733767867@sha256:dee813b83663d420eb108983a1c94c614ff5d3fcb5159a7bd0324f0edbe7fca1 '$(CONTAINER_CI_KONG_SMOKE_TEST_RUN_SERVER_NAME)'

RM := rm
RMDIR := $(RM) -rf

TAG ?=

.PHONY: all
all: test

$(ROCKSPEC_DEV_FILE): kong-plugin.rockspec
	cp kong-plugin.rockspec $(ROCKSPEC_DEV_FILE)
	$(CONTAINER_CI_KONG_RUN) sh -c '(cd $(DOCKER_MOUNT_IN_CONTAINER); luarocks new_version $(ROCKSPEC_DEV_FILE) --tag=dev-0 --dir .)'

$(ROCKSPEC_RELEASE_FILE): $(ROCKSPEC_DEV_FILE)
	$(CONTAINER_CI_KONG_RUN) sh -c '(cd $(DOCKER_MOUNT_IN_CONTAINER); luarocks new_version $(ROCKSPEC_DEV_FILE) --tag=v$(KONG_PLUGIN_VERSION)-$(KONG_PLUGIN_REVISION) --dir .)'

.PHONY: release-rockspec
release-rockspec: $(ROCKSPEC_RELEASE_FILE)

.PHONY: release-rockspec
release-info:
	@echo "VERSION=v$(KONG_PLUGIN_VERSION)-$(KONG_PLUGIN_REVISION)"
	@echo "ROCKSPEC_RELEASE_FILE=$(ROCKSPEC_RELEASE_FILE)"

# Rebuild the rock file every time the rockspec or the kong/**/.lua files change
$(ROCK_RELEASE_FILE): container-ci-kong-tooling $(ROCKSPEC_RELEASE_FILE) $(PLUGIN_FILES)
	$(CONTAINER_CI_KONG_TOOLING_RUN) sh -c '(cd $(DOCKER_MOUNT_IN_CONTAINER); luarocks make --pack-binary-rock --deps-mode none $(ROCKSPEC_RELEASE_FILE))'

test-results:
	mkdir -p $(TEST_RESULTS_PATH)

.PHONY: tail-logs
tail-logs:
	tail -F servroot/logs/*.log | grep --line-buffered --color '\[\($(KONG_PLUGIN_NAME)\|dns-client\|kong\)\]\|$$'

.PHONY: test
test: lint test-unit

.PHONY: pack
pack: $(ROCK_RELEASE_FILE)

.PHONY: container-ci-kong-tooling
container-ci-kong-tooling: $(ROCKSPEC_DEV_FILE) container-network-ci
	$(CONTAINER_CI_KONG_TOOLING_BUILD)

.PHONY: container-ci-kong-tooling-debug
container-ci-kong-tooling-debug: BUILDKIT_PROGRESS = 'plain'
container-ci-kong-tooling-debug: DOCKER_NO_CACHE = '--no-cache'
container-ci-kong-tooling-debug: container-ci-kong-tooling

.PHONY: container-ci-kong-smoke-test
container-ci-kong-smoke-test: $(ROCKSPEC_DEV_FILE) container-network-ci
	$(CONTAINER_CI_KONG_SMOKE_TEST_BUILD)

.PHONY: container-ci-kong-smoke-test-debug
container-ci-kong-smoke-test-debug: BUILDKIT_PROGRESS = 'plain'
container-ci-kong-smoke-test-debug: DOCKER_NO_CACHE = '--no-cache'
container-ci-kong-smoke-test-debug: container-ci-kong-smoke-test

.PHONY: container-network-ci
container-network-ci:
	$(DOCKER) network inspect '$(CONTAINER_CI_NETWORK_NAME)' >/dev/null 2>&1 || $(DOCKER) network create --driver bridge '$(CONTAINER_CI_NETWORK_NAME)'

.PHONY: service-redis
service-redis: container-network-ci
	$(DOCKER) container inspect '$(CONTAINER_CI_REDIS_NAME)' > /dev/null 2>&1 || $(CONTAINER_CI_REDIS_RUN)

.PHONY: service-postgres
service-postgres: container-network-ci
	$(DOCKER) container inspect '$(CONTAINER_CI_POSTGRES_NAME)' > /dev/null 2>&1 || $(CONTAINER_CI_POSTGRES_RUN)

.PHONY: service-openfga-migration
service-openfga-migration: container-network-ci
	$(DOCKER) container inspect '$(CONTAINER_CI_OPENFGA_NAME)' > /dev/null 2>&1 || $(CONTAINER_CI_OPENFGA_MIGRATION)

.PHONY: service-openfga-run
service-openfga-run: container-network-ci
	$(DOCKER) container inspect '$(CONTAINER_CI_OPENFGA_NAME)' > /dev/null 2>&1 || $(CONTAINER_CI_OPENFGA_RUN)

.PHONY: service-openfga
service-openfga: container-network-ci service-openfga-migration service-openfga-run

.PHONY: service-openfga-data-import
service-openfga-data-import: service-openfga
	sleep 1
#	$(CONTAINER_CI_OPENFGA_DATA_IMPORT_SHELL) store create --name "Github"
	$(CONTAINER_CI_OPENFGA_DATA_IMPORT_SHELL) store import --store-id 01JF958AHC0F7CT35GCFN4EHP6 --file /openfga/store.fga.yaml

.PHONY: stop-service-redis
stop-service-redis:
	-$(DOCKER) kill '$(CONTAINER_CI_REDIS_NAME)'

.PHONY: stop-service-postgres
stop-service-postgres:
	-$(DOCKER) kill '$(CONTAINER_CI_POSTGRES_NAME)'

.PHONY: stop-service-openfga
stop-service-openfga:
	-$(DOCKER) kill '$(CONTAINER_CI_OPENFGA_NAME)'

.PHONY: stop-services
stop-services: stop-service-redis stop-service-openfga stop-service-postgres

.PHONY: lint
lint: container-ci-kong-tooling
	$(CONTAINER_CI_KONG_TOOLING_RUN) sh -c '(cd $(DOCKER_MOUNT_IN_CONTAINER); luacheck --no-default-config --config .luacheckrc .)'

.PHONY: format-code
format-code: container-ci-kong-tooling
	$(CONTAINER_CI_KONG_TOOLING_RUN) sh -c '(cd $(DOCKER_MOUNT_IN_CONTAINER); stylua --check . || stylua --verify .)'

.PHONY: test-unit
test-unit: clean-test-results test-results container-ci-kong-tooling clean-servroot service-openfga
	$(CONTAINER_CI_KONG_TOOLING_RUN) busted $(BUSTED_ARGS)
	@if [ -f $(TEST_RESULTS_PATH)/luacov.stats.out ]; then \
		$(CONTAINER_CI_KONG_TOOLING_RUN) sh -c '(cd $(DOCKER_MOUNT_IN_CONTAINER)/$(TEST_RESULTS_PATH); luacov-console $(DOCKER_MOUNT_IN_CONTAINER)/kong; luacov-console -s);' ;\
		$(CONTAINER_CI_KONG_TOOLING_RUN) sh -c '(cd $(DOCKER_MOUNT_IN_CONTAINER)/$(TEST_RESULTS_PATH); luacov -r html; mv luacov.report.out luacov.report.html);' ;\
		echo "Coverage report: file://$(PWD)/$(TEST_RESULTS_PATH)/luacov.report.html" ;\
		$(CONTAINER_CI_KONG_TOOLING_RUN) sh -c "(cd $(DOCKER_MOUNT_IN_CONTAINER)/$(TEST_RESULTS_PATH); luacov -r lcov; sed -e 's|/kong-plugin/||' -e 's/^\(DA:[0-9]\+,[0-9]\+\),[^,]*/\1/' luacov.report.out > lcov.info)" ;\
	fi

.PHONY: tooling-shell
tooling-shell: container-ci-kong-tooling
	$(CONTAINER_CI_KONG_TOOLING_RUN) bash

.PHONY: smoke-test-run-server
smoke-test-run-server: clean-servroot container-ci-kong-smoke-test
smoke-test-run-server: service-postgres service-openfga
	$(CONTAINER_CI_KONG_SMOKE_TEST_RUN_SERVER)

.PHONY: smoke-test-run-server-shell
smoke-test-run-server-shell: container-ci-kong-smoke-test container-network-ci
	$(CONTAINER_CI_KONG_SMOKE_TEST_RUN_SERVER) bash

.PHONY: smoke-test-run-test
smoke-test-run-test: container-network-ci
	$(CONTAINER_CI_KONG_SMOKE_TEST_RUN_TEST)

.PHONY: lua-language-server-add-kong
lua-language-server-add-kong: container-ci-kong-tooling
	-mkdir -p .luarocks
	$(CONTAINER_CI_KONG_TOOLING_RUN) cp -rv /usr/local/share/lua/5.1/. $(DOCKER_MOUNT_IN_CONTAINER)/.luarocks
	$(CONTAINER_CI_KONG_TOOLING_RUN) cp -rv /kong $(DOCKER_MOUNT_IN_CONTAINER)/.luarocks
	$(CONTAINER_CI_KONG_TOOLING_RUN) cp -rv /usr/local/openresty/lualib/. $(DOCKER_MOUNT_IN_CONTAINER)/.luarocks

.PHONY: clean-test-results
clean-test-results:
	-$(RMDIR) test-results

.PHONY: clean-servroot
clean-servroot:
	-$(RMDIR) $(SERVROOT_PATH)

.PHONY: clean-rockspec
clean-rockspec:
	-$(RMDIR) kong-plugin-*.rockspec
#-git ls-files --others --exclude-standard --ignored -- | grep 'kong-plugin-.*\.rockspec' | xargs $(RM) || true

.PHONY: clean-rock
clean-rock:
	-$(RMDIR) *.rock

.PHONY: clean-openfga-sqlite
clean-openfga-sqlite: clean
	-$(RMDIR) spec/stub/openfga.sqlite*

.PHONY: clean-container-ci-kong-tooling
clean-container-ci-kong-tooling:
	-$(DOCKER) rmi '$(CONTAINER_CI_KONG_TOOLING_IMAGE_NAME)'

.PHONY: clean-container-ci-kong-smoke-test
clean-container-ci-kong-smoke-test:
	-$(DOCKER) rmi '$(CONTAINER_CI_KONG_SMOKE_TEST_IMAGE_NAME)'

.PHONY: clean-redis
clean-redis:
	-$(DOCKER) rm --force '$(CONTAINER_CI_REDIS_NAME)'

.PHONY: clean-postgres
clean-postgres:
	-$(DOCKER) rm --force '$(CONTAINER_CI_POSTGRES_NAME)'

.PHONY: clean-openfga
clean-openfga:
	-$(DOCKER) rm --force '$(CONTAINER_CI_OPENFGA_NAME)'

.PHONY: clean-container-smoke-test-network
clean-container-smoke-test-network:
	-$(DOCKER) network rm '$(CONTAINER_CI_NETWORK_NAME)'

.PHONY: clean
clean: clean-test-results
clean: clean-rock clean-rockspec
clean: clean-servroot
clean: clean-container-ci-kong-tooling clean-container-ci-kong-smoke-test clean-container-smoke-test-network
clean: clean-redis clean-postgres clean-openfga
	-$(RMDIR) .luarocks
