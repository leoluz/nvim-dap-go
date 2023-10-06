local M = {}

local tests_query = [[
(function_declaration
  name: (identifier) @testname
  parameters: (parameter_list
    . (parameter_declaration
      type: (pointer_type) @type) .)
  (#match? @type "*testing.(T|M)")
  (#match? @testname "^Test.+$")) @parent
]]

local subtests_query = [[
(call_expression
  function: (selector_expression
    operand: (identifier)
    field: (field_identifier) @run)
  arguments: (argument_list
    (interpreted_string_literal) @testname
    (func_literal))
  (#eq? @run "Run")) @parent
]]

local function format_subtest(testcase, test_tree)
  local parent
  if testcase.parent then
    for _, curr in pairs(test_tree) do
      if curr.name == testcase.parent then
        parent = curr
        break
      end
    end
    return string.format("%s/%s", format_subtest(parent, test_tree), testcase.name)
  else
    return testcase.name
  end
end

local function get_closest_above_cursor(test_tree)
  local result
  for _, curr in pairs(test_tree) do
    if not result then
      result = curr
    else
      local node_row1, _, _, _ = curr.node:range()
      local result_row1, _, _, _ = result.node:range()
      if node_row1 > result_row1 then
        result = curr
      end
    end
  end
  if result then
    return format_subtest(result, test_tree)
  end
  return nil
end

local function is_parent(dest, source)
  if not (dest and source) then
    return false
  end
  if dest == source then
    return false
  end

  local current = source
  while current ~= nil do
    if current == dest then
      return true
    end

    current = current:parent()
  end

  return false
end

local function get_closest_test()
  local stop_row = vim.api.nvim_win_get_cursor(0)[1]
  local ft = vim.api.nvim_buf_get_option(0, 'filetype')
  assert(ft == 'go', 'can only find test in go files, not ' .. ft)
  local parser = vim.treesitter.get_parser(0)
  local root = (parser:parse()[1]):root()

  local test_tree = {}

  local test_query = vim.treesitter.query.parse(ft, tests_query)
  assert(test_query, 'could not parse test query')
  for _, match, _ in test_query:iter_matches(root, 0, 0, stop_row) do
    local test_match = {}
    for id, node in pairs(match) do
      local capture = test_query.captures[id]
      if capture == "testname" then
        local name = vim.treesitter.get_node_text(node, 0)
        test_match.name = name
      end
      if capture == "parent" then
        test_match.node = node
      end
    end
    table.insert(test_tree, test_match)
  end

  local subtest_query = vim.treesitter.query.parse(ft, subtests_query)
  assert(subtest_query, 'could not parse test query')
  for _, match, _ in subtest_query:iter_matches(root, 0, 0, stop_row) do
    local test_match = {}
    for id, node in pairs(match) do
      local capture = subtest_query.captures[id]
      if capture == "testname" then
        local name = vim.treesitter.get_node_text(node, 0)
        test_match.name = string.gsub(string.gsub(name, ' ', '_'), '"', '')
      end
      if capture == "parent" then
        test_match.node = node
      end
    end
    table.insert(test_tree, test_match)
  end

  table.sort(test_tree, function(a, b)
    return is_parent(a.node, b.node)
  end)

  for _, parent in ipairs(test_tree) do
    for _, child in ipairs(test_tree) do
      if is_parent(parent.node, child.node) then
        child.parent = parent.name
      end
    end
  end

  return get_closest_above_cursor(test_tree)
end

local function get_package_name()
  local test_dir = vim.fn.fnamemodify(vim.fn.expand("%:.:h"), ":r");
  return "./" .. test_dir
end

M.closest_test = function()
  local package_name = get_package_name()
  local test_case = get_closest_test()
  local test_scope
  if test_case then
    test_scope = "testcase"
  else
    test_scope = "package"
  end
  return {
    package = package_name,
    name = test_case,
    scope = test_scope,
  }
end

M.get_root_dir = function()
  local id, client = next(vim.lsp.buf_get_clients())
  if id == nil then
    error({ error_msg = "lsp client not attached" })
  end
  if not client.config.root_dir then
    error({ error_msg = "lsp root_dir not defined" })
  end
  return client.config.root_dir
end

return M
