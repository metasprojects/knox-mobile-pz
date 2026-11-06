-- 0.3.0: music on the music phones, from the B42 music mods. True Moozic (and the packs and mods built the True Music
-- way) list each song in the global GlobalMusic: GlobalMusic[<cassette or record item type>] = the player it fits,
-- and the song's sound has the same name as the item. Knox copies a song you carry onto a music phone (the Sisu 5320
-- XpressoMusic, the PearPhone 4 and PearPad, the Supernova IV) and plays it from there: with earbuds or headphones
-- only you hear it; on the speaker, zombies and people nearby do. Without a music mod there is no Music app.
-- Pure Lua 5.1: client/KnoxMobile/MusicPlayer.lua plays, server/KnoxMobile/Music.lua copies and relays.
local Music = {}

-- How many songs each music phone holds.
Music.FAMILIES = { Stylus = 60, ModernPear = 200, ModernAndroid = 200 }
Music.KEEPALIVE_MS = 60000 -- a playing phone tells the server it still plays this often
Music.EXPIRE_MS = 90000    -- and the server forgets it after this long without a word
Music.HEAR = 25            -- squares: other players this close hear a speaker

local function registry() return type(GlobalMusic) == "table" and GlobalMusic or nil end

-- Is a music mod running (anything in GlobalMusic)?
function Music.available()
    local g = registry()
    if not g then return false end
    -- (The game's Lua has no next(); counting stops at the first song.)
    local n = 0
    for _ in pairs(g) do
        n = n + 1
        if n > 0 then return true end
    end
    return false
end

function Music.isTrack(itemType)
    local g = registry()
    return g ~= nil and type(itemType) == "string" and g[itemType] ~= nil
end

function Music.capacity(model) return model and Music.FAMILIES[model.family] or nil end

-- "CassetteMainTheme" -> "Main Theme": a name when the game can't give one.
function Music.prettyName(itemType)
    local s = tostring(itemType or ""):gsub("^Cassette", ""):gsub("^Vinyl", ""):gsub("^CD", "")
    s = s:gsub("(%l)(%u)", "%1 %2"):gsub("_", " ")
    return s ~= "" and s or tostring(itemType)
end

-- Adds a song to a phone's music. Returns "added", "already" or "full".
function Music.add(state, model, track, name)
    local cap = Music.capacity(model)
    if not cap then return "full" end
    state.contents.music = state.contents.music or {}
    for _, s in ipairs(state.contents.music) do if s.track == track then return "already" end end
    if #state.contents.music >= cap then return "full" end
    state.contents.music[#state.contents.music + 1] = { track = track, name = name or Music.prettyName(track) }
    return "added"
end

-- The next index going `dir` (1 or -1) through n songs, wrapping round.
function Music.step(i, dir, n)
    if n <= 0 then return nil end
    local j = (i or 0) + (dir or 1)
    if j < 1 then j = n elseif j > n then j = 1 end
    return j
end

-- A dead owner's songs: n of the music mods' songs, picked by rng, in a stable order. Names come from `nameOf`.
function Music.found(rng, n, nameOf)
    local g = registry()
    if not g then return {} end
    local all = {}
    for track in pairs(g) do all[#all + 1] = track end
    table.sort(all)
    local out, used = {}, {}
    for _ = 1, math.min(n, #all) do
        local track = all[rng:int(1, #all)]
        for _ = 1, 8 do
            if not used[track] then break end
            track = all[rng:int(1, #all)]
        end
        if not used[track] then
            used[track] = true
            out[#out + 1] = { track = track, name = nameOf and nameOf(track) or Music.prettyName(track) }
        end
    end
    return out
end

return Music
