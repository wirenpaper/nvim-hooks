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
local function rehook_helper()
	vim.cmd("set autochdir")
	local path = get_buffer_path()
	hooks = path..'/hooks'
	if not file_exists(hooks) then 
		print("hooks doesn't exist") 
	else
		vim.cmd([[autocmd InsertEnter hooks call PlaceSigns(-1,-1)]])
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
function lines_from(file, n)
	dups = {}
	file_line_number = {}
	if not file_exists(file) then return {} end
	local lines = {}
	for line in io.lines(file) do
		if dups[line] ~= nil and dups[line] ~= ""  then
			print("DUPLICATE hooks:"..#lines+1)
			ERROR_LINE = #lines+1
			kill_flag = true
			return
		else
			dups[line] = line
		end
		lines[#lines + 1] = line
		file_line_number[line] = #lines
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

-- #TODO vimscript -> lua
vim.cmd([[
function! PlaceSigns(n,m)
	let signs = ['j', 'k', 'l', ';', 'm', ',', '.', '/', '!!', '!!', '!!', '!!', '!!']
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
	vim.cmd([[autocmd CursorMoved,BufWritePost,BufWinEnter hooks call 
	\PlaceSigns(]] .. n-1 .. [[, ]] .. m-1 .. [[)]])
end

lines_from(hooks,1)
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
	bufname[vim.api.nvim_get_current_buf()] = hooks
	ERROR_LINE = 0
end

local function hook_term()
	vim.cmd("on")
	hook_file()
	vim.cmd("sp")
	vim.cmd("wincmd j")
	--vim.cmd("te cd "..path.." && $SHELL")
	vim.cmd("te")
end

bufname = {}
local function set_dir_mode2(path, args)
	vim.cmd("te cd "..path.." && $SHELL")
	buffers[path.." "..args] = vim.api.nvim_get_current_buf()
	bufname[vim.api.nvim_get_current_buf()] = path.." "..args
end

local function set_dir_mode1(path)
	vim.cmd("te cd "..path.." && $SHELL")
	buffers[path] = vim.api.nvim_get_current_buf()
	bufname[vim.api.nvim_get_current_buf()] = path
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
		print("FILES CANNOT BE LABELED hooks:"..n)
		ERROR_LINE = n
	else
		print("MALFORMED hooks:"..n)
		ERROR_LINE = n
	end
end

local function hook_mode1(n)
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
			bufname[vim.api.nvim_get_current_buf()] = path
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
	if ERROR_LINE ~= 0 then
		signs(n_shad, ERROR_LINE)
	else
		signs(n,ERROR_LINE)
		n_shad = n
	end
end

local function copy_filename()
	local file = format_path(bufname[vim.api.nvim_get_current_buf()])
	if file ~= nil then
		print("COPIED TO CLIPBOARD: "..file)
	else
		file = vim.api.nvim_buf_get_name(0)
		print("COPIED TO CLIPBOARD: "..file)
	end
	vim.api.nvim_call_function('setreg', {'+', file})
end

local function pfname()
	local file = bufname[vim.api.nvim_get_current_buf()]
	if file == nil then
		file = vim.api.nvim_buf_get_name(0)
	end
	print(file)
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

-- commands
vim.api.nvim_create_user_command("ReHook", function() rehook() end, {})
vim.api.nvim_create_user_command("ReHookForce", function() rehook_force() end, {})
vim.api.nvim_create_user_command("Lsa", function() vim.cmd([[ls +]]) end, {})
