local M = {}

function file_content(source_path)
    local source_file = io.open(source_path, "r")
    if not source_file then
        print("Error: Could not open " .. source_path .. " for reading.")
        return
    end
    local content = source_file:read("*all")
    source_file:close()
    return content
end

M = {
    file_content = file_content
}

return M
