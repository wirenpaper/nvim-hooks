local M = {}

function M.clone_current_buffer()
    local current_buf = vim.api.nvim_get_current_buf()
    local original = vim.api.nvim_buf_get_name(current_buf)
    
    if original == '' then
        vim.notify("No file in current buffer. Mission impossible.", vim.log.levels.WARN)
        return
    end
    
    local new = original .. '.clone'
    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    local view = vim.fn.winsaveview()
    
    local success = os.execute(string.format('cp "%s" "%s"', original, new))
    
    if success then
        vim.api.nvim_buf_call(current_buf, function()
            vim.cmd('write')
        end)
        
        vim.cmd('edit ' .. new)
        vim.api.nvim_win_set_cursor(0, cursor_pos)
        vim.fn.winrestview(view)
        vim.cmd('write')
        
        vim.notify("Buffer cloned as " .. vim.fn.fnamemodify(new, ':t'), vim.log.levels.INFO)

        local current_file = vim.fn.expand('%:t')
        local clone_file = current_file .. '.clone'
        local buf_id = vim.fn.bufnr(clone_file)
    else
        vim.notify("Clone operation failed!", vim.log.levels.ERROR)
    end
end

function M.delete_clone()
    local current_buf = vim.api.nvim_get_current_buf()
    local original = vim.api.nvim_buf_get_name(current_buf)
    
    if original == '' then
        vim.notify("No file in current buffer. Mission impossible.", vim.log.levels.WARN)
        return
    end
    
    local clone_path = original .. '.clone'
    
    -- Check if clone exists
    local clone_exists = vim.fn.filereadable(clone_path) == 1
    
    if not clone_exists then
        vim.notify("No clone found for elimination.", vim.log.levels.WARN)
        return
    end
    
    -- Delete the clone file
    local success = os.remove(clone_path)
    
    if success then
        vim.notify("Clone eliminated.", vim.log.levels.INFO)
    else
        vim.notify("Clone elimination failed!", vim.log.levels.ERROR)
    end
end

vim.api.nvim_create_user_command('CloneBuffer', M.clone_current_buffer, {})
vim.api.nvim_create_user_command('DeleteCloneBuffer', M.delete_clone, {})

return M
