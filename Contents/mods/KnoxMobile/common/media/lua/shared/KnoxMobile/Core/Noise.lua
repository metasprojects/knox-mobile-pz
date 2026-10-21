-- Phone audio noise radius and hearing trade-off (spec §9.1). Pure Lua 5.1.
local Noise = {}

Noise.WHISPER = 2
Noise.PULSE_SECONDS = 3

function Noise.radius(audio, settings)
    local multiplier = (settings and settings.noiseMultiplier) or 1
    local route = audio.route
    local volume = audio.volume or 0

    if route == "earbuds" or route == "headphones" or route == "oneEarbud" then
        return 0
    end

    if route == "ear" then
        return Noise.WHISPER * multiplier
    end

    -- speaker and any unknown route
    if volume <= 0 then
        return 0
    end
    return (5 + 20 * volume) * multiplier
end

function Noise.ringRadius(soundMode, volume, inBag, settings)
    if soundMode == "silent" or soundMode == "vibrate" then
        return 0
    end
    local radius = Noise.radius({ route = "speaker", volume = volume }, settings)
    if inBag then
        return radius / 2
    end
    return radius
end

function Noise.hearingPenalty(route, settings)
    if settings and settings.hearingPenalty == false then
        return "none"
    end
    if route == "earbuds" then
        return "mild"
    end
    if route == "headphones" then
        return "strong"
    end
    return "none"
end

function Noise.audioQuality(route)
    if route == "oneEarbud" then
        return 0.6
    end
    return 1
end

function Noise.pulsesFor(seconds)
    local pulses = math.floor(seconds / Noise.PULSE_SECONDS)
    if pulses < 0 then
        pulses = 0
    end
    return pulses
end

return Noise