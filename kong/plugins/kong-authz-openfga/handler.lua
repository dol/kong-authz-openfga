local plugin_name = "kong-authz-openfga"
local access = require("kong.plugins." .. plugin_name .. ".access")

local Plugin = {
  -- See https://docs.konghq.com/gateway/latest/plugin-development/custom-logic/#kong-plugins for ordering
  PRIORITY = 901,
  VERSION = "0.1.0",
}

function Plugin:access(conf)
  access.execute(conf, plugin_name)
end

return Plugin
