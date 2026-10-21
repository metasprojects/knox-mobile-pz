-- The car phone (1993 hardware): the handset of a mounted Car Phone Kit. Not in Phones/Index.lua: it never spawns,
-- never comes in a box and is never a starting phone; Game/Phones maps the KnoxMobile.CarPhone item to it.
-- A roof antenna and a 3-watt transceiver: the strongest antenna Knox Mobile allows. It looks like the DoorStop 8000.
return {
    id = "CarPhone", name = "Motormouth Roadster Car Phone", brand = "Motormouth", year = 1993,
    form = "Car phone", family = "SegmentLCD", connector = "Pin",
    removableBattery = false, camera = "none", extras = {},
    toughness = 0.9, waterResistant = false, antenna = 3, weight = 0.5,
    colors = { "Charcoal", "Putty" }, caseSize = "XL", look = "DoorStop8000",
}
