local PLUGIN_NAME = "kong-authz-openfga"

-- helper function to validate data against a schema
local validate
do
  local validate_entity = require("spec.helpers").validate_plugin_config_schema
  local plugin_schema = require("kong.plugins." .. PLUGIN_NAME .. ".schema")

  function validate(data)
    return validate_entity(data, plugin_schema)
  end
end

describe(PLUGIN_NAME .. ": (#schema)", function()
  it("accepts valid minimal config", function()
    local ok, err = validate({
      host = "localhost",
      store_id = "some_store_id",
      tuple = {
        user = "user:anne",
        relation = "can_view",
        object = "group:finance",
      },
    })
    assert.is_nil(err)
    assert.is_truthy(ok)
  end)

  it("accepts valid minimal config with by lua", function()
    local ok, err = validate({
      host = "localhost",
      store_id = "some_store_id",
      tuple = {
        user_by_lua = "return 'user:anne'",
        relation_by_lua = "return 'can_view'",
        object_by_lua = "return 'group:finance'",
      },
    })
    assert.is_nil(err)
    assert.is_truthy(ok)
  end)

  it("accepts valid full config", function()
    local ok, err = validate({
      host = "localhost",
      port = 1234,
      https = true,
      https_verify = true,
      max_attempts = 3,
      failed_attempts_backoff_timeout = 1000,
      store_id = "store_id",
      model_id = "model_id",
      timeout = 1000,
      keepalive = 6000,
      tuple = {
        user = "user:anne",
        relation = "can_view",
        object = "group:finance",
      },
      contextual_tuples = {
        {
          user = "user:anne",
          relation = "user",
          object = "ip-address-range:10.0.0.0/16",
        },
      },
    })
    assert.is_nil(err)
    assert.is_truthy(ok)
  end)

  it("does not accepts missing required fields", function()
    local ok, err = validate({
      host = "localhost",
      tuple = {
        user = "user:anne",
        relation = "can_view",
        object = "group:finance",
      },
    })
    assert.is_same({
      ["config"] = {
        ["store_id"] = "required field missing",
      },
    }, err)
    assert.is_falsy(ok)
  end)
end)
