--- @alias ComponentPosition
---| "left"
---| "center"
---| "right"

--- @class StatusLineComponentConfiguration
--- @field public name string The name of the component; trying not to take dependencies on this other than logging.
--- @field public callback function(event: any): string The callback to be executed when updating the statusline component.
--- @field public highlight string Name of highlight to apply to rendered component.
--- @field public event string[] | nil Name of the event to be triggered on.
--- @field public user_event string[] | nil Name of any user events to trigger on.
--- @field public position ComponentPosition Positioning for the rendered component.
--- @field public eval boolean Whether or not to evaluate the string as a statusline string. Useful when using native string replacements.

--- @class StatusLineConfiguration Configuration for the statusline
--- @field components StatusLineComponentConfiguration[] Array of components to render.

--- @class StatusLineComponent: StatusLineComponentConfiguration
--- @field public new function(component: StatusLineComponent): StatusLineComponent Component constructor
--- @field public render function(self: self, event: any, buf: int?): StatusLineComponent The last value that a render callback produced. Do not set.
--- @field event string[] Override event to always be a table.
--- @field user_event string[] Override user_event to always be a table.
--- @field private last_value string The last value that a render callback produced. Do not set.
local StatusLineComponent = {
    event = { "VimEnter" }, -- Needed to render the statusline as soon as vim opens.
    last_value = '',
}

--- Create StatusLineComponent object from configuration
--- @param component StatusLineComponentConfiguration
--- @return StatusLineComponent
function StatusLineComponent:new(component)
    if component.event ~= nil then
        vim.list_extend(component.event, self.event)
    end

    if component.user_event ~= nil then
        vim.list_extend(component.user_event, self.user_event)
    end

    return vim.tbl_deep_extend("force", self, component)
end

--- Render the statusline component into string.
--- @param event any
--- @return string StatusLineComponentString String representing the statusline component
--- @return integer StatusLineComponentWidth Integer representing the width of the component after any expression evaluations.
function StatusLineComponent:render(event)
    local bufnr = event.buf
    local win_id = vim.fn.bufwinid(bufnr)
    local eval_string
    local compare_event = self.event
    local incoming_event = event.event

    if not win_id then
        return '', 0
    end

    if event.event == "User" and self.user_event then
        compare_event = self.user_event
        incoming_event = event.match
    end

    if vim.tbl_contains(compare_event, incoming_event) then
        self.last_value = self.callback(event) or ''
        eval_string = vim.api.nvim_eval_statusline(self.last_value, { winid = win_id })

        if self.eval then
            self.last_value = eval_string.str
        end
    end

    if eval_string == nil then
        eval_string = {
            width = vim.api.nvim_eval_statusline(self.last_value, { winid = win_id }).width
        }
    end

    return self.last_value, eval_string.width
end

--- Return string wrapped in highlight expression
--- @param value string? Optional: highlight custom string with object highlight setting
---@return string
function StatusLineComponent:apply_highlight(value)
    local str = value or self.last_value
    if self.highlight == '' then
        return str
    end

    return '%#' .. self.highlight .. '#' .. str .. '%#' .. 'StatusLineNormal' .. '#'
end

return StatusLineComponent
