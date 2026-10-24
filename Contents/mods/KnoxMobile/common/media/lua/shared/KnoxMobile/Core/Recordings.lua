-- Numbers that answer with a recording (0.2.0): 911, the state's information line, 411 directory assistance and the
-- local businesses, churches and offices of Knox County. What you hear changes with the days: open, then closed
-- "until further notice", then a full mailbox or a phone that rings out. A church's tape never changes; nobody went
-- back to change it. The 555-01xx numbers are kept out of the SIM number pool (Core/Sim). Pure Lua 5.1.
local Recordings = {}

Recordings.NINE_ONE_ONE = "911"
Recordings.DIRECTORY = "411"
Recordings.HOTLINE = "(502) 555-0117"

-- kind: food, pharmacy, church, police, school, hardware, gas.
Recordings.BUSINESSES = {
    { town = "Muldraugh", name = "Spiffo's", number = "(502) 555-0147", kind = "food" },
    { town = "Muldraugh", name = "Muldraugh Hardware", number = "(502) 555-0142", kind = "hardware" },
    { town = "Muldraugh", name = "the Muldraugh pharmacy", number = "(502) 555-0158", kind = "pharmacy" },
    { town = "Muldraugh", name = "First Baptist Church of Muldraugh", number = "(502) 555-0163", kind = "church" },
    { town = "Muldraugh", name = "the Meade County Sheriff, Muldraugh office", number = "(502) 555-0171", kind = "police" },
    { town = "West Point", name = "West Point Hardware", number = "(502) 555-0124", kind = "hardware" },
    { town = "West Point", name = "Spiffo's West Point", number = "(502) 555-0131", kind = "food" },
    { town = "West Point", name = "West Point Elementary", number = "(502) 555-0186", kind = "school" },
    { town = "Riverside", name = "the Riverside pharmacy", number = "(606) 555-0112", kind = "pharmacy" },
    { town = "Riverside", name = "Riverside Methodist Church", number = "(606) 555-0127", kind = "church" },
    { town = "Riverside", name = "the Riverside Gas-2-Go", number = "(606) 555-0145", kind = "gas" },
    { town = "Rosewood", name = "the Rosewood Sheriff's station", number = "(606) 555-0119", kind = "police" },
    { town = "Rosewood", name = "Rosewood Elementary", number = "(606) 555-0153", kind = "school" },
    { town = "Rosewood", name = "Rosewood Hardware and Feed", number = "(606) 555-0168", kind = "hardware" },
    { town = "March Ridge", name = "March Ridge Community Church", number = "(606) 555-0134", kind = "church" },
    { town = "March Ridge", name = "the March Ridge Fossoil", number = "(606) 555-0177", kind = "gas" },
}

-- What each kind of place says: normal (days 0-1), closed (2-6). After a week a mailbox is full or nobody answers,
-- except a church: its tape goes on.
local OPEN = {
    food = "Thanks for calling {name} in {town}! / We're open ten to ten, seven days a week. / Leave a message and we'll call you right back.",
    pharmacy = "You've reached {name}. / Our hours are nine to seven. For a refill, leave your name and prescription number after the tone.",
    church = "Thank you for calling {name}. / Sunday service is at ten. / Leave a message and the pastor will call you back.",
    police = "You've reached {name}. / If this is an emergency, hang up and dial nine-one-one. / Otherwise leave a message.",
    school = "You've reached {name}. / School is out for the summer. The office is open Tuesdays and Thursdays.",
    hardware = "{name}. We're open eight to six, closed Sundays. / Leave a message.",
    gas = "{name}. We're open twenty-four hours. / Leave a message for the manager.",
}
local CLOSED = {
    food = "You've reached {name}. / Because of the emergency we are closed until further notice. / Please don't come by. Stay safe.",
    pharmacy = "This is {name}. / We are out of antibiotics and fever reducers. / If you are sick, do not come to the pharmacy. Stay home.",
    church = "This is {name}. / The fellowship hall is open to anyone who needs somewhere to go. / Come to the side door and knock. We'll let you in.",
    police = "You've reached {name}. / Deputies cannot respond to calls that are not emergencies. / Stay inside and keep your doors locked.",
    school = "This is {name}. / The building is being used by the county. / Please do not come to the school. Please.",
    hardware = "{name}. / We're out of plywood, nails and generators. / We're closing early until this is over.",
    gas = "{name}. / No gas until the truck comes. We don't know when the truck comes.",
}

Recordings.NINE = {
    { to = 1, kind = "answer", lines = "Nine-one-one, please hold. / All of our dispatchers are on other calls. / Please stay on the line. Do not hang up." },
    { to = 3, kind = "answer", lines = "You have reached Knox County Emergency Communications. / Because of the number of calls, units cannot be sent to every address. / Stay inside. Lock your doors. Do not go near anyone who is sick." },
    { to = 7, kind = "answer", lines = "This is a recorded message from the Kentucky Division of Emergency Management. / Emergency services in the Knox County area are suspended. / Shelter in place. Listen to the Emergency Broadcast System for instructions." },
}
Recordings.INFO = {
    { to = 2, kind = "answer", lines = "Thank you for calling the Kentucky public information line. / If someone in your home has a fever or has been bitten, keep them in a separate room. / Do not travel. Checkpoints are in place on 31W and the interstate." },
    { to = 10, kind = "answer", lines = "This is the Kentucky public information line. / The Knox County exclusion zone is closed. No one will be allowed to leave. / Do not approach the fence. This message will be updated." },
}

local function fill(text, b) return (text:gsub("{(%a+)}", function(k) return b[k] or k end)) end

function Recordings.business(number)
    for _, b in ipairs(Recordings.BUSINESSES) do if b.number == number then return b end end
    return nil
end

local function byDay(list, day)
    for _, e in ipairs(list) do if day < e.to then return e end end
    return nil
end

-- What answers this number on this day: { kind = answer|voicemail|noAnswer|notInService, lines, name, listings },
-- or nil when the number is not a recording. town: the caller's nearest town (for 411).
function Recordings.call(number, day, town, rng)
    if number == Recordings.NINE_ONE_ONE then
        local e = byDay(Recordings.NINE, day)
        if not e then return { kind = "noAnswer", name = "911" } end
        return { kind = e.kind, lines = e.lines, name = "911" }
    end
    if number == Recordings.HOTLINE then
        local e = byDay(Recordings.INFO, day)
        if not e then return { kind = "notInService" } end
        return { kind = e.kind, lines = e.lines, name = "Kentucky info line" }
    end
    if number == Recordings.DIRECTORY then
        if day >= 7 then
            return { kind = "answer", name = "411", lines = "Directory assistance is not available at this time. / Please try your call again later." }
        end
        local listings = Recordings.listings(town)
        local parts = { "Directory assistance. What city, please?", town .. ". One moment." }
        for _, b in ipairs(listings) do parts[#parts + 1] = b.name .. ": " .. b.number end
        parts[#parts + 1] = "The state information line is " .. Recordings.HOTLINE .. "."
        return { kind = "answer", name = "411", lines = table.concat(parts, " / "), listings = listings }
    end
    local b = Recordings.business(number)
    if not b then return nil end
    if day < 2 then return { kind = "voicemail", lines = fill(OPEN[b.kind], b), name = b.name } end
    if day < 7 or b.kind == "church" then return { kind = "voicemail", lines = fill(CLOSED[b.kind], b), name = b.name } end
    if rng:chance(0.5) then return { kind = "voicemail", lines = "The mailbox you have reached is full.", name = b.name } end
    return { kind = "noAnswer", name = b.name }
end

-- The places 411 reads out for a town (the nearest ones first when the town has none).
function Recordings.listings(town)
    local out = {}
    for _, b in ipairs(Recordings.BUSINESSES) do if b.town == town then out[#out + 1] = b end end
    if #out == 0 then for i = 1, 3 do out[#out + 1] = Recordings.BUSINESSES[i] end end
    return out
end

return Recordings
