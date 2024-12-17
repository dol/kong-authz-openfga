local assert = require("luassert.assert")
local helpers = require("spec.helpers")
local utils = require("kong.tools.utils")
local http = require("resty.http")
local cjson = require("cjson")
local openfga_mock = require("spec.mock.openfga")

local PLUGIN_NAME = "kong-authz-openfga"

-- Routes
local ROUTE_MOCK_HOSTNAME = "mock.test"

-- Mock and live servers
local MOCK_HOSTNAME = "localhost"
local MOCK_PORT = 8080
local LIVE_HOSTNAME = os.getenv("KONG_SPEC_TEST_LIVE_HOSTNAME") or "localhost"
local LIVE_PORT = 8080

local TEST_MODES = {
  mock = {
    hostname = MOCK_HOSTNAME,
    port = MOCK_PORT,
  },
  -- live = {
  --   hostname = LIVE_HOSTNAME,
  --   port = LIVE_PORT,
  -- },
}

local setup_fga = function(mode)
  if mode == "mock" then
    local mock_server = openfga_mock.server(MOCK_PORT)
    mock_server:start()

    return "allowed"
  end

  local httpc = http.new()
  local res, err = httpc:request_uri("http://" .. LIVE_HOSTNAME .. ":" .. LIVE_PORT .. "/stores", {
    method = "POST",
    body = cjson.encode({
      name = utils.uuid(),
    }),
    headers = {
      ["Content-Type"] = "application/json",
    },
  })

  if not res then
    return nil, err
  end

  local store_id = cjson.decode(res.body).id

  local model = [[
{
  "schema_version": "1.1",
  "type_definitions": [
    {
      "type": "user"
    },
    {
      "metadata": {
        "relations": {
          "ip_based_access_policy": {
            "directly_related_user_types": [
              {
                "condition": "in_company_network",
                "relation": "member",
                "type": "organization"
              }
            ]
          },
          "member": {
            "directly_related_user_types": [
              {
                "type": "user"
              }
            ]
          }
        }
      },
      "relations": {
        "ip_based_access_policy": {
          "this": {}
        },
        "member": {
          "this": {}
        }
      },
      "type": "organization"
    },
    {
      "metadata": {
        "relations": {
          "can_view": {},
          "organization": {
            "directly_related_user_types": [
              {
                "type": "organization"
              }
            ]
          },
          "viewer": {
            "directly_related_user_types": [
              {
                "type": "user"
              }
            ]
          }
        }
      },
      "relations": {
        "can_view": {
          "intersection": {
            "child": [
              {
                "computedUserset": {
                  "relation": "viewer"
                }
              },
              {
                "tupleToUserset": {
                  "computedUserset": {
                    "relation": "ip_based_access_policy"
                  },
                  "tupleset": {
                    "relation": "organization"
                  }
                }
              }
            ]
          }
        },
        "organization": {
          "this": {}
        },
        "viewer": {
          "this": {}
        }
      },
      "type": "document"
    }
  ],
  "conditions": {
    "in_company_network": {
      "expression": "user_ip.in_cidr(cidr)",
      "name": "in_company_network",
      "parameters": {
        "cidr": {
          "type_name": "TYPE_NAME_STRING"
        },
        "user_ip": {
          "type_name": "TYPE_NAME_IPADDRESS"
        }
      }
    }
  }
}
  ]]
  local model_create = "http://"
    .. LIVE_HOSTNAME
    .. ":"
    .. LIVE_PORT
    .. "/stores/"
    .. store_id
    .. "/authorization-models"
  local res_mode, err_model = httpc:request_uri(model_create, {
    method = "POST",
    body = model,
    headers = {
      ["Content-Type"] = "application/json",
    },
  })

  if not res_mode then
    return nil, err_model
  end

  print("Model response body: " .. cjson.encode(res_mode.body))

  local tuples = [[
{
  "writes": {
    "tuple_keys": [
      {
        "user": "organization:acme#member",
        "relation": "ip_based_access_policy",
        "object": "organization:acme",
        "condition": {
          "name": "in_company_network",
          "context": {
            "cidr": "192.168.0.0/24"
          }
        }
      },
      {
        "user": "organization:acme",
        "relation": "organization",
        "object": "document:1"
      },
      {
        "user": "user:anne",
        "relation": "viewer",
        "object": "document:1"
      },
      {
        "user": "user:anne",
        "relation": "member",
        "object": "organization:acme"
      }
    ]
  }
}
  ]]

  local tuples_create = "http://" .. LIVE_HOSTNAME .. ":" .. LIVE_PORT .. "/stores/" .. store_id .. "/write"
  local tuples_mode, err_tuples = httpc:request_uri(tuples_create, {
    method = "POST",
    body = tuples,
    headers = {
      ["Content-Type"] = "application/json",
    },
  })

  if not tuples_mode then
    return nil, err_tuples
  end

  print("Tuples response body: " .. cjson.encode(tuples_mode.body))

  local check = [[
{
  "tuple_key": {
    "user": "user:anne",
    "relation": "can_view",
    "object": "document:1"
  },
  "context": { "user_ip": "193.168.0.1" }
}
  ]]
  local check_create = "http://" .. LIVE_HOSTNAME .. ":" .. LIVE_PORT .. "/stores/" .. store_id .. "/check"
  local check_mode, err_check = httpc:request_uri(check_create, {
    method = "POST",
    body = check,
    headers = {
      ["Content-Type"] = "application/json",
    },
  })

  if not check_mode then
    return nil, err_check
  end

  print("Check response body: " .. cjson.encode(check_mode.body))

  return cjson.decode(res.body).id
end

for _, strategy in helpers.all_strategies({ "postgres", "off" }) do
  for mode, connection_details in pairs(TEST_MODES) do
    describe(PLUGIN_NAME .. ": (#access) [#" .. strategy .. "] [#" .. mode .. "]", function()
      local http_client

      lazy_setup(function()
        local bp = helpers.get_db_utils(strategy, nil, { PLUGIN_NAME })

        local store_id, fge_err = setup_fga(mode)

        assert.not_nil(store_id)
        assert.is_nil(fge_err)

        local route_mock = bp.routes:insert({
          hosts = { ROUTE_MOCK_HOSTNAME },
        })
        bp.plugins:insert({
          name = PLUGIN_NAME,
          route = { id = route_mock.id },
          config = {
            host = connection_details.hostname,
            port = connection_details.port,
            store_id = store_id,
            tuple = {
              user = "user:anne",
              relation = "can_view",
              object = "document",
            },
            contextual_tuples = {
              {
                user = "organization:acme#member",
                relation = "ip_based_access_policy",
                object_by_lua = "return kong.client.get_ip()",
              },
            },
          },
        })

        -- start kong
        assert(helpers.start_kong({
          -- set the strategy
          database = strategy,
          -- use the custom test template to create a local mock server
          nginx_conf = "spec/fixtures/custom_nginx.template",
          -- make sure our plugin gets loaded
          plugins = PLUGIN_NAME,
        }))
      end)

      lazy_teardown(function()
        helpers.stop_kong(nil, true)
      end)

      before_each(function()
        http_client = helpers.proxy_client()
      end)

      after_each(function()
        if http_client then
          http_client:close()
        end
      end)

      describe("request to #mock", function()
        it("reqest allow", function()
          local r = http_client:post("/request", {
            headers = {
              ["host"] = ROUTE_MOCK_HOSTNAME,
            },
          })

          assert.response(r).has.status(ngx.HTTP_OK)

          local body = assert.response(r).has.jsonbody()
          assert.equal(ROUTE_MOCK_HOSTNAME, body.headers["x-forwarded-host"])
        end)

        it("reqest deny", function()
          local r = http_client:post("/request", {
            headers = {
              ["host"] = ROUTE_MOCK_HOSTNAME,
            },
          })

          assert.response(r).has.status(ngx.HTTP_OK)

          local body = assert.response(r).has.jsonbody()
          assert.equal(ROUTE_MOCK_HOSTNAME, body.headers["x-forwarded-host"])

          -- assert.logfile().has.line("xyz", true)
        end)
      end)
    end)
  end
end
