local assert = require("luassert.assert")
local cjson = require("cjson")

local PLUGIN_NAME = "kong-authz-openfga"

local CONFIG_BASIC = {
  host = "localhost",
  port = "8080",
  store_id = "allowed",
  tuple = {
    user = "user:anne",
    relation = "can_view",
    object = "document",
  },
  contextual_tuples = {},
}

local CONFIG_BASIC_CONTEXTUAL = {
  host = "localhost",
  port = "8080",
  store_id = "allowed",
  tuple = {
    user = "user:anne",
    relation = "can_view",
    object = "document",
  },
  contextual_tuples = {
    {
      user = "organization:acme#member",
      relation = "ip_based_access_policy",
      object = "10.2.0.2",
    },
  },
}

local CONFIG_SANDBOX = {
  host = "localhost",
  port = "8080",
  store_id = "allowed",
  tuple = {
    user_by_lua = "return 'user:anne'",
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
}

local CONFIGS = {
  basic = CONFIG_BASIC,
  basic_contextual = CONFIG_BASIC_CONTEXTUAL,
  sandbox = CONFIG_SANDBOX,
}

describe(PLUGIN_NAME .. ": (unit)", function()
  local plugin
  local request_body, exit_status, exit_body, log_lines
  local openfga_mock_response

  local log_fn = function(...)
    table.insert(log_lines, { ... })
  end

  setup(function()
    -- Mock Kong functions
    _G.kong = {
      configuration = {
        untrusted_lua = "sandbox",
      },
      log = {
        err = log_fn,
        debug = log_fn,
      },
      response = {
        exit = function(status, body, _)
          exit_status = status
          exit_body = body
        end,
      },
      client = {
        get_ip = function()
          return "10.2.0.2"
        end,
      },
    }

    package.loaded["resty.http"] = nil
    local http = require("resty.http")
    -- Mock the http module
    http.new = function()
      return {
        set_timeout = function() end,
        request_uri = function(_, _, params)
          request_body = params.body
          return {
            status = 200,
            body = openfga_mock_response,
          }
        end,
      }
    end

    -- load the plugin code
    plugin = require("kong.plugins." .. PLUGIN_NAME .. ".handler")
  end)

  for mode, config in pairs(CONFIGS) do
    describe("[#" .. mode .. "]", function()
      -- Clean the state between each test
      before_each(function()
        openfga_mock_response = ""
        request_body = nil
        exit_status = nil
        exit_body = nil
        log_lines = {}
      end)

      after_each(function()
        print("### Captured log line START")
        for _, line in ipairs(log_lines) do
          print("  ", line)
        end
        print("### Captured log line END")
      end)

      it("invalid mock response", function()
        openfga_mock_response = "invalid json"
        plugin:access(config)
        assert.equal(500, exit_status)
        assert.equal("An unexpected error occurred", exit_body)
      end)

      it("allow", function()
        openfga_mock_response = [[{"allowed": true}]]
        plugin:access(config)
        assert.is_nil(exit_status)
        assert.is_nil(exit_body)
        local request_body_json = cjson.decode(request_body)

        assert.equal("user:anne", request_body_json.tuple_key.user)
        assert.equal("can_view", request_body_json.tuple_key.relation)
        assert.equal("document", request_body_json.tuple_key.object)
        if #config.contextual_tuples > 1 then
          assert.equal("organization:acme#member", request_body_json.contextual_tuples.tuple_keys[1].user)
          assert.equal("ip_based_access_policy", request_body_json.contextual_tuples.tuple_keys[1].relation)
          assert.equal("10.2.0.2", request_body_json.contextual_tuples.tuple_keys[1].object)
        end
      end)

      it("deny", function()
        openfga_mock_response = [[{"allowed": false}]]
        plugin:access(config)
        assert.equal(403, exit_status)
        assert.equal("Forbidden", exit_body)
      end)
    end)
  end
end)
