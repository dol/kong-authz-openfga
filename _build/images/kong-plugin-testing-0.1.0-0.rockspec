package = "kong-plugin-testing"
version = "0.1.0-0"

description = {
  summary = "Package to install all the testing dependencies",
}

source = {
  url = "",
}

dependencies = {
  "busted >= 2.2.0",
  "busted-hjtest = 0.0.5",
  "luacheck = 1.2.0",
  "luacov = 0.16.0",
  "lua-llthreads2 = 0.1.6",
  "http = 0.4",
}

build = {
  type = "builtin",
}
