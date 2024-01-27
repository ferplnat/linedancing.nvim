local M = {}

local StatusLineComponent = require('linedancing.statusline')
local async = require('plenary.async')

M.on_events = {
    ["WinResized"] = true,
    ["VimResized"] = true,
}

--- @type StatusLineComponent[]
M.registered_components = {}

--- Registers a given statusline component for event processing to work
--- @param statusline_component StatusLineComponentConfiguration
--- @return nil
M.register_statusline_component = function(statusline_component)
    --- @type StatusLineComponent
    statusline_component = StatusLineComponent:new(statusline_component)
    table.insert(M.registered_components, statusline_component)
    if not statusline_component.event and not statusline_component.user_event then
        return
    end

    for _, event in pairs(statusline_component.event) do
        M.on_events[event] = true
    end

    if statusline_component.user_event ~= nil then
        if M.on_events["User"] == nil then
            M.on_events["User"] = {}
        end

        M.on_events["User"] = vim.tbl_extend("error", M.on_events["User"], statusline_component.user_event)
    end

    statusline_component.callback = async.wrap(statusline_component.callback, 1)
end

--- Updates computed values for registered components.
--- @param event any Autocmd event.
--- @return nil
M.update_components = function(event)
    local bufnr = event.buf
    local win_id = vim.fn.bufwinid(bufnr)

    if win_id == nil or win_id == -1 then
        return
    end

    local win_config = vim.api.nvim_win_get_config(win_id)
    if not win_config.relative == "" then
        return
    end

    local component_updated = false
    for _, component in pairs(M.registered_components) do
        if component:update(event) then
            component_updated = true
        end
    end

    if component_updated then
        M.update_statusline(event)
    end
end

--- Update dimensions, padding, truncation for the statusline string. Does not update components.
--- @param event any Autocmd event
--- @return nil
M.update_statusline = function(event)
    local bufnr = event.buf
    local win_id = vim.fn.bufwinid(bufnr)

    if win_id == nil or win_id == -1 then
        return
    end

    local win_config = vim.api.nvim_win_get_config(win_id)
    if not win_config.relative == "" then
        return
    end

    local status_width = vim.api.nvim_eval_statusline('%=%=', { winid = win_id }).width

    local rendered_components = {
        ["left"] = {},
        ["center"] = {},
        ["right"] = {},
    }

    local rendered_components_width = {
        ["left"] = 0,
        ["center"] = 0,
        ["right"] = 0,
    }

    for _, component in pairs(M.registered_components) do
        table.insert(rendered_components[component.position], component:apply_highlight())
        rendered_components_width[component.position] = rendered_components_width[component.position] +
            component.last_width
    end

    local left_side = table.concat(rendered_components["left"])
    local center = table.concat(rendered_components["center"])
    local right_side = table.concat(rendered_components["right"])

    -- Get the width of the rendered strings
    local left_side_width = rendered_components_width["left"]
    local center_width = rendered_components_width["center"]
    local right_side_width = rendered_components_width["right"]

    -- Calculate the padding needed to align the rendered strings
    local left_side_padding = math.floor((status_width - center_width) / 2) - left_side_width
    local right_side_padding = math.ceil((status_width - center_width) / 2) - right_side_width

    -- Create the padding strings
    local left_padding = string.rep(' ', left_side_padding)
    local right_padding = string.rep(' ', right_side_padding)

    -- KA-CHOW!
    M.current_statusline = left_side .. left_padding .. center .. right_padding .. right_side
    vim.api.nvim_exec_autocmds("User", { pattern = "StatusLineComponentUpdated" })
end

--- Update window statusline with the last computed value.
--- @param event any Autocmd event
--- @return nil
M.show_statusline = function(event)
    local bufnr = event.buf
    local win_id = vim.fn.bufwinid(bufnr)

    if win_id == nil or win_id == -1 then
        return
    end
    vim.wo[win_id].statusline = M.current_statusline
end

--- Setup function to configure linedancing
--- @param conf StatusLineConfiguration Configuration table, see: linedancing-configuration.
M.setup = function(conf)
    for _, component in pairs(conf.components) do
        M.register_statusline_component(component)
    end

    local autocmd_group = vim.api.nvim_create_augroup('linedancing-autocmd', { clear = true })
    for event_type, val in pairs(M.on_events) do
        local settings = {
            group = autocmd_group,
            callback = function(event)
                local win_id = vim.fn.bufwinid(event.buf)
                if win_id == nil or win_id == -1 then return end

                local win_config = vim.api.nvim_win_get_config(win_id)

                -- Fix weirdness with things like notify or noice
                if win_config.relative ~= "" then
                    return
                end

                async.void(function(ev)
                    M.update_components(ev)
                end)(event)
            end,
        }

        -- User events are always under "User" ':h events'
        if event_type == "User" and val ~= nil then
            settings.pattern = val
        end

        vim.api.nvim_create_autocmd(event_type, settings)
    end

    vim.api.nvim_create_autocmd("User", {
        pattern = "StatusLineComponentUpdated",
        group = autocmd_group,
        callback = function(event)
            M.show_statusline(event)
        end,
    })
end

return M
