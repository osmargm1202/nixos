-- Characterize the actual pinned route consumer, not a duplicate formula.
local hook
package.preload['device-info-cache'] = function()
    return {
        get_device_info = function() return { name = 'integrated' } end,
        find_route_info = function(_, route)
            return { direction = route.direction, index = 0, name = 'test-route' }
        end,
    }
end
Log = { open_topic = function() return { info = function() end, debug = function() end } end }
Constraint = function(value) return value end
EventInterest = function(value) return value end
AsyncEventHook = function(value)
    hook = value
    return { register = function() end }
end
Json = { Raw = function(value) return { parse = function() return value end } end }
Pod = { Object = function(value) return value end, Array = function(value) return value end }
Core = { sync = function(callback) callback() end }
Settings = { get_float = function(key)
    return key == 'device.routes.default-sink-volume' and 0.064 or 1.0
end }
dofile(arg[1])
local function apply(direction, saved)
    local param, advanced
    local device = {
        properties = {
            ['device.routes.default-sink-volume'] = arg[2],
            ['device.routes.default-source-volume'] = arg[3],
        },
        set_param = function(_, kind, value)
            assert(kind == 'Route')
            param = value
        end,
    }
    local event = {
        get_subject = function() return device end,
        get_data = function() return { [0] = { direction = direction, props = saved } } end,
    }
    hook.steps.start.execute(event, { advance = function() advanced = true end })
    assert(advanced)
    return param.props
end
for _, direction in ipairs({ 'Output', 'Input' }) do
    local initial = apply(direction, nil)
    assert(initial.channelVolumes[2] == 3.375, 'default raw gain must be3.375')
    assert(math.abs(initial.channelVolumes[2] ^ (1/3) - 1.5) < 0.000001, 'must display150%')
    local manual = apply(direction, { channelVolumes = { 0.125, 0.216 }, mute = true })
    assert(manual.channelVolumes[2] == 0.125 and manual.channelVolumes[3] == 0.216,
        'stored manual channel balance/volume must win over defaults')
    assert(manual.mute == true, 'must preserve a muted route')
end
print('PASS: pinned WirePlumber applies150% only to fresh routes, preserving stored volume/balance/mute')
