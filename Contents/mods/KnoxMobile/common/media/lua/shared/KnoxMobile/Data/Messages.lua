-- English text for notifications and timed-action labels, keyed the way the code builds translation keys:
--   notify[kind][event] -> IGUI_KnoxMobile_<kind>_<event>
--   jobs[kind]          -> IGUI_KnoxMobile_Job_<kind>
--   words[group][code]  -> IGUI_KnoxMobile_Word_<group>_<code>  (Util.word: codes the server sends, worded here)
-- tools/gen writes these (and every T("IGUI_KnoxMobile_...", "...") string in the code) to Translate/EN/IG_UI.json.
-- No bare percent signs: the game's Translator only accepts %1, %2... placeholders.
local M = {}

M.notify = {
    battery = {
        low15 = "Battery low (15 percent left)", low5 = "Battery critical (5 percent left)",
        shutdown = "Phone died: battery empty", dead = "The battery is dead. Charge it first.",
    },
    charge = {
        full = "Fully charged", sourceEmpty = "The charger ran out of power", started = "Charging from %1",
        cannot = "Can't charge: %1", leftCharging = "Left it charging here",
    },
    wet = {
        damp = "Your phone is damp", waterDamaged = "Your phone is water-damaged",
        died = "Your phone died from water damage", dried = "Your phone has dried out",
        shortCircuit = "It sparks and won't turn on",
    },
    damage = {
        scratched = "Your phone got scratched", cracked = "Your phone's screen cracked",
        broken = "Your phone broke", protectorCracked = "The screen protector cracked. Screen saved.",
    },
    repair = { fixed = "Repair worked", worse = "The repair made it worse", failed = "The repair didn't work" },
    rice = {
        notYet = "Not dry yet: leave it in rice for a full day", dried = "Dried out in the rice!",
        tooFarGone = "Too far gone for rice", noEffect = "The rice did nothing",
    },
    crack = { ok = "PIN cracked: the phone is unlocked", failed = "Couldn't crack it. Locked out for an hour." },
    repeater = {
        placedPowered = "Repeater R%1 placed and powered", placedUnpowered = "Repeater R%1 placed: it needs power",
        batteryOn = "Car battery attached to repeater R%1", maintained = "Repeater R%1 serviced",
    },
    -- Cell sites brought back with a generator (server/KnoxMobile/SiteRestore.lua); %1 is the site code.
    site = {
        online = "Cell site %1 is back on the air", connectedOff = "Generator hooked up to %1. Start it to bring the site up.",
        noGenerator = "No generator at %1's hookup point", tooFar = "Too far from cell site %1",
        notAllowed = "Restoring cell sites is off on this server", disconnected = "Generator unhooked from %1",
    },
    sim = { inserted = "SIM inserted: %1" },
    -- A found phone taken home (Actions takeHome, server TextBack); %1 is its owner's first name.
    returned = { home = "%1's phone is home" },
    audio = { noGear = "You have no %1 that fit this phone" },
    manual = { read = "You know how this kind of phone works now" },
    bank = { plugged = "Power bank charging", unplugged = "Power bank unplugged", full = "Power bank full" },
    wipe = { done = "Phone wiped. It's yours now." },
    callFailed = {
        noService = "No service", circuitsBusy = "All circuits are busy. Try again later.",
        noPhone = "This phone isn't in your inventory", noSim = "Insert a SIM card to call", phoneOff = "The phone is off",
        unreachable = "The number you dialed can't be reached", busy = "Line busy",
        notInService = "The number you have dialed is not in service.",
        self = "You can't call yourself", noVoice = "Calls are turned off on this server",
        noPower = "The payphone is dead. No power.",
    },
}

-- Words for codes the server and the phone state use (Util.word(group, code)).
M.words = {
    -- "Charging from %1", "Unplug from %1"
    Source = { wall = "the wall outlet", car = "the car", carBatteryClip = "the car battery", powerBank = "the power bank",
        solar = "the solar charger", aa = "the AA charger", crank = "the hand crank" },
    -- "Can't charge: %1" (Core/Charging.choose reason codes)
    NoCharge = { noFit = "no charger or cable fits it", needAdapter = "its cable needs a USB wall adapter or another USB power source",
        needCable = "you need the phone's own cable for that", wall = "there's no power here", car = "you need a car with power",
        carBatteryClip = "you need a charged car battery", powerBank = "the power bank is empty",
        solar = "the solar charger needs sunlight", aa = "you need AA batteries", crank = "crank it by hand instead",
        wallOnly = "only a wall charger can stay plugged in here" },
    -- "Unplugged: %1" (Core/Charging.stillConnected reason codes)
    Unplug = { walkedAway = "you walked away from the outlet", powerOut = "the power went out", wall = "the power went out",
        car = "you left the car", carBatteryClip = "the car battery is dead", powerBank = "the power bank is empty",
        solar = "not enough sunlight", aa = "the AA batteries are dead", crank = "you stopped cranking" },
    -- "You have no %1 that fit this phone" (audio routes)
    Gear = { earbuds = "earbuds", oneEarbud = "earbuds", headphones = "headphones", speaker = "speaker" },
    -- Phone tooltip: "in a %1", conditions and wetness.
    Case = { Slim = "slim case", Rugged = "rugged case", Waterproof = "waterproof case", Wallet = "wallet case",
        Battery = "battery case", BeltHolster = "belt holster" },
    Condition = { scratched = "scratched", cracked = "cracked screen", broken = "broken" },
    Wet = { damp = "damp", waterDamaged = "water-damaged" },
    -- Settings values.
    Sound = { ring = "Ring", vibrate = "Vibrate", silent = "Silent" },
    Route = { speaker = "Speaker", earbuds = "Earbuds", oneEarbud = "One earbud", headphones = "Headphones" },
    Tone = { classic = "Classic", chiptune = "Chiptune", custom = "My tune" },
    Size = { S = "Small", M = "Medium", L = "Large" },
    Side = { right = "Right", left = "Left" },
    Switch = { on = "On", off = "Off" },
    -- "Not sent: %1" (Messaging.sendText and Core/MessageQueue reasons)
    TextFail = { noService = "no service", phoneOff = "the phone is off", locked = "the phone is locked",
        unreachable = "they have no service", notPager = "that number isn't a pager",
        notNumeric = "a pager shows numbers only", tooLong = "a page holds 20 digits at most", empty = "nothing to send" },
    -- Answering machine tapes (Core/Machine): %1 the resident's first name, %2 who called, %3 the nearest town.
    -- June 30 to July 7 1993, oldest first; the zone's phone lines went down on July 7-8.
    Machine = {
        dinner = "Hi %1, it's %2. Just checking you're still coming Sunday. Bring the potato salad. Call me back.",
        dentist = "This message is for %1. This is %2 at the dentist's office in %3, confirming your cleaning Tuesday at ten.",
        dish = "Hey %1, it's %2. You left your casserole dish at the church picnic. Swing by whenever.",
        car = "%1, it's %2 down at the garage. Your car's ready. It was the alternator. We close at five.",
        birthday = "Happy birthday, %1! It's %2. Love you. Call me when you get in.",
        lake = "Hey %1, it's %2. Are we still on for the lake on the Fourth? I'll bring the cooler.",
        bill = "Hello, this is %2 with Knox Telephones, calling for %1 about your account. Please call us back.",
        news = "%1, it's %2. Are you watching WBLN? Call me as soon as you get this.",
        fireworks = "It's %2. They called off the fireworks in %3. Something about the flu. You hear anything?",
        stayHome = "%1, honey, it's %2. Don't go in to work tomorrow. Please. Call me.",
        school = "This is %2 at the %3 school office. All summer programs are cancelled until further notice.",
        bridge = "%1, pick up. Pick up. It's %2. They closed the bridge. Nobody's getting out. Call me.",
        busy = "It's %2. I keep getting a busy signal. If you get this, don't open the door for anybody.",
        soldiers = "%1? It's %2. There are soldiers on Main Street. Where are you? Please call.",
        county = "This is Knox County Emergency Management. Stay indoors. Do not travel. Wait for further instructions.",
        scratched = "Hey %1, it's %2. Some guy grabbed me outside the store. It's just a scratch. Call me, okay?",
    },
    -- Photos app captions (Core/Photos): %1 someone in the owner's life, %2 the date ("June 30"). The last ones
    -- were taken by accident or in the dark, so they have no date.
    Photo = {
        birthday = "%1's birthday, %2", cookout = "Cookout in the backyard, %2", dog = "The dog asleep on the couch, %2",
        lake = "%1 with a catfish at the lake, %2", car = "The new truck in the driveway, %2",
        spiffos = "Me and %1 at Spiffo's, %2", porch = "Sunset from the porch, %2", baby = "%1 holding the baby, %2",
        softball = "Softball game, %2. We lost", graduation = "%1 in a cap and gown, %2",
        convoy = "[blurry] Army trucks on 31W, %2", grocery = "The line at the grocery store, %2",
        roadblock = "Roadblock at the bridge, %2", smoke = "Smoke over town, %2",
        boarded = "Boarded-up windows across the street, %2",
        hallway = "[dark, blurry] something in the hallway", window = "[dark] a face at the back window",
        yard = "[blurry] someone standing in the yard. Not moving", door = "[dark] the bedroom door, scratched from the outside",
        bite = "[close-up] a bite on a forearm", pocket = "[black] taken in a pocket by accident",
        stairs = "[dark] the basement stairs. Something at the bottom",
        crowd = "[blurry] a crowd coming up the road toward the house",
        carwindow = "[blurry] hands on the car window", kitchen = "[dark] the kitchen. The back door is open",
    },
    -- The machine's voice: "Message 2. Tuesday, 4:12 PM."
    Weekday = { Sun = "Sunday", Mon = "Monday", Tue = "Tuesday", Wed = "Wednesday", Thu = "Thursday", Fri = "Friday",
        Sat = "Saturday" },
}

M.jobs = {
    powerOn = "Turning on", powerOff = "Turning off", insertSim = "Inserting SIM", ejectSim = "Removing SIM",
    openBox = "Unboxing", readManual = "Reading manual", plug = "Plugging in", unplug = "Unplugging",
    wrap = "Wrapping", unwrap = "Unwrapping", fitCase = "Fitting case", removeCase = "Removing case",
    fitProtector = "Fitting protector", repair = "Repairing", riceIn = "Burying in rice", riceOut = "Taking out of rice",
    crank = "Cranking", placeRepeater = "Placing repeater", scrap = "Scrapping", crackPin = "Cracking PIN",
    swapBattery = "Swapping battery", plugBank = "Plugging in", unplugBank = "Unplugging", wipe = "Wiping phone",
    leaveCharging = "Plugging in",
}

return M
