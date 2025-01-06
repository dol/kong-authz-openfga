local kong = kong
local http = require("resty.http")
local cjson = require("cjson.safe")
local sandbox = require("kong.tools.sandbox").sandbox
local fmt = string.format

--- Constants
local RESPONSE_ERROR_MESSAGE = {
  ACCESS_DENIED = "Forbidden",
  INTERNAL_SERVER_ERROR = "An unexpected error occurred",
}

local _M = {}

--- Create a tuple key from the configuration
---@param conf TupleKey
---@return table
local function tuple(conf)
  local sandbox_opts = { env = { kong = kong, ngx = ngx } }
  local tuple_key = {}
  local fields = { "user", "relation", "object" }
  for _, field in ipairs(fields) do
    if conf[field] then
      tuple_key[field] = conf[field]
    else
      local field_by_lua = sandbox(conf[field .. "_by_lua"], sandbox_opts)()
      tuple_key[field] = field_by_lua
    end
  end

  return tuple_key
end

--- Trigger an unexpected error response and exit the plugin
--- @return nil
local function unexpected_error()
  return kong.response.exit(500, RESPONSE_ERROR_MESSAGE.INTERNAL_SERVER_ERROR)
end

local function make_fga_request(httpc, url, fga_request, conf)
  local response, response_err = httpc:request_uri(url, {
    method = "POST",
    body = cjson.encode(fga_request),
    headers = {
      ["Content-Type"] = "application/json",
    },
    ssl_verify = conf.https_verify, -- Verify the SSL certificate
    keepalive_timeout = conf.keepalive,
  })

  if not response then
    return false, "FGA request failed: " .. response_err
  end

  local body, json_err = cjson.decode(response.body)
  if json_err then
    return false, "Failed to decode FGA response body: " .. json_err
  end

  if response.status == 200 and body.allowed ~= nil and type(body.allowed) == "boolean" then
    return body.allowed, nil
  end

  local raise_err = "FGA request failed: "
  if body and body.message then
    raise_err = raise_err .. body.message
  end
  if body and body.code then
    raise_err = raise_err .. ", code: " .. body.code
  end
  return false, raise_err
end

--- Execute the OpenFGA check
---@param conf Config
function _M.execute(conf)
  local httpc, http_err = http.new()
  if not httpc then
    kong.log.err("Failed to create HTTP client: ", http_err)
    return unexpected_error()
  end

  httpc:set_timeout(conf.timeout)

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

  local protocol = conf.https and "https" or "http"

  local url = fmt("%s://%s:%d/stores/%s/check", protocol, conf.host, conf.port, conf.store_id)
  local attempts = 0
  local max_attempts = conf.max_attempts
  repeat
    attempts = attempts + 1

    local attempt_info = "attempt: " .. attempts .. "/" .. max_attempts

    -- Backoff timeout only after the first attempt was not successful
    if attempts > 1 then
      local backoff_timeout = (conf.failed_attempts_backoff_timeout * 2 ^ (attempts - 1)) / 1000
      kong.log.info("Querying OpenFGA. Backoff timeout: ", backoff_timeout, " seconds, ", attempt_info)
      ngx.sleep(backoff_timeout)
    else
      kong.log.info("Querying OpenFGA: ", attempt_info)
    end

    local allowed, raise_err = make_fga_request(httpc, url, fga_request, conf)

    if raise_err == nil then
      if allowed then
        -- Allowed by OpenFGA. Happy path
        return
      end
      return kong.response.exit(403, RESPONSE_ERROR_MESSAGE.ACCESS_DENIED)
    end

    -- Log the error and retry the request
    kong.log.err(raise_err, ", ", attempt_info)
  until attempts >= conf.max_attempts

  return unexpected_error()
end

return _M
