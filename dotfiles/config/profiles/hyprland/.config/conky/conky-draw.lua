-- Cairo background boxes for conky widget
-- Drawn BEFORE text (lua_draw_hook_pre)
-- TUNE: adjust y/h values in boxes[] to match actual text layout on screen
require 'cairo'

local function rrect(cr, x, y, w, h, radius, r, g, b, a)
    cairo_new_path(cr)
    cairo_move_to(cr, x + radius, y)
    cairo_line_to(cr, x + w - radius, y)
    cairo_arc(cr, x + w - radius, y + radius, radius, -math.pi / 2, 0)
    cairo_line_to(cr, x + w, y + h - radius)
    cairo_arc(cr, x + w - radius, y + h - radius, radius, 0, math.pi / 2)
    cairo_line_to(cr, x + radius, y + h)
    cairo_arc(cr, x + radius, y + h - radius, radius, math.pi / 2, math.pi)
    cairo_line_to(cr, x, y + radius)
    cairo_arc(cr, x + radius, y + radius, radius, math.pi, 3 * math.pi / 2)
    cairo_close_path(cr)
    -- fill
    cairo_set_source_rgba(cr, r, g, b, a)
    cairo_fill_preserve(cr)
    -- subtle border (Catppuccin surface1 #494d64)
    cairo_set_source_rgba(cr, 0.286, 0.302, 0.392, 0.55)
    cairo_set_line_width(cr, 1.2)
    cairo_stroke(cr)
end

-- Catppuccin Macchiato base: #24273a = (0.141, 0.153, 0.227)
-- TUNE: x=margin, y=start px, w=box width, h=box height, radius, r, g, b, alpha
local boxes = {
    -- section   x   y    w    h  rad    r      g      b      a
    {"clock",    3,  2,  334, 122,  14, 0.141, 0.153, 0.227, 0.82},
    {"cpu",      3, 130, 334,  74,  10, 0.141, 0.153, 0.227, 0.78},
    {"gpu",      3, 210, 334,  74,  10, 0.141, 0.153, 0.227, 0.78},
    {"ram",      3, 290, 334,  74,  10, 0.141, 0.153, 0.227, 0.78},
    {"swap",     3, 370, 334,  74,  10, 0.141, 0.153, 0.227, 0.78},
    {"ssd",      3, 450, 334,  74,  10, 0.141, 0.153, 0.227, 0.78},
    {"top3",     3, 530, 334,  96,  10, 0.141, 0.153, 0.227, 0.78},
}

function conky_draw_bg(cr)
    if conky_info == nil then return end
    for _, b in ipairs(boxes) do
        rrect(cr, b[2], b[3], b[4], b[5], b[6], b[7], b[8], b[9], b[10])
    end
end
