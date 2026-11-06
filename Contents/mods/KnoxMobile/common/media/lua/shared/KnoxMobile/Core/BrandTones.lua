-- Brand ringtones (after 0.3.0): each maker's own signature tune, in the Composer's notes (Core/Composer), so it
-- plays through the same note sounds as a tune you write. All original. Settings > Tone > Brand. Pure Lua 5.1.
local BrandTones = {}

BrandTones.TUNES = {
    Sisu = "8e2 8g2 8c3 8g2 4e3 8d3 8c3 4g2 8- 8e2 8g2 8c3 8e3 2d3",
    Motormouth = "16a2 16a2 8e3 16a2 16a2 8f#3 16a2 16a2 8g3 8f#3 4e3 8- 16b2 16c#3 4d3",
    Pear = "8c3 8e3 8g3 8e3 8a3 8g3 4e3 8- 8d3 8f3 8a3 8f3 4c3",
    Bramble = "16g2 16b2 16d3 16g3 8- 16g2 16b2 16d3 16g3 8- 16f#3 16e3 16d3 16b2 4g2",
    Chirp = "32c3 32- 32c3 32- 16g3 16- 32c3 32- 32c3 32- 16g3 16- 8e3 8c3 4g2",
    Daebak = "8d3 16d3 16e3 8f#3 8a3 8b3 8a3 8f#3 8d3 4e3 8- 8a2 8d3 2f#3",
    ["Golden Years"] = "4c2 4e2 4g2 2c3 4g2 4e2 2c2",
    Kaiju = "8e1 8e1 8g1 8e1 8a1 8g1 8e1 8d1 4e1 8- 8b1 8a1 8g1 4e1",
    Orbita = "4a2 8- 8e3 4a3 8- 8e3 4g3 8f3 8e3 2d3",
    TracPhone = "16c3 16c3 16c3 8- 16d3 16d3 16d3 8- 8e3 8d3 8c3 4g2",
}

-- The model's tune: its brand's, or nil (a brand with none, or an era with no tunes at all: the 1993 segment LCDs).
function BrandTones.forModel(model)
    if not model or model.family == "SegmentLCD" then return nil end
    return BrandTones.TUNES[model.brand]
end

return BrandTones
