local ts = require("dap-go-ts")

local M = {
  last_testname = "",
  last_testpath = "",
  test_buildflags = "",
  test_verbose = false,
}

local default_config = {
  delve = {
    path = "dlv",
    initialize_timeout_sec = 20,
    port = "${port}",
    args = {},
    build_flags = "",
    -- Automatically handle the issue on delve Windows versions < 1.24.0
    -- where delve needs to be run in attched mode or it will fail (actually crashes).
    detached = vim.fn.has("win32") == 0,
    output_mode = "remote",
  },
  tests = {
    verbose = false,
  },
}

local internal_global_config = {}

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

local function get_build_flags(config)
  return coroutine.create(function(dap_run_co)
    local build_flags = config.build_flags
    vim.ui.input({ prompt = "Build Flags: " }, function(input)
      build_flags = vim.split(input or "", " ")
      coroutine.resume(dap_run_co, build_flags)
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
      cwd = config.delve.cwd,
    },
    options = {
      initialize_timeout_sec = config.delve.initialize_timeout_sec,
    },
  }

  dap.adapters.go = function(callback, client_config)
    if client_config.port == nil then
      callback(delve_config)
      return
    end

    local host = client_config.host
    if host == nil then
      host = "127.0.0.1"
    end

    local listener_addr = host .. ":" .. client_config.port
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
      outputMode = configs.delve.output_mode,
    },
    {
      type = "go",
      name = "Debug (Arguments)",
      request = "launch",
      program = "${file}",
      args = get_arguments,
      buildFlags = configs.delve.build_flags,
      outputMode = configs.delve.output_mode,
    },
    {
      type = "go",
      name = "Debug (Arguments & Build Flags)",
      request = "launch",
      program = "${file}",
      args = get_arguments,
      buildFlags = get_build_flags,
      outputMode = configs.delve.output_mode,
    },
    {
      type = "go",
      name = "Debug Package",
      request = "launch",
      program = "${fileDirname}",
      buildFlags = configs.delve.build_flags,
      outputMode = configs.delve.output_mode,
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
      outputMode = configs.delve.output_mode,
    },
    {
      type = "go",
      name = "Debug test (go.mod)",
      request = "launch",
      mode = "test",
      program = "./${relativeFileDirname}",
      buildFlags = configs.delve.build_flags,
      outputMode = configs.delve.output_mode,
    },
  }

  if dap.configurations.go == nil then
    dap.configurations.go = {}
  end

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
  internal_global_config = vim.tbl_deep_extend("force", default_config, opts or {})
  M.test_buildflags = internal_global_config.delve.build_flags
  M.test_verbose = internal_global_config.tests.verbose

  local dap = load_module("dap")
  setup_delve_adapter(dap, internal_global_config)
  setup_go_configuration(dap, internal_global_config)
end

local function debug_test(testname, testpath, build_flags, extra_args, custom_config)
  local dap = load_module("dap")

  local config = {
    type = "go",
    name = testname,
    request = "launch",
    mode = "test",
    program = testpath,
    args = { "-test.run", "^" .. testname .. "$" },
    buildFlags = build_flags,
    outputMode = "remote",
  }
  config = vim.tbl_deep_extend("force", config, custom_config or {})

  if not vim.tbl_isempty(extra_args) then
    table.move(extra_args, 1, #extra_args, #config.args + 1, config.args)
  end

  dap.run(config)
end

function M.debug_test(custom_config)
  local test = ts.closest_test()

  if test.name == "" or test.name == nil then
    vim.notify("no test found")
    return false
  end

  M.last_testname = test.name
  M.last_testpath = test.package

  local msg = string.format("starting debug session '%s : %s'...", test.package, test.name)
  vim.notify(msg)

  local extra_args = {}
  if M.test_verbose then
    extra_args = { "-test.v" }
  end

  debug_test(test.name, test.package, M.test_buildflags, extra_args, custom_config)

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

  local extra_args = {}
  if M.test_verbose then
    extra_args = { "-test.v" }
  end

  debug_test(testname, testpath, M.test_buildflags, extra_args)

  return true
end

function M.get_build_flags()
  return get_build_flags(internal_global_config)
end

function M.get_arguments()
  return get_arguments()
end

return M
