-- This software is copyright Kong Inc. and its licensors.
-- Use of the software is subject to the agreement between your organization
-- and Kong Inc. If there is no such agreement, use is governed by and
-- subject to the terms of the Kong Master Software License Agreement found
-- at https://konghq.com/enterprisesoftwarelicense/.
-- [ END OF LICENSE 0867164ffc95e54f04670b5169c09574bdbd9bba ]

local pl_path = require "pl.path"
local split = require("kong.tools.string").split
local pl_stringx = require ("pl.stringx")

local env_config = {
  debugger = os.getenv("KONG_EMMY_DEBUGGER"),
  host = os.getenv("KONG_EMMY_DEBUGGER_HOST"),
  port = os.getenv("KONG_EMMY_DEBUGGER_PORT"),
  wait = os.getenv("KONG_EMMY_DEBUGGER_WAIT"),
  source_path = os.getenv("KONG_EMMY_DEBUGGER_SOURCE_PATH"),
  source_path_mapping = os.getenv("KONG_EMMY_DEBUGGER_SOURCE_PATH_MAPPING"),
  multi_worker = os.getenv("KONG_EMMY_DEBUGGER_MULTI_WORKER"),
}

local source_path
local source_path_mapping
local env_prefix

local function find_source_mapping(path)
  for source, mapping in pairs(source_path_mapping) do
    if pl_stringx.startswith(path, source) then
      return pl_stringx.replace(path, source, mapping, 1)
    end
  end
  return path
end

local function find_source(path)
  if pl_path.exists(path) then
    return find_source_mapping(path)
  end

  local bytecode_path = path:gsub("%.lua$", ".ljbc")
  if pl_path.exists(bytecode_path) then
    return bytecode_path
  end

  if path:match("^=") then
    -- code is executing from .conf file, don't attempt to map
    return path
  end

  if path:match("^jsonschema:") then
    -- code is executing from jsonschema, don't attempt to map
    return path
  end

  for _, p in ipairs(source_path) do
    local full_path = pl_path.join(p, path)
    local full_bytecode_path = pl_path.join(p, bytecode_path)
    if pl_path.exists(full_path) then
      return find_source_mapping(full_path)
    end

    if pl_path.exists(full_bytecode_path) then
      return full_bytecode_path
    end
  end

  ngx.log(ngx.ERR, "source file ", path, " not found in ", env_prefix, "_EMMY_DEBUGGER_SOURCE_PATH")

  return path
end

local function load_debugger(path)
  _G.emmy = {
    fixPath = find_source
  }

  local ext = pl_path.extension(path)
  local name = pl_path.basename(path):sub(1, -#ext - 1)

  local save_cpath = package.cpath
  package.cpath = pl_path.dirname(path) .. '/?' .. ext
  local dbg = require(name)
  package.cpath = save_cpath
  return dbg
end

local function parse_mapping(mapping_str)
  local mappings = {}
  local pairs = split(mapping_str, ":")
  for _, pair in ipairs(pairs) do
    local mapping = split(pair, ";", 2)
    if #mapping == 2 then
      mappings[mapping[1]] = mapping[2]
    end
  end
  return mappings
end

local function init(config_)
  local config = config_ or {}
  local debugger = config.debugger or env_config.debugger
  local host = config.host or env_config.host or "localhost"
  local port = config.port or env_config.port or 9966
  local wait = config.wait or env_config.wait
  local multi_worker = env_config.multi_worker or env_config.multi_worker

  env_prefix = config.env_prefix or "KONG"
  source_path = split(config.source_path or env_config.source_path or "", ":")
  source_path_mapping = parse_mapping(config.source_path_mapping or env_config.source_path_mapping or "")

  if not debugger then
    return
  end

  if not pl_path.isabs(debugger) then
    ngx.log(ngx.ERR, env_prefix, "_EMMY_DEBUGGER (", debugger, ") must be an absolute path")
    return
  end
  if not pl_path.exists(debugger) then
    ngx.log(ngx.ERR, env_prefix, "_EMMY_DEBUGGER (", debugger, ") file not found")
    return
  end
  local ext = pl_path.extension(debugger)
  if ext ~= ".so" and ext ~= ".dylib" then
    ngx.log(ngx.ERR, env_prefix, "_EMMY_DEBUGGER (", debugger, ") must be a .so (Linux) or .dylib (macOS) file")
    return
  end
  if ngx.worker.id() > 0 and not multi_worker then
    ngx.log(ngx.ERR, env_prefix, "_EMMY_DEBUGGER is only supported in the first worker process, suggest setting KONG_NGINX_WORKER_PROCESSES to 1")
    return
  end

  ngx.log(ngx.NOTICE, "loading EmmyLua debugger ", debugger)
  ngx.log(ngx.WARN, "The EmmyLua integration for Kong is a feature solely for your convenience during development. Kong assumes no liability as a result of using the integration and does not endorse it’s usage. Issues related to usage of EmmyLua integration should be directed to the respective project instead.")

  local dbg = load_debugger(debugger)
  dbg.tcpListen(host, port + (ngx.worker.id() or 0))

  ngx.log(ngx.NOTICE, "EmmyLua debugger loaded, listening on port ", port)

  if wait then
    -- Wait for IDE connection
    ngx.log(ngx.NOTICE, "waiting for IDE to connect")
    dbg.waitIDE()
    ngx.log(ngx.NOTICE, "IDE connected")
  end
end

return {
  init = init,
  load_debugger = load_debugger
}
