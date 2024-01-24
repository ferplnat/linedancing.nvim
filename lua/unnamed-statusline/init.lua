local M = {}

local async = require('plenary.async')
local StatusLineComponent = require('unnamed-statusline.statusline')

M.on_events = {}

--- @type StatusLineComponent[]
M.registered_components = {}

--- Registers a given statusline component for event processing to work
--- @param statusline_component StatusLineComponentConfiguration
local register_statusline_component = function(statusline_component)
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

    -- REMOVE
    statusline_component.callback = async.wrap(statusline_component.callback, 1)
end

M.update_statusline = function(event)
    local bufnr = event.buf
    local win_id = vim.fn.bufwinid(bufnr)
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
        local result, result_width = component:render(event)
        table.insert(rendered_components[component.position], component:apply_highlight(result))
        rendered_components_width[component.position] = rendered_components_width[component.position] + result_width
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
    vim.opt_local.statusline = left_side .. left_padding .. center .. right_padding .. right_side
end

M.update_statusline_async = function(event)
end

--- Setup function to configure unnamed-statusline
--- @param conf StatusLineConfiguration Array of statusline components to register
M.setup = function(conf)
    for _, component in pairs(conf.components) do
        register_statusline_component(component)
    end

    local autocmd_group = vim.api.nvim_create_augroup('unnamed-statusline', { clear = true })
    for event_type, val in pairs(M.on_events) do
        print('registering autocmd', event_type)

        local settings = {
            group = autocmd_group,
            callback = function(event)
                M.update_statusline(event)
            end,
        }

        if event_type == "User" and val ~= nil then
            settings.pattern = val
        end

        vim.api.nvim_create_autocmd(event_type, settings)
    end
end

return M
