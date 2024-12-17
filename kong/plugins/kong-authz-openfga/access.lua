local kong = kong
local http = require("resty.http")
local cjson = require("cjson.safe")
local sandbox = require("kong.tools.sandbox").sandbox
local fmt = string.format

local _M = {}

local function tuple(conf)
  local sandbox_opts = { env = { kong = kong, ngx = ngx } }
  local tuple_key = {}

  if conf.user then
    tuple_key.user = conf.user
  else
    local user_by_lua = sandbox(conf.user_by_lua, sandbox_opts)()
    tuple_key.user = user_by_lua
  end

  if conf.relation then
    tuple_key.relation = conf.relation
  else
    local relation_by_lua = sandbox(conf.relation_by_lua, sandbox_opts)()
    tuple_key.relation = relation_by_lua
  end

  if conf.object then
    tuple_key.object = conf.object
  else
    local object_by_lua = sandbox(conf.object_by_lua, sandbox_opts)()
    tuple_key.object = object_by_lua
  end

  return tuple_key
end

--- Execute the OpenFGA check
---@param conf Config
function _M.execute(conf)
  local httpc = http.new()

  local tuple_key = tuple(conf.tuple)

  local fga_request = {
    tuple_key = tuple_key,
  }

  -- If contextual_tuples has at least one element, we add it to the request
  if #conf.contextual_tuples > 0 then
    fga_request.contextual_tuples = {
      tuple_keys = {},
    }
    for _, tuple_conf in ipairs(conf.contextual_tuples) do
      table.insert(fga_request.contextual_tuples.tuple_keys, tuple(tuple_conf))
    end
  end

  if conf.model_id then
    fga_request.authorization_model_id = conf.model_id
  end

  kong.log.debug("FGA request: ", cjson.encode(fga_request))

  local res, err = httpc:request_uri(fmt("http://%s:%d/stores/%s/check", conf.host, conf.port, conf.store_id), {
    method = "POST",
    body = cjson.encode(fga_request),
    headers = {
      ["Content-Type"] = "application/json",
    },
  })

  if not res then
    kong.log.err("FGA request failed: ", err)
    return kong.response.exit(500, "An unexpected error occurred")
  end

  local body, json_err = cjson.decode(res.body)

  if json_err then
    kong.log.err("Failed to decode FGA response body: ", json_err)
    return kong.response.exit(500, "An unexpected error occurred")
  end

  if res.status == 200 then
    if body.allowed == false then
      return kong.response.exit(403, "Forbidden")
    end
    kong.log.debug("Allowed by OpenFGA")
    return
  end

  -- In the not 200 case, we log the error and return a generic error message
  local err_message = "An unexpected error occurred"
  local log_message = "FGA request failed: "
  if body and body.message then
    log_message = log_message .. body.message
  end
  if body and body.code then
    log_message = log_message .. ", code: " .. body.code
  end

  kong.log.warn(log_message)
  return kong.response.error(500, err_message)
end

return _M
