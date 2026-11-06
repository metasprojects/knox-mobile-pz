-- Client: PZVR (Workshop 3816830877; VR on top of Project Viewpoint and ZombieBuddy), best effort and built blind:
-- nobody has tested Knox Mobile in VR yet, and the Workshop page asks VR players to report. When PZVR is active the
-- phone defaults to readable on a headset: the large size and big text (unless the small size was picked on purpose).
-- PZVR points VR controllers at the UI as clicks and its stick navigates menus, which the phone already takes
-- (mouse, keys, controller); Viewpoint's first person is already supported (client/KnoxMobile/Viewpoint.lua).
local Vr = { cached = nil }
KnoxMobile.Vr = Vr

-- Is PZVR in the active mods? (B42 lists some ids with a leading backslash.)
function Vr.active()
    if Vr.cached ~= nil then return Vr.cached end
    local found = false
    pcall(function()
        local mods = getActivatedMods()
        for i = 0, mods:size() - 1 do
            local id = tostring(mods:get(i)):gsub("^\\", ""):upper()
            if id == "PZVR" then found = true end
        end
    end)
    Vr.cached = found
    return found
end

return Vr
