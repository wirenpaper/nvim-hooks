local M = {}

term_dict = {}
bufname = {}

function key_map(n)
	if n == 1 then
		return "j"
	elseif n == 2 then
		return "k"
	elseif n == 3 then
		return "l"
	elseif n == 4 then
		return ";"
	elseif n == 5 then
		return "m"
	elseif n == 6 then
		return ","
	elseif n == 7 then
		return "."
	elseif n == 8 then
		return "/"
	end
end

function file_exists(path)
	if path ~= nil then
		local f=io.open(path,"r")
		if f~=nil then io.close(f) return true else return false end
	end
end

local function clean_spaces(str)
	local str = string.gsub(str, " [^%S\n]+", " ")
	if str:sub(1, 1) == " " then return str:sub(2) else return str end
	return str
end

local function format_path(str)
	if str == nil then return nil end
	str = clean_spaces(str)
	local i, j = string.find(str, " ")
	if i then
		return string.sub(str, 1, i-1), string.sub(str, j+1)
	else
		return str
	end
end

function remove_slash(s)
	-- Check if the last character is a "/"
	if string.sub(s, -1) == "/" then
		-- Remove the last character
		s = string.sub (s, 1, -2)
	end
	-- Return the modified string
	return s
end

function get_end_path_name(s)
	local t={}
	for str in string.gmatch(s, "([^/]+)") do
		t = str
	end
	return t
end

function get_after_space(str)
	local i = string.find(str, " ") -- find the first space
	if i then -- if there is a space
		return string.sub(str, i + 1) -- return the substring after the space
	else -- if there is no space
		return "" -- return an empty string
	end
end

local function get_buffer_path()
	local path = vim.api.nvim_buf_get_name(0)
	if vim.fn.isdirectory(path) ~= 0 then
		return path
	elseif file_exists(path) then
		return vim.fn.fnamemodify(path, ':h')
	else
		return vim.loop.cwd()
	end
end

local path = get_buffer_path()
local hooks = path..'/hooks'

local function fname_aux()
	local file = bufname[vim.api.nvim_get_current_buf()]
	if file == nil then
		if vim.api.nvim_buf_get_name(0) == hooks then
			file = {vim.api.nvim_buf_get_name(0), "hooks"}
		else
			file = {vim.api.nvim_buf_get_name(0), "file"}
		end
	end
	return file
end

local function fname_aux_set(file)
	if vim.fn.isdirectory(file) ~= 0 then
		file = {file, "term"}
	elseif file == hooks then
		file = {file, "hooks"}
	else
		file = {file, "file"}
	end
	return file
end

function has_multiple_slashes_in_row(s)
	local i = 1
	for c in s:gmatch"." do
		if i ~= #s and string.sub(s,i,i) == "/" and string.sub(s,i+1,i+1) == "/" then
			return true
		end
		i = i+1
	end
	return false
end

local function chk_num(name)
	local num = 1

	if vim.fn.filereadable(hooks) == 0 then return 0 end
	for line in io.lines(hooks) do
		local path, _ = format_path(line)
		if path == name then
			return num
		end
		num = num+1
	end
	return 0
end

local function chk_num_v2(name)
	local num = 1
	for line in io.lines(hooks) do
		if name == line then
			return num
		end
		num = num+1
	end
	return 0
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
		return vim.api.nvim_buf_get_name(0).."⇁ "
	else
		local path = format_path(fname_aux()[1])


		local first = get_end_path_name(path)
		if string.sub(path, -1) == "/" then
			first = first.."/"
		end
		local last = get_after_space(fname_aux()[1])
		if last == "" then
			local idx = chk_num(path)
			local opts = lines_from(hooks)
			tmux_protocol(idx, opts)
			return vim.fn.getcwd()

		else
			local idx = chk_num_v2(path.." "..last)
			local opts = lines_from(hooks)
			tmux_protocol(idx, opts)
			return vim.fn.getcwd()
		end
	end
end

local function fname_set_cleaned(file)
	local path, args = format_path(file)
	if fname_aux_set(path)[2] == "file" then
		if args == nil then
			return " "..get_end_path_name(path).."@ "
		else
			return " "..get_end_path_name(path).."@".." -- "..args.." "
		end
	else
		if args == nil then
			return " [ "..get_end_path_name(path).." ] "
		else
			return " [ "..get_end_path_name(path).." ]".." -- "..args.." "
		end
	end
end

local function is_tmux_running()
	local tmux_check_command = "tmux list-sessions"
	local status = os.execute(tmux_check_command)

	if status == 0 then
		-- tmux is running
		return true
	else
		-- tmux is not running
		return false
	end
end

function tmux_protocol(n, opts)
	local tmux_string = ""
	local km = key_map(n)
	if type(opts) == "table" then
		for i,v in ipairs(opts) do
			if v ~= "" and key_map(n) ~= key_map(i) then
				tmux_string = 
				tmux_string..
				"#[bg=yellow]#[fg=colour16]"..key_map(i)..
				"#[fg=white]#[bg=colour16]"..fname_set_cleaned(v)
			elseif v ~= "" and key_map(n) == key_map(i) then
				tmux_string = 
				tmux_string..
				"#[bg=hotpink]#[fg=colour16]"..key_map(i)..
				"#[fg=white]#[bg=colour52]"..fname_set_cleaned(v)
			end
		end
	end
	local function_name = "update_tmux_status_line"
	local line_number = 0
	local command = "python3 /home/saifr/scripts/tmux.py " .. function_name .. " " .. line_number .. " '" .. tmux_string .. "'"
	os.execute(command)
end

local function fname()
	return fname_aux()[1]
end

local function pfname_aux()
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
			print(pfname_aux().."/")
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
local function rehook_helper()
	vim.cmd("set autochdir")
	local path = get_buffer_path()
	hooks = path..'/hooks'

	local idx = chk_num(fname())
	local opts = lines_from(hooks)
	tmux_protocol(idx, opts)

	if not file_exists(hooks) then 
		print("hooks doesn't exist") 
	else
		vim.cmd([[autocmd InsertEnter hooks call PlaceSigns(-1,-1)]])
		hooks_fired = true
	end
end

local function rehook()
	if is_modified() == false then
		rehook_helper()
	else
		print("save modified buffers")
	end
end

local function rehook_force()
	rehook_helper()
end

ERROR_LINE = 0
kill_flag = false
file_line_number = {}

function is_file(path)
    local stat = vim.loop.fs_stat(path)
    return stat and stat.type == 'file'
end

function lines_from(file)
	dups = {}
	file_line_number = {}
	if not file_exists(file) then return {} end
	local lines = {}
	if vim.fn.filereadable(file) == 0 then return 0 end
	for line in io.lines(file) do
		local tmp_line = ""
		if is_file(format_path(line)) then
			tmp_line = format_path(line)
		end
		if tmp_line == "" then
			if dups[line] ~= nil and dups[line] ~= ""  then
				print("DUPLICATE hooks:"..#lines+1)
				ERROR_LINE = #lines+1
				kill_flag = true
				return
			else
				dups[line] = line 
			end
		else
			if dups[tmp_line] ~= nil and dups[tmp_line] ~= ""  then
				print("DUPLICATE hooks:"..#lines+1)
				ERROR_LINE = #lines+1
				kill_flag = true
				return
			else
				dups[tmp_line] = tmp_line 
			end
		end
		lines[#lines + 1] = line
		file_line_number[line] = #lines
	end
	return lines
end

-- #TODO vimscript -> lua
vim.cmd([[
function! PlaceSigns(n,m)
	let signs = ['j', 'k', 'l', ';', 'm', ',', '.', '/', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9']
	let current_buffer = bufnr('%')

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
		execute 'sign define sign' . i . ' text=' . sign . ' texthl=Search'
		execute 'sign place ' . i . ' line=' . i . ' name=sign' . i . ' buffer=' . current_buffer
		let i += 1
	endfor
endfunction
]])

local function signs(n,m)
	if n == nil then
		n = 0
	end
	if m == nil then
		m = 0
	end
	vim.cmd([[autocmd CursorMoved,BufWritePost,BufWinEnter hooks call 
	\PlaceSigns(]] .. n-1 .. [[, ]] .. m-1 .. [[)]])
end

n_shad = file_line_number[vim.api.nvim_buf_get_name(0)]
local function hook_file()
	vim.cmd("silent on")
	local path, args = format_path(current_buffer)
	if vim.fn.isdirectory(path) == 0 then 
		local n = file_line_number[vim.api.nvim_buf_get_name(0)]
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
	vim.cmd("e "..hooks)
	bufname[vim.api.nvim_get_current_buf()] = {hooks, "hooks"}
	ERROR_LINE = 0
end

local function hook_term()
	vim.cmd("on")
	hook_file()
	vim.cmd("sp")
	vim.cmd("wincmd j")
	vim.cmd("te")
end

term_bufnum = {}
local function set_dir_mode2(path, args)
	vim.cmd("te cd "..path.." && $SHELL")
	buffers[path.." "..args] = vim.api.nvim_get_current_buf()
	bufname[vim.api.nvim_get_current_buf()] = {path.." "..args, "term"}
	term_dict[fname()] = path
	term_bufnum[fname()] = vim.api.nvim_get_current_buf()
	vim.api.nvim_set_current_dir(path)
end

local function set_dir_mode1(path)
	vim.cmd("te cd "..path.." && $SHELL")
	buffers[path] = vim.api.nvim_get_current_buf()
	bufname[vim.api.nvim_get_current_buf()] = {path, "term"}
	term_dict[fname()] = path
	term_bufnum[fname()] = vim.api.nvim_get_current_buf()
	vim.api.nvim_set_current_dir(path)
end

local function hook_mode2(n, args)
	current_buffer = path.." "..args
	if vim.fn.isdirectory(path) ~= 0 then
		if buffers[current_buffer] == nil then
			set_dir_mode2(path, args)
		else
			local buf_loaded = vim.api.nvim_buf_is_loaded(buffers[path.." "..args])
			if buf_loaded == true then
				vim.api.nvim_set_current_buf(buffers[path.." "..args])
			else
				set_dir_mode2(path, args)
			end
		end
	elseif file_exists(path) then
		file_args = args
		if buffers[path] == nil then
			vim.cmd("e "..path)
			buffers[path] = vim.api.nvim_get_current_buf()
			bufname[vim.api.nvim_get_current_buf()] = {path, "file"}
		else
			vim.api.nvim_set_current_buf(buffers[path])
		end
	else
		print("MALFORMED hooks:"..n)
		ERROR_LINE = n
	end
end

local function hook_mode1(n)
	file_args = ""
	current_buffer = path
	if vim.fn.isdirectory(path) ~= 0 then 
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
		if path == hooks then
			print("cannot reference current hookfile")
			ERROR_LINE = n
			return
		end

		if buffers[path] == nil then
			vim.cmd("e "..path)
			buffers[path] = vim.api.nvim_get_current_buf()
			bufname[vim.api.nvim_get_current_buf()] = {path, "file"}
		else
			vim.api.nvim_set_current_buf(buffers[path])
		end
	else
		print("MALFORMED hooks:"..n)
		ERROR_LINE = n
	end
end

vim.cmd([[autocmd InsertEnter hooks call PlaceSigns(-1,-1)]])

local function hook(n)
	if vim.fn.filereadable(hooks) == 0 then print("hooks file doesn't exist or isn't readble") return end
	ERROR_LINE = 0
	vim.cmd("silent on")
	if file_exists(hooks) == false then
		print("HOOKS NOT FOUND")
		return
	end
	local opts = lines_from(hooks)

	if kill_flag == true then
		kill_flag = false
		return
	end

	if opts[n] == nil then
		print("UNSET hooks:"..n)
		return
	end

	path, args = format_path(opts[n])

	if string.sub(path,-1) == "/" then
		print("CANNOT END PATH WITH '/'  "..n)
		ERROR_LINE = n
		signs(n_shad, ERROR_LINE)
		return
	end

	if has_multiple_slashes_in_row(path) then
		print("REPEAT SLASHES NOT ALLOWED "..n)
		ERROR_LINE = n
		signs(n_shad, ERROR_LINE)
		return
	end

	if path == "" then
		print("UNSET hooks:"..n)
		return
	end
	if args == nil then hook_mode1(n) else hook_mode2(n, args) end
	if ERROR_LINE ~= 0 then
		signs(n_shad, ERROR_LINE)
	else
		signs(n,ERROR_LINE)
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
		print("COPIED TO CLIPBOARD: "..file)
	else
		file = vim.api.nvim_buf_get_name(0)
		print("COPIED TO CLIPBOARD: "..file)
	end
	vim.api.nvim_call_function('setreg', {'+', file})
end

function term_buffer_directory_onchange()
	term_dict[fname()] = vim.fn.getcwd()
end

local function on_buffer_enter()
	local idx = chk_num(fname())
	local opts = lines_from(hooks)
	tmux_protocol(idx, opts)

	if term_dict[fname()] ~= nil then
		local path, _ = format_path(term_dict[fname()])
		vim.api.nvim_set_current_dir(path)
	end

	if hooks_fired == true then
		for key, value in pairs(term_bufnum) do
			vim.cmd([[bd! ]]..value)
		end
		term_bufnum = {}
		hooks_fired = false
	end
end

local function on_neovim_exit()
	local function_name = "update_tmux_status_line"
	local line_number = 0
	local command = "python3 /home/saifr/scripts/tmux.py " .. function_name .. " " .. line_number ..
			" '" .. "#[fg=red]NVIM EXITED" .. "'"
	os.execute(command)
end

function register_autocommands()
	vim.api.nvim_create_autocmd('BufEnter', {pattern = '*', callback = on_buffer_enter})
	vim.api.nvim_create_autocmd('VimLeavePre', {callback = on_neovim_exit})
	if os.getenv("TMUX") == nil then print("WARNING: running hooks without tmux") end
end

-- key bindings
vim.keymap.set('n', 'fj', function() hook(1) end)
vim.keymap.set('n', 'fk', function() hook(2) end)
vim.keymap.set('n', 'fl', function() hook(3) end)
vim.keymap.set('n', 'f;', function() hook(4) end)
vim.keymap.set('n', 'fm', function() hook(5) end)
vim.keymap.set('n', 'f,', function() hook(6) end)
vim.keymap.set('n', 'f.', function() hook(7) end)
vim.keymap.set('n', 'f/', function() hook(8) end)
vim.keymap.set('n', 'fs', function() hook_term() end)
vim.keymap.set('n', 'fa', function() copy_filename() end)
vim.keymap.set('n', 'fd', function() hook_file() end)
vim.keymap.set('n', 'fn', function() pfname() end, {})

local function tmux_warning()
	print("tmux is off")
end

-- commands
vim.api.nvim_create_user_command("ReHook", function() rehook() end, {})
vim.api.nvim_create_user_command("ReHookForce", function() rehook_force() end, {})
vim.api.nvim_create_user_command("TBdc", function() term_buffer_directory_onchange() end, {})
vim.api.nvim_create_user_command("Warn", function() tmux_warning() end, {})

function kill_flag_set(bool_val)
	kill_flag = bool_val
end

M = {
	fname_cleaned = fname_cleaned,
	fname_set_cleaned = fname_set_cleaned,
	hooks = hooks,
	lines_from = lines_from,
	signs = signs,
	ERROR_LINE = ERROR_LINE,
	kill_flag_set = kill_flag_set,
	key_map = key_map,
	register_autocommands = register_autocommands
}

return M
