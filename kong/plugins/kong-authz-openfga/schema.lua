local plugin_name = "kong-authz-openfga"
local typedefs = require("kong.db.schema.typedefs")

local function validate_lua_expression(expression)
  local sandbox = require("kong.tools.sandbox")
  return sandbox.validate_safe(expression)
end

local lua_code = {
  type = "string",
  custom_validator = validate_lua_expression,
}

---@class TupleKey
---@field user string
---@field user_by_lua string
---@field relation string
---@field relation_by_lua string
---@field object string
---@field object_by_lua string
local tuple_key = {
  type = "record",
  required = true,
  fields = {
    { user = { type = "string" } },
    { user_by_lua = lua_code },
    { relation = { type = "string" } },
    { relation_by_lua = lua_code },
    { object = { type = "string" } },
    { object_by_lua = lua_code },
  },
  entity_checks = {
    { only_one_of = { "user", "user_by_lua" } },
    { at_least_one_of = { "user", "user_by_lua" } },
    { only_one_of = { "relation", "relation_by_lua" } },
    { at_least_one_of = { "relation", "relation_by_lua" } },
    { only_one_of = { "object", "object_by_lua" } },
    { at_least_one_of = { "object", "object_by_lua" } },
  },
}

---@class Config
---@field host string
---@field port number
---@field https boolean
---@field https_verify boolean
---@field timeout number
---@field keepalive number
---@field store_id string
---@field model_id string
---@field api_token string
---@field api_token_issuer string
---@field api_audience string
---@field api_client_id string
---@field api_client_secret string
---@field api_token_cache number
---@field tuple TupleKey
---@field contextual_tuples TupleKey[]
return {
  name = plugin_name,
  fields = {
    { consumer = typedefs.no_consumer },
    { protocols = typedefs.protocols },
    {
      config = {
        type = "record",
        fields = {
          { host = typedefs.host({ required = true }) },
          { port = typedefs.port({ description = "HTTP API port of OpenFGA", required = true, default = 8080 }) },
          { https = { required = true, type = "boolean", default = false } },
          { https_verify = { required = true, type = "boolean", default = false } },
          { timeout = { type = "number", default = 10000 } },
          { keepalive = { type = "number", default = 60000 } },
          { store_id = { required = true, type = "string" } },
          {
            model_id = {
              description = "Optional model id (version). Latest is used if this is empty",
              required = false,
              type = "string",
            },
          },
          {
            api_token = {
              description = "Optional API token",
              type = "string",
              referenceable = true,
              encrypted = true,
            },
          },
          { api_token_issuer = { type = "string" } },
          { api_audience = { type = "string" } },
          { api_client_id = { type = "string", referenceable = true, encrypted = true } },
          { api_client_secret = { type = "string", referenceable = true, encrypted = true } },
          { api_token_cache = { type = "number", default = 600 } },
          {
            tuple = tuple_key,
          },
          {
            contextual_tuples = {
              type = "set",
              elements = tuple_key,
              default = {},
            },
          },
        },
        entity_checks = {
          {
            mutually_required = {
              "api_token_issuer",
              "api_audience",
              "api_client_id",
              "api_client_secret",
            },
          },
        },
      },
    },
  },
}