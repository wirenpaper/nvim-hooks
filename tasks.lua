package.path = package.path .. ";/home/saifr/.config/nvim/plugin/hooks/?.lua"
local hooks = require'hooks'
local Queue = require'queue'

local M = {}

-- Helper function to create a simple promise-like object
local function create_promise()
    local handlers = {}
    return {
        resolve = function(value)
            if handlers.resolve then handlers.resolve(value) end
        end,
        reject = function(err)
            if handlers.reject then handlers.reject(err) end
        end,
        then_do = function(resolve_handler, reject_handler)
            handlers.resolve = resolve_handler
            handlers.reject = reject_handler
        end
    }
end
local Localhost = {}
Localhost.__index = Localhost

function Localhost:new(instruction, port)
    local instance = setmetatable({}, Localhost)
    instance.job_id = -1
    instance.is_active = false
    instance.instruction = instruction
    instance.port = port
    return instance
end

function pop_cmds()
    local cmds = { 
        {Localhost:new("ng serve", 4200)},
        {Localhost:new("ng serve --port 4209", 4209), 1}
    }
    for _, el in ipairs(cmds) do
        if el[2] then
            el[2] = cmds[el[2]]
        end
    end
    run_tasks(cmds)
end

vim.api.nvim_create_user_command('PopCmds', pop_cmds, {})

function run_tasks(cmds)
    vim.schedule(function()
        for _, cmd in ipairs(cmds) do
            if not cmd[2] then  -- No dependency
                run_localhost(cmd[1])
            else
                -- Start a single async watcher for this command
                local function watch_dependency()
                    local job_id = vim.fn.jobstart({'sleep', '0.5'}, {
                        on_exit = function()
                            if cmd[2][1].is_active then
                                run_localhost(cmd[1])
                            else
                                watch_dependency()  -- Check again in 500ms
                            end
                        end
                    })
                end
                watch_dependency()
            end
        end
    end)
end

local task_path = hooks.path .. '/.hook_files/tasks/'

function run_localhost(cmd)
    if cmd.job_id > 0 then
        return  -- Prevent multiple starts
    end
    
    vim.cmd("redraw")
    local working_dir = vim.fn.fnamemodify(task_path, ":h:h")
    
    local job_id = vim.fn.jobstart(cmd.instruction, {
        cwd = working_dir,
        detach = true,
        stdout_buffered = true,
        stderr_buffered = true,
    })
    
    if job_id > 0 then
        cmd.job_id = job_id
        print('Initiating server on port:', cmd.port)
        
        -- Start a single async watcher for the port
        local function watch_port()
            local port_check_job = vim.fn.jobstart({'nc', '-z', 'localhost', tostring(cmd.port)}, {
                on_exit = function(_, exit_code)
                    if exit_code == 0 then
                        cmd.is_active = true
                        print("port " .. cmd.port .. " is running")
                    else
                        vim.fn.jobstart({'sleep', '0.5'}, {
                            on_exit = function()
                                watch_port()  -- Check again in 500ms
                            end
                        })
                    end
                end
            })
        end
        
        watch_port()
    else
        vim.cmd("redraw")
        print('Failed to start local server')
    end
end

vim.api.nvim_create_user_command('RunTasks', run_tasks, {})
-- kill -9 $(lsof -t -i:4200)

function AttachToLocalServer()
  local job_id = 0 -- Replace this with the job ID you got from running ng_serve
  vim.fn.termopen('', {
    on_stdout = function(_, data, _)
      print(table.concat(data, '\n'))
    end,
    on_stderr = function(_, data, _)
      print(table.concat(data, '\n'))
    end,
    on_exit = function(_, code, _)
      if code ~= 0 then
        print('Local server exited with code:', code)
      end
    end,
    detach = false, -- Keep the terminal attached
    stoponexit = 'kill', -- Kill the job when the terminal is closed
    job_id = job_id, -- Attach to the specific job ID
  })
end

function KillLocalServer(job_id)
    vim.fn.jobstop(job_id)
    print("Local server stopped with job ID:", job_id)
end

return M
