function file_exists(path)
	if path ~= nil then
		local f=io.open(path,"r")
		if f~=nil then io.close(f) return true else return false end
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

-- global vars -------------------------------------
local buffer_path = vim.api.nvim_buf_get_name(0)
local path = get_buffer_path()
local hooks = path..'/hooks'
current_buffer = buffer_path
local buffers = {}
----------------------------------------------------

-- funcs continued
local function rehook()
	vim.cmd("set autochdir")
	local path = get_buffer_path()
	hooks = path..'/hooks'
	print(hooks)
	--if not file_exists(hooks) then print("hooks doesn't exist") end
end

kill_flag = false
function lines_from(file, n)
	dups = {}
	if not file_exists(file) then return {} end
	local lines = {}
	for line in io.lines(file) do
		if dups[line] ~= nil and dups[line] ~= ""  then
			print("DUPLICATE hooks:"..#lines+1)
			kill_flag = true
			return
		else
			dups[line] = line
		end
		lines[#lines + 1] = line
	end
	return lines
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

local function hook_file()
	current_buffer = path.."/hooks"
	vim.cmd("on")
	print(hooks)
	vim.cmd("e "..hooks)
end

local function hook_term()
	vim.cmd("on")
	hook_file()
	vim.cmd("sp")
	vim.cmd("wincmd j")
	vim.cmd("te")
end

local function set_dir_mode2(path, args)
	vim.cmd("te cd "..path.." && $SHELL")
	buffers[path.." "..args] = vim.api.nvim_get_current_buf()
end

local function set_dir_mode1(path)
	vim.cmd("te cd "..path.." && $SHELL")
	buffers[path] = vim.api.nvim_get_current_buf()
end

local function hook_mode2(n, args)
	current_buffer = path.." "..args
	print(path.." "..args)
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
		print("FILES CANNOT BE LABELED hooks:"..n)
	else
		print("MALFORMED hooks:"..n)
	end
end

local function hook_mode1(n)
	current_buffer = path
	print(path)
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
		if buffers[path] == nil then
			vim.cmd("e "..path)
			buffers[path] = vim.api.nvim_get_current_buf()
		else
			vim.api.nvim_set_current_buf(buffers[path])
		end
	else
		print("MALFORMED hooks:"..n)
	end
end

local function hook(n)
	vim.cmd("silent on")
	if file_exists(hooks) == false then
		print("HOOKS NOT FOUND")
		return
	end
	local opts = lines_from(hooks, n)
	if kill_flag == true then
		kill_flag = false
		return
	end
	if opts[n] == nil then
		print("UNSET hooks:"..n)
		return
	end
	path, args = format_path(opts[n])
	if path == "" then
		print("UNSET hooks:"..n)
		return
	end
	if args == nil then hook_mode1(n) else hook_mode2(n, args) end
end

local function copy_filename()
	local file = format_path(current_buffer)
	print("COPIED TO CLIPBOARD: "..file)
	vim.api.nvim_call_function('setreg', {'+', file})
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
vim.keymap.set('n', 'fn', function() print(current_buffer) end, {})

-- commands
vim.api.nvim_create_user_command("ReHook", function() rehook() end, {})
