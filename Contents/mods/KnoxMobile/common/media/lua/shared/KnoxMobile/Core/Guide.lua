-- The welcome guide (after 0.3.0): a few texts from KNOX MOBILE over a new character's first days, each one thing
-- worth knowing. Sent with the character's own SIM (Messaging.setupOwnSim); sandbox Stories > Welcome texts.
-- Pure Lua 5.1; the words go through Core/Lang. after: world minutes after the SIM is set up.
local Guide = {}

Guide.TIPS = {
    { after = 5, text = "Welcome to Knox Mobile. Your phone works while the towers have power. "
        .. "Indoors costs a bar: go up a floor or step outside." },
    { after = 120, text = "TIP: Keep it charged. A wall outlet with power, a car, a hand crank or a power bank all work. "
        .. "Right-click the phone for everything it can do." },
    { after = 1440, text = "TIP: Texts wait for a phone that's off or out of range. "
        .. "Group chats, Find my crew and SOS are in your apps." },
    { after = 2880, text = "TIP: When a tower dies, a running generator at its cell site brings it back. "
        .. "Your phone's manual lists the sites." },
    { after = 4320, text = "TIP: A dropped phone can crack and a wet one can die. A case helps. "
        .. "Wet? Bag of rice, or open it up with a screwdriver." },
}

return Guide
