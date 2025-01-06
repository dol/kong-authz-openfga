local plugin_name = "kong-authz-openfga"
local package_name = "kong-plugin-" .. plugin_name
local package_namespace = "kong.plugins." .. plugin_name
local package_path = "kong/plugins/" .. plugin_name
local package_version = "dev"
local rockspec_revision = "0"

package = package_name
version = package_version .. "-" .. rockspec_revision

source = {
  url = "git+https://github.com/dol/kong-authz-openfga.git",
}

description = {
  summary = "Kong plugin for kong-authz-openfga integration",
  homepage = "https://github.com/dol/kong-authz-openfga",
  license = "MIT",
}

dependencies = {
  "lua ~> 5.1",
}

build = {
  type = "builtin",
  modules = {
    [package_namespace .. ".access"] = package_path .. "/access.lua",
    [package_namespace .. ".handler"] = package_path .. "/handler.lua",
    [package_namespace .. ".schema"] = package_path .. "/schema.lua",
  },
}
