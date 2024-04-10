local ts = require("dap-go-ts")

local M = {
  last_testname = "",
  last_testpath = "",
  test_buildflags = "",
}

local default_config = {
  delve = {
    path = "dlv",
    initialize_timeout_sec = 20,
    port = "${port}",
    args = {},
    build_flags = "",
    detached = true,
  },
}

local function load_module(module_name)
  local ok, module = pcall(require, module_name)
  assert(ok, string.format("dap-go dependency error: %s not installed", module_name))
  return module
end

local function get_arguments()
  return coroutine.create(function(dap_run_co)
    local args = {}
    vim.ui.input({ prompt = "Args: " }, function(input)
      args = vim.split(input or "", " ")
      coroutine.resume(dap_run_co, args)
    end)
  end)
end

local function filtered_pick_process()
  local opts = {}
  vim.ui.input(
    { prompt = "Search by process name (lua pattern), or hit enter to select from the process list: " },
    function(input)
      opts["filter"] = input or ""
    end
  )
  return require("dap.utils").pick_process(opts)
end

local function setup_delve_adapter(dap, config)
  local args = { "dap", "-l", "127.0.0.1:" .. config.delve.port }
  vim.list_extend(args, config.delve.args)

  local delve_config = {
    type = "server",
    port = config.delve.port,
    executable = {
      command = config.delve.path,
      args = args,
      detached = config.delve.detached,
    },
    options = {
      initialize_timeout_sec = config.delve.initialize_timeout_sec,
    },
  }

  dap.adapters.go = function(callback, client_config)
    if client_config.mode ~= "remote" then
      callback(delve_config)
      return
    end

    local listener_addr = client_config.host .. ":" .. client_config.port
    delve_config.port = client_config.port
    delve_config.executable.args = { "dap", "-l", listener_addr }

    callback(delve_config)
  end
end

local function setup_go_configuration(dap, configs)
  local common_debug_configs = {
    {
      type = "go",
      name = "Debug",
      request = "launch",
      program = "${file}",
      buildFlags = configs.delve.build_flags,
    },
    {
      type = "go",
      name = "Debug (Arguments)",
      request = "launch",
      program = "${file}",
      args = get_arguments,
      buildFlags = configs.delve.build_flags,
    },
    {
      type = "go",
      name = "Debug Package",
      request = "launch",
      program = "${fileDirname}",
      buildFlags = configs.delve.build_flags,
    },
    {
      type = "go",
      name = "Attach",
      mode = "local",
      request = "attach",
      processId = filtered_pick_process,
      buildFlags = configs.delve.build_flags,
    },
    {
      type = "go",
      name = "Debug test",
      request = "launch",
      mode = "test",
      program = "${file}",
      buildFlags = configs.delve.build_flags,
    },
    {
      type = "go",
      name = "Debug test (go.mod)",
      request = "launch",
      mode = "test",
      program = "./${relativeFileDirname}",
      buildFlags = configs.delve.build_flags,
    },
  }

  for _, config in ipairs(common_debug_configs) do
    table.insert(dap.configurations.go, config)
  end

  if configs == nil or configs.dap_configurations == nil then
    return
  end

  for _, config in ipairs(configs.dap_configurations) do
    if config.type == "go" then
      table.insert(dap.configurations.go, config)
    end
  end
end

function M.setup(opts)
  local config = vim.tbl_deep_extend("force", default_config, opts or {})
  M.test_buildflags = config.delve.build_flags
  local dap = load_module("dap")
  setup_delve_adapter(dap, config)
  setup_go_configuration(dap, config)
end

local function debug_test(testname, testpath, build_flags)
  local dap = load_module("dap")
  dap.run({
    type = "go",
    name = testname,
    request = "launch",
    mode = "test",
    program = testpath,
    args = { "-test.run", "^" .. testname .. "$" },
    buildFlags = build_flags,
  })
end

function M.debug_test()
  local test = ts.closest_test()

  if test.name == "" or test.name == nil then
    vim.notify("no test found")
    return false
  end

  M.last_testname = test.name
  M.last_testpath = test.package

  local msg = string.format("starting debug session '%s : %s'...", test.package, test.name)
  vim.notify(msg)
  debug_test(test.name, test.package, M.test_buildflags)

  return true
end

function M.debug_last_test()
  local testname = M.last_testname
  local testpath = M.last_testpath

  if testname == "" then
    vim.notify("no last run test found")
    return false
  end

  local msg = string.format("starting debug session '%s : %s'...", testpath, testname)
  vim.notify(msg)
  debug_test(testname, testpath, M.test_buildflags)

  return true
end

return M
