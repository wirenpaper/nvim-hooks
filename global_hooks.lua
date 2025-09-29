package.path = package.path .. ";/home/saifr/.config/nvim/plugin/hooks/?.lua"
local hooks = require("hooks")
local utils = require("utilities")
local M = {}

gterm_dict = {}
gbufname = {}
gmeta_names = {}

local function key_map(n)
  if n == 1 then
    return "u"
  elseif n == 2 then
    return "i"
  elseif n == 3 then
    return "o"
  elseif n == 4 then
    return "p"
  end
end

local function file_exists(path)
  if path ~= nil then
    local f = io.open(path, "r")
    if f ~= nil then
      io.close(f)
      return true
    else
      return false
    end
  end
end

local function clean_spaces(str)
  local str = string.gsub(str, " [^%S\n]+", " ")
  if str:sub(1, 1) == " " then
    return str:sub(2)
  else
    return str
  end
  return str
end

local function format_path(str)
  if str == nil then
    return nil
  end
  str = clean_spaces(str)
  local i, j = string.find(str, " ")
  if i then
    return string.sub(str, 1, i - 1), string.sub(str, j + 1)
  else
    return str
  end
end

local function remove_slash(s)
  -- Check if the last character is a "/"
  if string.sub(s, -1) == "/" then
    -- Remove the last character
    s = string.sub(s, 1, -2)
  end
  -- Return the modified string
  return s
end

local function get_end_path_name(s)
  -- If 's' is not a string or is nil, return an empty string immediately.
  if type(s) ~= "string" then
    return ""
  end

  local t = "" -- It's good practice to initialize with a default value.
  for str in string.gmatch(s, "([^/]+)") do
    t = str
  end
  return t
end

local function get_after_space(str)
  local i = string.find(str, " ") -- find the first space
  if i then -- if there is a space
    return string.sub(str, i + 1) -- return the substring after the space
  else -- if there is no space
    return "" -- return an empty string
  end
end

jmp_path = path
local function get_buffer_path()
  local path = vim.api.nvim_buf_get_name(0)
  if vim.fn.isdirectory(path) ~= 0 then
    return path
  elseif file_exists(path) then
    return vim.fn.fnamemodify(path, ":h")
  else
    return vim.loop.cwd()
  end
end

local path = get_buffer_path()

local function path_exists(path)
  local stat = vim.loop.fs_stat(path)
  return stat ~= nil
end

workspace = path .. "/.hook_files"

ws = nil
ghooks = nil
--MARK:hooks
if path_exists(path .. "/.hook_files") then
  ghooks = path .. "/.hook_files/__global__" 
end

vim.o.showtabline = 2
local function fname_aux()
  local file = gbufname[vim.api.nvim_get_current_buf()]
  if file == nil then
    if vim.api.nvim_buf_get_name(0) == ghooks then
      file = { vim.api.nvim_buf_get_name(0), "hooks" }
    else
      file = { vim.api.nvim_buf_get_name(0), "file" }
    end
  end
  return file
end

local function fname_aux_set(file)
  if vim.fn.isdirectory(file) ~= 0 then
    file = { file, "term" }
  elseif file == ghooks then
    file = { file, "hooks" }
    print("file: " .. file)
  else
    file = { file, "file" }
  end
  return file
end

local function has_multiple_slashes_in_row(s)
  local i = 1
  for c in s:gmatch(".") do
    if i ~= #s and string.sub(s, i, i) == "/" and string.sub(s, i + 1, i + 1) == "/" then
      return true
    end
    i = i + 1
  end
  return false
end

local file_args = ""
local function fname_cleaned()
  if fname_aux()[2] == "file" then
    if file_args == "" then
      return vim.api.nvim_buf_get_name(0)
    else
      return vim.api.nvim_buf_get_name(0)
    end
  elseif fname_aux()[2] == "hooks" then
    return vim.api.nvim_buf_get_name(0) .. "⇁ "
  else
    local path = format_path(fname_aux()[1])

    local first = get_end_path_name(path)
    if string.sub(path, -1) == "/" then
      first = first .. "/"
    end
    local last = get_after_space(fname_aux()[1])
    if last == "" then
      local opts = lines_from(ghooks)
      statusline_protocol(opts)
      return vim.fn.getcwd()
    else
      local opts = lines_from(ghooks)
      statusline_protocol(opts)
      return vim.fn.getcwd()
    end
  end
end

local function fname_set_cleaned(file)
  local path, args = format_path(file)
  if fname_aux_set(path)[2] == "file" then
    if args == nil then
      return " " .. get_end_path_name(path) .. "@ "
    else
      return " " .. get_end_path_name(path) .. "@" .. " -- " .. args .. " "
    end
  else
    if args == nil then
      return " [ " .. get_end_path_name(path) .. " ] "
    else
      return " [ " .. get_end_path_name(path) .. " ]" .. " -- " .. args .. " "
    end
  end
end

local function fname()
  return fname_aux()[1]
end

local mod_flag = false

cmode = "dark"

vim.api.nvim_create_autocmd({ "VimEnter", "ColorScheme" }, {
  pattern = "*",
  callback = function()
    cmode = "dark"
    color = vim.g.colors_name
    if color == "quiet" then
      cmode = "light"
    end
    if color == "darkness" then
      cmode = "dark"
    end
    --statusline_protocol(gropts)
  end,
})

gropts = ""

---Polls for a value and executes a callback when it's available.
---@param producer_func function: A function that returns the value you're waiting for. Should return nil if not ready.
---@param on_success_callback function: The function to run with the value once it's no longer nil.
local function poll_for_value(producer_func, on_success_callback)
  local timer = vim.loop.new_timer()
  local attempts = 0
  local max_attempts = 40 -- Give up after 2 seconds (40 * 50ms)
  local is_closing = false -- <<< The new guard flag

  timer:start(
    0,
    50,
    vim.schedule_wrap(function()
      -- If we're already closing, do nothing. This prevents the "already closing" error.
      if is_closing then
        return
      end

      local value = producer_func()
      if value ~= nil then
        is_closing = true -- <<< Set the flag first
        timer:close()
        on_success_callback(value)
      else
        attempts = attempts + 1
        if attempts > max_attempts then
          is_closing = true -- <<< Set the flag first
          timer:close()
          -- vim.notify("Error: Timed out waiting for gfile_line_number.", vim.log.levels.ERROR)
        end
      end
    end)
  )
end

local function statusline_protocol2(opts)
  gropts = opts

  if not string.match(get_end_path_name(ghooks), "__workspaces__") then
    ws = get_end_path_name(ghooks)
  end

  local function build_and_execute_tmux_command(n)
    local tmux_string = ""
    local km = key_map(n)

    if type(opts) == "table" then
      for i, v in ipairs(opts) do
        if i > 8 then
          break
        end
        if v ~= "" and key_map(n) ~= key_map(i) then
          if not string.match(get_end_path_name(ghooks), "__workspaces__") then
	    tmux_string = tmux_string .. '%#TabKeyStyled#' .. key_map(i) .. '%*' .. fname_set_cleaned(v)
          else
            local s = get_end_path_name(v)
            s = string.sub(s, 2, -2)
            if s == ws then
	    tmux_string = tmux_string .. '%#TabKeyStyled#' .. key_map(i) .. '%*' ..'%#TabKeySelected#'.. fname_set_cleaned(v)..'%*'
            else
	    tmux_string = tmux_string .. '%#TabKeyStyled#' .. key_map(i) .. '%*' .. fname_set_cleaned(v)
            end
          end
        elseif v ~= "" and key_map(n) == key_map(i) then
	    tmux_string = tmux_string .. '%#TabKeyStyled#' .. key_map(i) .. '%*' ..'%#TabKeySelected#'.. fname_set_cleaned(v)..'%*'
        end
      end
    end
    vim.o.statusline = tmux_string
  end

  -- This block now determines HOW to get the line number 'n', and then passes
  -- it to the function above for processing.
  if file_exists(fname()) == false or gterm_dict[fname()] ~= nil then
    -- ASYNC CASE: The value is not ready yet.
    -- We poll for the value, and once we have it, we run our logic.
    poll_for_value(
      function()
        return gfile_line_number[fname()]
      end,
      build_and_execute_tmux_command -- The function to run on success
    )
  else
    -- SYNC CASE: The value is ready immediately.
    -- We get it directly and run our logic right away.
    local n = gfile_line_number[gmeta_names[fname()]]
    build_and_execute_tmux_command(n)
  end
end

local function statusline_protocol(opts)
  gropts = opts

  if not string.match(get_end_path_name(ghooks), "__workspaces__") then
    ws = get_end_path_name(ghooks)
  end

  local tmux_string = ""
  local km = key_map(n)
  local n = 0

  if file_exists(fname()) == false or gterm_dict[fname()] ~= nil then
    n = gfile_line_number[fname()]
  else
    n = gfile_line_number[gmeta_names[fname()]]
  end

  if type(opts) == "table" then
    for i, v in ipairs(opts) do
      if i > 8 then
        break
      end
      if v ~= "" and key_map(n) ~= key_map(i) then
        if not string.match(get_end_path_name(ghooks), "__workspaces__") then
	  tmux_string = tmux_string .. '%#TabKeyStyled#' .. key_map(i) .. '%*' .. fname_set_cleaned(v)
        else
          local s = get_end_path_name(v)
          s = string.sub(s, 2, -2)
          if s == ws then
	    tmux_string = tmux_string .. '%#TabKeyStyled#' .. key_map(i) .. '%*' ..'%#TabKeySelected#'.. fname_set_cleaned(v)..'%*'
          else
	    tmux_string = tmux_string .. '%#TabKeyStyled#' .. key_map(i) .. '%*' .. fname_set_cleaned(v)
          end
        end
      elseif v ~= "" and key_map(n) == key_map(i) then
	   tmux_string = tmux_string .. '%#TabKeyStyled#' .. key_map(i) .. '%*' ..'%#TabKeySelected#'.. fname_set_cleaned(v)..'%*'
      end
    end
  end
  vim.o.statusline = tmux_string
end

local function pfname_aux()
  file = nil
  local mbufname = gbufname[vim.api.nvim_get_current_buf()]
  if mbufname ~= nil then
    local name = mbufname[1]
    if name ~= nil then
      file = format_path(name)
    else
      file = nil
    end
  end
  if file ~= nil then
    return file
  else
    file = vim.api.nvim_buf_get_name(0)
    return file
  end
end

local function pfname()
  if fname_aux()[2] == "term" then
    local str = fname_aux()[1]
    if string.sub(str, -1) ~= "/" then
      print(pfname_aux() .. "/")
    else
      print(pfname_aux())
    end
  else
    print(pfname_aux())
  end
end

local buffer_path = vim.api.nvim_buf_get_name(0)
current_buffer = buffer_path
local buffers = {}

local function is_modified()
  local modified_buffers = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].modified then
      table.insert(modified_buffers, buf)
    end
  end

  if #modified_buffers > 0 then
    return true
  else
    return false
  end
end

-- funcs continued
local hooks_fired = false
local should_kill_terminals = true
local function rehook_helper(path, skip_terminal_kill)

  local opts = lines_from(ghooks)
  statusline_protocol(opts)

  if not file_exists(ghooks) then
    print("hooks doesn't exist")
  else
    vim.cmd([[autocmd InsertEnter ]] .. ghooks .. [[ call PlaceSigns(-1,-1)]])
    hooks_fired = true
    should_kill_terminals = not skip_terminal_kill
  end
end

local function rehook(path, skip_terminal_kill)
  if is_modified() == false then
    rehook_helper(path, skip_terminal_kill)
  else
    print("save modified buffers")
  end
end

local function rehook_force()
  rehook_helper(nil, false)
end

ERROR_LINE = 0
kill_flag = false

local function is_file(path)
  local stat = vim.loop.fs_stat(path)
  return stat and stat.type == "file"
end

gfile_line_number = {}
local gdups = {}
local function lines_from(file)
  gdups = {}
  gfile_line_number = {}
  if not file_exists(file) then
    return {}
  end
  local lines = {}
  if vim.fn.filereadable(file) == 0 then
    return 0
  end
  for line in io.lines(file) do
    local tmp_line = ""
    if is_file(format_path(line)) then
      tmp_line = format_path(line)
    end
    if tmp_line == "" then
      if gdups[line] ~= nil and gdups[line] ~= "" then
        print("DUPLICATE hooks:" .. #lines + 1)
        ERROR_LINE = #lines + 1
        kill_flag = true
        return
      else
        gdups[line] = line
      end
    else
      if gdups[tmp_line] ~= nil and gdups[tmp_line] ~= "" then
        print("DUPLICATE hooks:" .. #lines + 1)
        ERROR_LINE = #lines + 1
        kill_flag = true
        return
      else
        gdups[tmp_line] = tmp_line
        gmeta_names[format_path(line)] = line
      end
    end
    lines[#lines + 1] = line
    gfile_line_number[line] = #lines
  end
  return lines
end

-- #TODO vimscript -> lua
vim.cmd([[
function! PlaceSigns(n,m)
    " First clear all signs
    execute 'sign unplace * buffer=' . bufnr('%')

    let signs = ['j', 'k', 'l', ';', 'm', ',', '.', '/']
    let current_buffer = bufnr('%')
    let line_count = line('$')  " Get the number of lines in the current buffer

    if a:n != -1 && a:n == a:m
        let signs[a:n] = 'X*'
    else
        if a:m != -1
            let signs[a:m] = 'XX'
        endif

        if a:n != -1
            let signs[a:n] = signs[a:n].'*'
        endif
    endif

    let i = 1
    for sign in signs
        if i <= line_count
            execute 'sign define sign' . i . ' text=' . sign . ' texthl=Search'
            execute 'sign place ' . i . ' line=' . i . ' name=sign' . i . ' buffer=' . current_buffer
            let i += 1
        endif
    endfor
endfunction
]])

local function signs(n, m)
  if n == nil then
    n = 0
  end
  if m == nil then
    m = 0
  end

  if ghooks then
    vim.cmd(
      [[autocmd CursorMovedI,BufWritePost,BufWinEnter,TextChanged,TextChangedI,TextChangedP,InsertLeave ]]
        .. ghooks
        .. [[ call PlaceSigns(]]
        .. n - 1
        .. [[, ]]
        .. m - 1
        .. [[)]]
    )
  end
end

local function setup_hook_files()
  -- Create the .hook_files directory
  local success = os.execute("mkdir -p " .. workspace)

  if not success then
    print("Failed to create directory: " .. workspace)
    return
  end

  -- Create and write to __f__ file
  local f_file = io.open(workspace .. "/__f__", "w")
  if f_file then
    f_file:write("__hooks__")
    f_file:close()
  else
    print("Failed to create __f__ file")
    return
  end

  -- Create empty __hooks__ file
  local hooks_file = io.open(workspace .. "/__hooks__", "w")
  if hooks_file then
    hooks_file:close()
  else
    print("Failed to create __hooks__ file")
    return
  end
end

n_shad = gfile_line_number[vim.api.nvim_buf_get_name(0)]
local function hook_file()
  vim.cmd("silent on")
  local path, args = format_path(current_buffer)

  if not path_exists(workspace) then
    setup_hook_files()
  end

  if vim.fn.isdirectory(path) == 0 then
    local n = gfile_line_number[vim.api.nvim_buf_get_name(0)]
    if n ~= nil then
      if ERROR_LINE ~= 0 then
        signs(n_shad, ERROR_LINE)
      else
        signs(n, ERROR_LINE)
        n_shad = n
      end
    else
      signs(n_shad, ERROR_LINE)
    end
  end

  vim.cmd("e " .. ghooks)
  gbufname[vim.api.nvim_get_current_buf()] = { ghooks, "hooks" }
  ERROR_LINE = 0
end

local function hook_term()
  vim.cmd("on")
  hook_file()
  vim.cmd("sp")
  vim.cmd("wincmd j")
  vim.cmd("te")
end

local function write_hooks(n, tpath)
  local lines = {}
  local file = io.open(ghooks, "r")
  for line in file:lines() do
    table.insert(lines, line)
  end
  file:close()

  lines[n] = tpath
  file = io.open(ghooks, "w")
  for _, line in ipairs(lines) do
    file:write(line, "\n")
  end
  file:close()
end

local function term_retag(params)
  local n = gfile_line_number[current_buffer]
  local tag = params.args
  if file_exists(fname()) == false or gterm_dict[fname()] ~= nil then
    if tag == "" then
      if path ~= fname() then
        if gdups[path] ~= nil then
          print("RETAG DENIED -- DUPLICATE")
          return
        end
        buffers[path] = vim.api.nvim_get_current_buf()
        gbufname[vim.api.nvim_get_current_buf()] = { path, "term" }
        gterm_dict[path] = path
        gterm_bufnum[path] = vim.api.nvim_get_current_buf()
        write_hooks(n, path)
      elseif path == fname() then
        print("RETAG DENIED -- BUFFER ALREADY NAMED AS SUCH")
      end
    else
      if path .. " " .. tag ~= fname() then
        if gdups[path .. " " .. tag] ~= nil then
          print("RETAG DENIED -- DUPLICATE")
          return
        end
        buffers[path .. " " .. tag] = vim.api.nvim_get_current_buf()
        gbufname[vim.api.nvim_get_current_buf()] = { path .. " " .. tag, "term" }
        gterm_dict[path .. " " .. tag] = path
        gterm_bufnum[path .. " " .. tag] = vim.api.nvim_get_current_buf()
        write_hooks(n, path .. " " .. tag)
      elseif path .. " " .. tag == fname() then
        print("RETAG DENIED -- BUFFER ALREADY NAMED AS SUCH")
      end
    end
  else
    print("ERROR: NOT A TERMINAL BUFFER")
  end
end
vim.api.nvim_create_user_command("TermRetag", function(params)
  term_retag(params)
end, { nargs = "*" })

gterm_bufnum = {}
local function set_dir_mode2(path, args)
  vim.cmd("te cd " .. path .. " && $SHELL")
  buffers[path .. " " .. args] = vim.api.nvim_get_current_buf()
  gbufname[vim.api.nvim_get_current_buf()] = { path .. " " .. args, "term" }
  gterm_dict[fname()] = path
  gterm_bufnum[fname()] = vim.api.nvim_get_current_buf()
  vim.api.nvim_set_current_dir(path)
end

local function set_dir_mode1(path)
  vim.cmd("te cd " .. path .. " && $SHELL")
  buffers[path] = vim.api.nvim_get_current_buf()
  gbufname[vim.api.nvim_get_current_buf()] = { path, "term" }
  gterm_dict[fname()] = path
  gterm_bufnum[fname()] = vim.api.nvim_get_current_buf()
  vim.api.nvim_set_current_dir(path)
end

local function hook_mode2(n, args)
  current_buffer = path .. " " .. args
  if vim.fn.isdirectory(path) ~= 0 then
    if is_modified() then
      --print("TERMINAL BUFFER: UNSAVED MODIFIED BUFFER(S)")
    end
    if buffers[current_buffer] == nil then
      set_dir_mode2(path, args)
    else
      local buf_loaded = vim.api.nvim_buf_is_loaded(buffers[path .. " " .. args])
      if buf_loaded == true then
        vim.api.nvim_set_current_buf(buffers[path .. " " .. args])
      else
        set_dir_mode2(path, args)
      end
    end
  elseif file_exists(path) then
    file_args = args
    if buffers[path] == nil then
      vim.cmd("e " .. path)
      buffers[path] = vim.api.nvim_get_current_buf()
      gbufname[vim.api.nvim_get_current_buf()] = { path, "file" }
    else
      vim.api.nvim_set_current_buf(buffers[path])
    end
  else
    print("MALFORMED hooks:" .. n)
    ERROR_LINE = n
  end
end

local function hook_mode1(n)
  file_args = ""
  current_buffer = path
  if vim.fn.isdirectory(path) ~= 0 then
    if is_modified() then
      --print("TERMINAL BUFFER: UNSAVED MODIFIED BUFFER(S)")
    end
    if buffers[path] == nil then
      set_dir_mode1(path)
    else
      local buf_loaded = vim.api.nvim_buf_is_loaded(buffers[path])
      if buf_loaded == true then
        vim.api.nvim_set_current_buf(buffers[path])
      else
        set_dir_mode1(path)
      end
    end
  elseif file_exists(path) then
    if path == ghooks then
      print("cannot reference current hookfile")
      ERROR_LINE = n
      return
    end

    if buffers[path] == nil then
      vim.cmd("e " .. path)
      buffers[path] = vim.api.nvim_get_current_buf()
      gbufname[vim.api.nvim_get_current_buf()] = { path, "file" }
    else
      vim.api.nvim_set_current_buf(buffers[path])
    end
  else
    print("MALFORMED hooks:" .. n)
    ERROR_LINE = n
  end
end

vim.cmd([[autocmd InsertEnter ghooks call PlaceSigns(-1,-1)]])

global_n = nil

local function hook(n)
  hooks.set_false_bookmarks_flag()
  hooks.normal()

  if bookmarks_flag == true then
    local cmd_str = string.format("GotoMark %s", marks[n])
    vim.cmd(cmd_str)
    return
  end

  if vim.fn.filereadable(ghooks) == 0 then
    print("hooks file doesn't exist or isn't readble")
    return
  end
  ERROR_LINE = 0
  vim.cmd("silent on")
  if file_exists(ghooks) == false then
    print("HOOKS NOT FOUND")
    return
  end
  local opts = lines_from(ghooks)

  if kill_flag == true then
    kill_flag = false
    return
  end

  if opts[n] == nil then
    print("UNSET hooks:" .. n)
    return
  end

  path, args = format_path(opts[n])

  -- Check if path is surrounded by asterisks (workspace mode)
  if string.sub(path, 1, 1) == "*" and string.sub(path, -1) == "*" then
    -- Extract workspace name (remove asterisks)
    local workspace_name = string.sub(path, 2, -2)
    -- Switch to workspace using the same function telescope calls
    hookfiles(workspace_name)
    return
  end

  if string.sub(path, -1) == "/" then
    print("CANNOT END PATH WITH '/'  " .. n)
    ERROR_LINE = n
    signs(n_shad, ERROR_LINE)
    return
  end

  if has_multiple_slashes_in_row(path) then
    print("REPEAT SLASHES NOT ALLOWED " .. n)
    ERROR_LINE = n
    signs(n_shad, ERROR_LINE)
    return
  end

  if path == "" then
    print("UNSET hooks:" .. n)
    return
  end
  if args == nil then
    hook_mode1(n)
  else
    hook_mode2(n, args)
  end
  if ERROR_LINE ~= 0 then
    signs(n_shad, ERROR_LINE)
  else
    signs(n, ERROR_LINE)
    n_shad = n
  end
end

local function copy_filename()
  file = nil
  local mbufname = bufname[vim.api.nvim_get_current_buf()]
  if mbufname ~= nil then
    local name = mbufname[1]
    if name ~= nil then
      file = format_path(name)
    else
      file = nil
    end
  end
  if file ~= nil then
    print("COPIED TO CLIPBOARD: " .. file)
  else
    file = vim.api.nvim_buf_get_name(0)
    print("COPIED TO CLIPBOARD: " .. file)
  end
  vim.api.nvim_call_function("setreg", { "+", file })
end

local function term_buffer_directory_onchange()
  gterm_dict[fname()] = vim.fn.getcwd()
end

local function on_buffer_enter2()
  if file_exists(fname()) == false or gterm_dict[fname()] ~= nil then
    if is_modified() then
      mod_flag = true
    end
  else
    mod_flag = false
  end

  local opts = lines_from(ghooks)
  statusline_protocol2(opts)

  if gterm_dict[fname()] ~= nil then
    local path, _ = format_path(gterm_dict[fname()])
    vim.api.nvim_set_current_dir(path)
  end

  if hooks_fired == true then
    if should_kill_terminals then
      for key, value in pairs(gterm_bufnum) do
        vim.cmd([[bd! ]] .. value)
      end
      gterm_bufnum = {}
    end
    hooks_fired = false
  end
end

local function on_buffer_enter()
  if file_exists(fname()) == false or gterm_dict[fname()] ~= nil then
    if is_modified() then
      mod_flag = true
    end
  else
    mod_flag = false
  end

  local opts = lines_from(ghooks)
  statusline_protocol(opts)

  if gterm_dict[fname()] ~= nil then
    local path, _ = format_path(gterm_dict[fname()])
    vim.api.nvim_set_current_dir(path)
  end

  if hooks_fired == true then
    if should_kill_terminals then
      for key, value in pairs(gterm_bufnum) do
        vim.cmd([[bd! ]] .. value)
      end
      gterm_bufnum = {}
    end
    hooks_fired = false
  end
end

local function on_buf_save()
  if is_modified() == true then
    mod_flag = true
  else
    mod_flag = false
  end
end

local function register_autocommands()
  vim.api.nvim_create_autocmd("BufEnter", { pattern = "*", callback = on_buffer_enter })
  vim.api.nvim_create_autocmd("TermOpen", { pattern = "*", callback = on_buffer_enter2 })
  --vim.api.nvim_create_autocmd("VimLeave", { callback = on_neovim_exit })
  vim.api.nvim_create_autocmd("BufWritePost", { callback = on_buf_save })
end

-- MARK:bindings
-- key bindings
vim.keymap.set("n", ",au", function()
  hook(1)
end)
vim.keymap.set("n", ",ai", function()
  hook(2)
end)
vim.keymap.set("n", ",ao", function()
  hook(3)
end)
vim.keymap.set("n", ",ap", function()
  hook(4)
end)

local function set_false_bookmarks_flag()
  bookmarks_flag = false
end

local function search_current_line()
  --Yank the current line
  vim.api.nvim_command("normal! yy")

  --Get the yanked line from the unnamed register
  local line = vim.fn.getreg("0")

  --Escape special characters
  line = line:gsub("([\\^$.*\\[\\]])", "\\%1")

  --Perform the search
  vim.api.nvim_command("let @/ = '" .. line .. "'")
end

-- Map the function to a key, for example <leader>l
vim.api.nvim_set_keymap("n", "<leader>l", ":lua search_current_line()<CR>", { noremap = true, silent = true })

-- Creates the :GotoMark command to jump directly to a named MARK
vim.api.nvim_create_user_command(
  'GotoMark',
  function(opts)
    local query = opts.args
    if not query or query == "" then
      vim.notify("Usage: :GotoMark <mark_name>", vim.log.levels.WARN)
      return
    end
    
    -- Search for the pattern
    local search_pattern = "MARK:" .. query
    
    -- Save current cursor position
    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    
    -- Try to find the mark from the beginning of the file
    vim.api.nvim_win_set_cursor(0, {1, 0})
    
    -- Use vim's search function
    local found = vim.fn.search(vim.fn.escape(search_pattern, '/\\'), 'W')
    
    if found > 0 then
      vim.notify("Jumped to MARK: " .. query, vim.log.levels.INFO)
    else
      -- Restore cursor position if not found
      vim.api.nvim_win_set_cursor(0, cursor_pos)
      vim.notify("MARK not found: '" .. query .. "'", vim.log.levels.ERROR)
    end
  end,
  {
    nargs = 1, -- Requires exactly one argument
  }
)

-- commands
vim.api.nvim_create_user_command("ReHook", function()
  rehook()
end, {})
vim.api.nvim_create_user_command("ReHookForce", function()
  rehook_force()
end, {})
vim.api.nvim_create_user_command("TBdc", function()
  term_buffer_directory_onchange()
end, {})
vim.api.nvim_create_user_command("Warn", function()
  tmux_warning()
end, {})

local function kill_flag_set(bool_val)
  kill_flag = bool_val
end

register_autocommands()
signs(0, 0)
kill_flag_set(false)

M = {
  set_false_bookmarks_flag = set_false_bookmarks_flag,
  rehook = rehook,
  path = path,
  on_buffer_enter = on_buffer_enter,
  fname_cleaned = fname_cleaned,
  fname_set_cleaned = fname_set_cleaned,
  lines_from = lines_from,
  signs = signs,
  ERROR_LINE = ERROR_LINE,
  kill_flag_set = kill_flag_set,
  key_map = key_map,
  register_autocommands = register_autocommands,
}

return M
