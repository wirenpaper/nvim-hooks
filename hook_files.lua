package.path = package.path .. ";/home/saifr/.config/nvim/plugin/hooks/?.lua"
local hooks = require'hooks'
local lualine = require'lualine'
local utils = require'utilities'

local M = {}

M.MARKER = "__f__"
path = hooks.path .. '/.hook_files/'
marker_path = path .. M.MARKER

-- Telescope requirements
local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local conf = require('telescope.config').values
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local previewers = require('telescope.previewers')

local function workspace_dir_isempty()
    path = hooks.path .. "/.hook_files/"
    local files = vim.fn.readdir(path, function(name)
        return name ~= '__f__' -- This keeps all files except '__f__'
    end)

    -- Then check if the resulting list has any files
    if #files > 0 then
        -- Directory has files other than '__f__'
    else
        -- Directory is empty (or only contains '__f__')
    end
end

local function file_write(content, target_path)
    local target_file = io.open(target_path, "w")
    if not target_file then
        print("Error: Could not open " .. target_path .. " for writing.")
        return
    end

    target_file:write(content)
    target_file:close()
end

local function file_copy(source_path, target_path)
    local content = utils.file_content(source_path)
    file_write(content, target_path)
end

local function bookmark(fname, marker_path)
    local file = io.open(marker_path, "w")
    if file then
        file:write(fname)
        file:close()
    else
        print("Error: Could not open " .. M.MARKER .. " for writing.")
    end
end

local function set_hookfiles(fname)
    local config = lualine.get_config()
    config.sections.lualine_x[3] = function() return fname end
    config.inactive_sections.lualine_x[3] = function() return fname end
    lualine.setup(config)
end

local function comp(ArgLead, CmdLine, CursorPos)
    local files = vim.fn.readdir(hooks.path .. '/.hook_files/', function(name)
        return name ~= M.MARKER and name:sub(1, #ArgLead) == ArgLead
    end)
    return files
end

function M.hook_files(arg, flt)
    local hook_files = vim.fn.readdir(hooks.path .. '/.hook_files/', function(name)
        local function default_conditions()
            return name ~= M.MARKER and name ~= flt and name ~= "tasks"
        end
        if arg == "DELETE" then 
            return default_conditions() and name ~= utils.file_content(hooks.path .. "/.hook_files/" .. M.MARKER)
        end
        return default_conditions()
    end)

    if #hook_files == 0 then
        if arg == "SWITCH" then
            vim.cmd("redraw")
            print("No files listed")
            return
        end

        if arg == "COPY" then
            print("No files listed")
        end

        if string.sub(arg, 1, #"COPY ") == "COPY " then
            vim.ui.input({
                prompt = "Copy to: "
            }, function(input)
                if input then
                    local path = hooks.path .. "/.hook_files/" .. string.sub(arg, #"COPY "+1)
                    hookfiles_cp_ex(path, hooks.path .. "/.hook_files/" .. input)
                else
                    print("Action cancelled")
                end
            end)
            return
        end

        if arg == "RENAME" then
            vim.cmd("redraw")
            print("No files listed")
            return
        elseif string.sub(arg, 1, #"RENAME ") == "RENAME " then
            vim.ui.input({
                prompt = "Rename to: "
            }, function(input)
                if input then
                    local path = hooks.path .. "/.hook_files/" .. string.sub(arg, 8)
                    hookfiles_ren_ex(path, hooks.path .. "/.hook_files/" .. input)
                else
                    print("Action cancelled")
                end
            end)
            return
        end
    end

    pickers.new({}, {
        prompt_title = "filter",
        layout_config = {
            width = .99,
            preview_width = 0.8,
        },
        finder = finders.new_table {
            results = hook_files,
            -- Add path here so the previewer can access it
            entry_maker = function(entry)
                return {
                    value = entry,
                    display = entry,
                    ordinal = entry,
                    path = hooks.path .. '/.hook_files/' .. entry,
                }
            end
        },
        previewer = previewers.new_buffer_previewer({
            title = arg,
            define_preview = function(self, entry)
                -- Read and display file contents
                local content = vim.fn.readfile(entry.path)
                vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, content)

                -- Optionally set filetype for syntax highlighting
                -- You might want to detect this based on file extension
                vim.bo[self.state.bufnr].filetype = 'lua'
            end,
        }),
        sorter = conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr)
            actions.select_default:replace(function()
                local entry = action_state.get_selected_entry()
                actions.close(prompt_bufnr)

                -- Schedule the print to ensure it runs after telescope closes
                vim.schedule(function()
                    if arg == "SWITCH" then
                        if entry and entry.value then
                            hookfiles(entry.value)
                        else
                            print("No such Workspace")
                        end
                    elseif arg == "DELETE" then
                        if entry and entry.value then
                            hookfiles_del(entry.value)
                        else
                            print("Select from list only")
                        end
                    elseif arg == "RENAME" then
                        if entry and entry.value then
                            hookfiles_ren(entry.value, entry.value)
                        else
                            print("No such Workspace")
                        end
                    elseif arg == "COPY" then
                        if entry and entry.value then
                            hookfiles_cp(entry.value, entry.value)
                        else
                            print("No such Workspace")
                        end
                    elseif string.sub(arg, 1, 7) == "RENAME " then
                        local path = hooks.path .. "/.hook_files/" .. string.sub(arg, 8)
                        if entry and entry.value then
                            hookfiles_ren_ex(path, hooks.path .. "/.hook_files/" .. entry.value)
                        else
                            -- THE POOMING
                            hookfiles_ren_ex(path, hooks.path .. "/.hook_files/" .. action_state.get_current_line())
                        end
                    elseif string.sub(arg, 1, 5) == "COPY " then
                        local path = hooks.path .. "/.hook_files/" .. string.sub(arg, #"COPY "+1)
                        if entry and entry.value then
                            hookfiles_cp_ex(path, hooks.path .. "/.hook_files/" .. entry.value)
                        else
                            hookfiles_cp_ex(path, hooks.path .. "/.hook_files/" .. action_state.get_current_line())
                        end
                    end
                end)
            end)
            return true
        end,
    }):find()
end

-- telescope commands
vim.api.nvim_create_user_command('Ws', function() 
    if workspace_dir_isempty() then
        print("No workspaces found")
        return
    end
    M.hook_files("SWITCH", utils.file_content(hooks.path .. "/.hook_files/" .. M.MARKER)) 
end, {})

function hookfiles(fname)
    bookmark(fname, marker_path)
    set_hookfiles(fname)
    hooks.rehook(hooks.path .. '/.hook_files/' .. fname, true)
end

vim.api.nvim_create_user_command('Wy', function()
    --M.hook_files("COPY") 
    if workspace_dir_isempty() then
        print("There are no workspaces")
        return
    end

    vim.ui.input({
        prompt = "Current workspace? (y/n): "
    }, function(input)
        flt = utils.file_content(hooks.path .. "/.hook_files/" .. M.MARKER)
        if input == "n" then
            M.hook_files("COPY", flt) 
        elseif input == "y" then
            local path = utils.file_content(hooks.path .. "/.hook_files/" .. M.MARKER)
            if path and path ~= "" then
                hookfiles_cp(path, flt)
            else
                print("Workspace doesnt exist")
            end
        else
            print("Action cancelled")
        end
    end)
end, {})

function hookfiles_cp(fname, flt)
    local source_path = hooks.path .. '/.hook_files/' .. fname
    M.hook_files("COPY " .. source_path:match("([^/]+)$"), flt)
end

function hookfiles_cp_ex(file, target)
    if target:sub(-1) == ":" then target = target:sub(1, -2) end

    function cp(file, target)
        vim.fn.system('cp ' .. file .. ' ' .. target)
        print(file:match("([^/]+)$") .. " -> " .. target:match("([^/]+)$") .. " [COPIED]")
    end
    
    if source == target then
        print("same file")
        return
    end

    if target:match("([^/]+)$") == utils.file_content(hooks.path .. "/.hook_files/" .. M.MARKER) then
        vim.ui.input({
            prompt = "COPY TO CURRENT WORKSPACE ?! Overwrite? (y/n): "
        }, function(input)
            if input == "y" then
                cp(file, target)
                hooks.on_buffer_enter()
            else
                print("Copy cancelled")
            end
        end)
        return
    elseif vim.fn.filereadable(target) == 1 then
        vim.ui.input({
            prompt = "File exists. Overwrite? (y/n): "
        }, function(input)
            if input == "y" then
                cp(file, target)
            else
                print("Copy cancelled")
            end
        end)
        return
    end
    
    cp(file, target)
end

vim.api.nvim_create_user_command('Wm', function() 
    if workspace_dir_isempty() then
        print("There are no workspaces")
        return
    end

    vim.ui.input({
        prompt = "Current workspace? (y/n): "
    }, function(input)
        flt = utils.file_content(hooks.path .. "/.hook_files/" .. M.MARKER)
        if input == "n" then
            M.hook_files("RENAME", flt) 
        elseif input == "y" then
            local path = utils.file_content(hooks.path .. "/.hook_files/" .. M.MARKER)
            if path and path ~= "" then
                hookfiles_ren(path, flt)
            else
                print("Workspace doesnt exist")
            end
        else
            print("Action canncelled")
        end
    end)
end, {})

function hookfiles_ren(fname, flt)
    local source_path = hooks.path .. '/.hook_files/' .. fname
    M.hook_files("RENAME " .. source_path:match("([^/]+)$"), flt)
end


function hookfiles_ren_ex(file, target)
    if target:sub(-1) == ":" then target = target:sub(1, -2) end

    function ren(file, target)
        vim.fn.rename(file, target)
        if file:match("([^/]+)$") == utils.file_content(hooks.path .. "/.hook_files/" .. M.MARKER) then
            bookmark(target:match("([^/]+)$"), hooks.path .. "/.hook_files/" .. M.MARKER)
            set_hookfiles(target:match("([^/]+)$"))
            hooks.rehook(hooks.path .. '/.hook_files/' .. target:match("([^/]+)$"))
        end
        vim.cmd("redraw")
        print(file:match("([^/]+)$") .. " -> " .. target:match("([^/]+)$") .. " [RENAMED]")
    end

    if source == target then
        print("same file")
        return
    end

    if target:match("([^/]+)$") == utils.file_content(hooks.path .. "/.hook_files/" .. M.MARKER) then
        vim.ui.input({
            prompt = "RENAME TO CURRENT WORKSPACE ?! Overwrite? (y/n): "
        }, function(input)
            if input == "y" then
                ren(file, target)
                hooks.on_buffer_enter()
            else
                print("Rename cancelled")
            end
        end)
        return
    elseif vim.fn.filereadable(target) == 1 then
        vim.ui.input({
            prompt = "File exists. Overwrite? (y/n): "
        }, function(input)
            if input == "y" then
                ren(file, target)
                set_hookfiles()
                hooks.on_buffer_enter()
            else
                print("Rename cancelled")
            end
        end)
        return
    end

    ren(file, target)
end

vim.api.nvim_create_user_command('Wd', function() M.hook_files("DELETE") end, {})
function hookfiles_del(fname)
    if fname:sub(-1) == ":" then fname = fname:sub(1, -2) end
    if workspace_dir_isempty() then
        print("There are no workspaces")
        return
    end

    if fname == utils.file_content(hooks.path .. "/.hook_files/" .. M.MARKER) then
        print("Cannot delete self.")
        return
    end

    vim.ui.input({
        prompt = "Delete file? Are you sure? (y/n): "
    }, function(input)
        if input == "y" then
            local file = hooks.path .. '/.hook_files/' .. fname
            local success, err = os.remove(file)

            if success then
                print(fname .. " [DELETED]")
            else
                print(fname .. " not deleted; error: " .. err)
                return
            end
        else
            print("Delete operation cancelled")
        end
    end)
end

local uv = vim.loop

local function list_files(dir)
    local files = {}
    local handle = uv.fs_scandir(dir)
    if handle then
        while true do
            local name, type = uv.fs_scandir_next(handle)
            if not name then break end
            if type == 'file' and name ~= '__f__' then
                table.insert(files, name)
            end
        end
    end
    return files
end

-- Split content into lines
local function split_lines(str)
    local lines = {}
    for line in str:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end
    return lines
end

-- Check if line exists in file
local function line_exists_in_file(filepath, line_to_check)
    local file = io.open(filepath, "r")
    if not file then return false end
    
    for file_line in file:lines() do
        if file_line == line_to_check then
            file:close()
            return true
        end
    end
    file:close()
    return false
end

vim.api.nvim_create_user_command('Seed', function()
    local files = list_files(hooks.path .. "/.hook_files")
    local content = utils.file_content(hooks.path .. "/hooks")
    local content_lines = split_lines(content)
    
    for _, file in ipairs(files) do
        local filepath = hooks.path .. "/.hook_files/" .. file
        local lines_to_append = {}
        
        -- Check each line from source file
        for _, line in ipairs(content_lines) do
            -- If line doesn't exist anywhere in target file, add it to append list
            if not line_exists_in_file(filepath, line) then
                table.insert(lines_to_append, line)
            end
        end
        
        -- If we have any new lines to append
        if #lines_to_append > 0 then
            local file_handle = io.open(filepath, "a")
            if file_handle then
                file_handle:write("\n" .. table.concat(lines_to_append, "\n"))
                file_handle:close()
            end
        end
    end
end, {})

vim.api.nvim_create_user_command('Weed', function()
    local files = list_files(hooks.path .. "/.hook_files")
    local content = utils.file_content(hooks.path .. "/hooks")
    local lines_to_remove = split_lines(content)
    
    for _, file in ipairs(files) do
        local filepath = hooks.path .. "/.hook_files/" .. file
        local file_handle = io.open(filepath, "r")
        if file_handle then
            local file_lines = {}
            -- Read all lines, keeping only non-matching ones
            for line in file_handle:lines() do
                local should_keep = true
                for _, remove_line in ipairs(lines_to_remove) do
                    if line == remove_line then
                        should_keep = false
                        break
                    end
                end
                if should_keep then
                    table.insert(file_lines, line)
                end
            end
            file_handle:close()
            
            -- Write back the filtered content
            file_handle = io.open(filepath, "w")
            if file_handle then
                file_handle:write(table.concat(file_lines, "\n"))
                file_handle:close()
            end
        end
    end
end, {})

return M
