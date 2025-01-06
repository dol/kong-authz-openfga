# Kong plugin kong-authz-openfga

The goal of this plugin is to integrate Kong with OpenFGA for fine-grained authorization. It allows you to define and enforce access control policies using OpenFGA.

## Installation

Install the plugin using `luarocks`.

```sh
luarocks install kong-plugin-kong-authz-openfga
```

## Enable it in Kong

<https://docs.konghq.com/gateway/3.9.x/reference/configuration/#plugins>

## Capabilities

- Integrates with OpenFGA for authorization
- Supports Lua expressions for dynamic policy evaluation

## Limitations

- No caching support yet

## Example minimal configuration

Below is the minimal example configuration one might use in `declarative_config`:

```yaml
- name: kong-authz-openfga
  config:
    host: localhost
    port: 1234
    store_id: "your_store_id"
    tuple:
      user: "user_id"
      relation: "relation"
      object: "object_id"
```

## Example full configuration

Below is the example configuration one might use in `declarative_config`:

```yaml
- name: kong-authz-openfga
  config:
    host: localhost
    port: 1234
    https: true
    https_verify: true
    max_attempts: 3
    failed_attempts_backoff_timeout: 1000
    timeout: 10000
    keepalive: 60000
    store_id: "your_store_id"
    model_id: "your_model_id"
    api_token: "your_api_token"
    api_token_issuer: "your_api_token_issuer"
    api_audience: "your_api_audience"
    api_client_id: "your_api_client_id"
    api_client_secret: "your_api_client_secret"
    api_token_cache: 600
    tuple:
      user: "user_id"
      relation: "relation"
      object: "object_id"
    contextual_tuples:
      - user: "user_id"
        relation: "relation"
        object: "object_id"
```

## Configuration

| Property                                                                    | Default value | Description                                                                                                                                                                                                              |
| --------------------------------------------------------------------------- | ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `host`<br/>_required_<br/><br/>**Type:** hostname (string)                  | -             | Hostname of the OpenFGA server                                                                                                                                                                                           |
| `port`<br/>_required_<br/><br/>**Type:** port (number)                      | 8080          | HTTP API port of OpenFGA                                                                                                                                                                                                 |
| `https`<br/>_optional_<br/><br/>**Type:** boolean                           | false         | Use HTTPS to connect to OpenFGA                                                                                                                                                                                          |
| `https_verify`<br/>_optional_<br/><br/>**Type:** boolean                    | false         | Verify HTTPS certificate                                                                                                                                                                                                 |
| `max_attempts`<br/>_optional_<br/><br/>**Type:** integer                    | 3             | The maximum number of attempts to make when querying OpenFGA. This is useful for handling transient errors and retries.                                                                                                  |
| `failed_attempts_backoff_timeout`<br/>_optional_<br/><br/>**Type:** integer | 1000          | The backoff timeout in milliseconds between retry attempts when querying OpenFGA. This helps to avoid overwhelming the server with rapid retries. Formula: `failed_attempts_backoff_timeout * 2 ^ (attempts - 1) / 1000` |
| `timeout`<br/>_optional_<br/><br/>**Type:** number                          | 10000         | The total timeout time in milliseconds for a request and response cycle.                                                                                                                                                 |
| `keepalive`<br/>_optional_<br/><br/>**Type:** number                        | 60000         | The maximal idle timeout in milliseconds for the current connection. See [tcpsock:setkeepalive](https://github.com/openresty/lua-nginx-module#tcpsocksetkeepalive) for more details.                                     |
| `store_id`<br/>_required_<br/><br/>**Type:** string                         | -             | The store ID in OpenFGA                                                                                                                                                                                                  |
| `model_id`<br/>_optional_<br/><br/>**Type:** string                         | -             | Optional model ID (version). Latest is used if this is empty                                                                                                                                                             |
| `api_token`<br/>_optional_<br/><br/>**Type:** string                        | -             | Optional API token                                                                                                                                                                                                       |
| `api_token_issuer`<br/>_optional_<br/><br/>**Type:** string                 | -             | API token issuer                                                                                                                                                                                                         |
| `api_audience`<br/>_optional_<br/><br/>**Type:** string                     | -             | API audience                                                                                                                                                                                                             |
| `api_client_id`<br/>_optional_<br/><br/>**Type:** string                    | -             | API client ID                                                                                                                                                                                                            |
| `api_client_secret`<br/>_optional_<br/><br/>**Type:** string                | -             | API client secret                                                                                                                                                                                                        |
| `api_token_cache`<br/>_optional_<br/><br/>**Type:** number                  | 600           | API token cache duration in seconds                                                                                                                                                                                      |
| `tuple`<br/>_required_<br/><br/>**Type:** record                            | -             | Tuple key for authorization                                                                                                                                                                                              |
| `contextual_tuples`<br/>_optional_<br/><br/>**Type:** set                   | {}            | Set of contextual tuples for authorization                                                                                                                                                                               |

## Plugin version

Version: 0.1.0

## Plugin priority

Priority: 901

## Plugin handler phases

Handler phases:

- access

# Local development

For local development, building and testing a containerized environment is used. The containerized environment is defined in the
[Makefile](Makefile). For the unit and integration test the [busted](https://olivinelabs.com/busted/) framework is used. To test
Kong the spec helper from the [kong-pongo](https://github.com/Kong/kong-pongo) toolkit is bundled in the project.

## Prerequisites for local development

- git
- make (download it from <https://sourceforge.net/projects/ezwinports/files/make-4.4-without-guile-w32-bin.zip/download>)
- bash
- Docker
- A text editor

## Initial setup

For the initial setup of the local development environment, the following steps are required:

1. Copy the file [.env.tpl](.env.tpl) to .env and adjust the values to your needs.
2. Docker is running and is able to pull images from docker.io.
3. `make` is installed

## Run lint, unit and integration tests

To run the `lint`, `unit` and `integration` tests just execute `make`. This will all run all tests in a containerized environment.

```sh
make
```

### Lint

Check linting and general Lua programming errors with `make lint`

```sh
make lint
```

### Run test

```sh
make test-unit
```

| Runtime configuration | Description                                                                                       |
| --------------------- | ------------------------------------------------------------------------------------------------- |
| BUSTED_NO_KEEP_GOING  | When set to `true`, `busted` will stop running tests after the first failure. Default is `false`. |
| BUSTED_COVERAGE       | When set to `true`, `busted` will generate a code coverage report. Default is `false`.            |
| BUSTED_EMMY_DEBUGGER  | When set to `true`, enables the EMMY Lua debugger for `busted` tests. Default is `false`.         |

#### Run test with EMMY Debugger

##### Prerequisites

- Install the [EmmyLua](https://marketplace.visualstudio.com/items?itemName=tangzx.emmylua) extension in VS Code

##### Usage

1. Start your tests with debugging enabled:

   `make test-unit BUSTED_EMMY_DEBUGGER=true`

2. In VS Code:
   - Set breakpoints in your Lua code
   - Start the debugger using F5 or the Debug panel
   - The debugger will attach to the running tests
3. Debug features available:
   - Step through code
   - Inspect variables
   - View call stack
   - Set conditional breakpoints

The debugger will automatically map source files between your local workspace and the container environment using the configured source roots.

### Pack the plugin into a .rock

```sh
make pack
```

### Format code

Format the code with `make format-code`

```sh
make format-code
```

### Inspect logs from test runs

Run each command in a separate terminal. Align the terminal side-by-side for a better overall view.

You might want to prefix the `make tail-logs` commands with `winpty` for better signal/abort handling.

Tail the kong logs.

```sh
make tail-logs
```

Run the tests.

```sh
make test-unit
```

Run the tests with a BUSTED_FILTER and don't continue on the first failure.

```sh
make test-unit BUSTED_FILTER="test case name" BUSTED_NO_KEEP_GOING=1
```

> For further debugging the Kong working directory is mounted to your local [./servroot](./servroot) folder. The working directory
> contains Kong configuration, logs and additional settings.<br><br>
> 🚨 For each test case the Kong working directory is wiped. Just use a combination of BUSTED_FILTER and BUSTED_NO_KEEP_GOING to
> get a faster feedback loop.

### Run a smoke test

Make sure to populate all the environment variables in the [.env](.env) file. The smoke test will use the values from the .env file.

In order to run the smoke test two terminal windows are required. In the first terminal window run the following command:

```sh
make smoke-test-run-server
```

In the second terminal window run the following command:

```sh
make smoke-test-run-test
```

The logs from the smoke test are visible in the first terminal window.

### Clean local development

It's recommended to clean the local development after a new git fetch&rebase/pull.

```sh
make clean
```

## Run CI lint, unit and integration tests

The project integrates with GitHub Actions for CI. The CI pipeline runs the lint, unit and integration tests.

## Test against a different Kong version

To test the plugin against a different Kong version change the `KONG_VERSION` and the `KONG_IMAGE_HASH` in the [plugin.properties](plugin.properties) file.

## Behind the scene

The local development environment is inspired by the `kong-pongo` toolkit. The spec helper from `kong-pongo` is bundled in the project.
All the linting and test are running in a containerized environment that is based on the [\_build/images/kong-tooling/Dockerfile](_build/images/kong-tooling/Dockerfile).
This image could also be reused for CI.

Similar to the tooling image the smoke test run in a different containerized environment that is based on the [\_build/images/kong-smoke-test/Dockerfile](_build/images/kong-smoke-test/Dockerfile).
The smoke test uses the Kong configuration and script from [\_build/deployment/kong-smoke-test](_build/deployment/kong-smoke-test).
The smoke test container emulates a Kong environment that installs a .rocks (Luarocks package) file.

### Mock service

The project bundles a mock server for OpenFGA.

#### Mock service in Lua

@TODO: TBD

### CI container image

The CI container image can be found under \_build/images/kong-tooling/Dockerfile. The image is based on the official Kong image and contains all the necessary tools to run the lint, unit and integration tests.

## Recommended Visual Studio Code extensions

- <https://marketplace.visualstudio.com/items?itemName=sumneko.lua>
- <https://marketplace.visualstudio.com/items?itemName=dwenegar.vscode-luacheck>
- <https://marketplace.visualstudio.com/items?itemName=tangzx.emmylua>

# Release a new version

1. Checkout the main branch
   1. `git checkout main`
2. Update the version number in [plugin.properties](plugin.properties)
3. Update the version number in [README.md](README.md)
4. Generate the release rockspec file
   1. `make release-rockspec`
5. Update the version number in [kong/plugins/kong-authz-openfga/handler.lua](kong/plugins/kong-authz-openfga/handler.lua)
6. Add a new section to [CHANGELOG.md](CHANGELOG.md) with the release highlights
7. Commit the changes, create a tag and push changes and tag to the remote repository
   1. `git add plugin.properties *.rockspec README.md kong/plugins/*/handler.lua CHANGELOG.md`
   2. `git commit -m "Release x.y.z-r"`
   3. `git tag vx.y.z-r`
   4. `git push`
   5. `git push --tags`
8. @TODO: Add step to perform a release in GitHub
