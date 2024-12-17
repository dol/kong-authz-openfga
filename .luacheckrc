std = "ngx_lua"
self = false

include_files = {
  "kong/plugins/**/*.lua",
  "spec/**/*.lua",
  "*.rockspec",
  ".busted",
  ".luacheckrc",
}

globals = {
  "_KONG",
  "kong",
  "Kong",
  "ngx.IS_CLI",
}

not_globals = {
  "string.len",
  "table.getn",
}

files["spec/**/*.lua"] = {
  std = "ngx_lua+busted",
}
