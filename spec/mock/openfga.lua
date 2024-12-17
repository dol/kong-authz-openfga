local http_mock = require("spec.helpers.http_mock")

local _M = {}

--- Starts a local OpenFGA mock server that servers predefined response fixture
---@param port number The port the server will be listening on
---@return http_mock mock
function _M.server(port)
  local routes = {
    ["/stores/allowed/check"] = {
      access = [[
        ngx.req.set_header("Content-Type", "application/json")
        local response_body = "{\"allowed\":true,\"resolution\":\"\"}"
        ngx.print(response_body)
        ]],
    },
    ["/stores/denied/check"] = {
      access = [[
        ngx.req.set_header("Content-Type", "application/json")
        local response_body = "{\"allowed\":false,\"resolution\":\"\"}"
        ngx.print(response_body)
        ]],
    },
  }

  local mock = http_mock.new(port, routes, {
    prefix = "/kong-plugin/servroot_mock",
    log_opts = {
      req = true,
      req_body = true,
      req_large_body = true,
    },
  })

  return mock
end

return _M
