-- Car phones (1993 hardware). Pure Lua 5.1.
-- B42 vehicle parts come from each vehicle script's part templates (127 vanilla vehicle scripts each list
-- `template = Radio`), so a new part would mean overriding every vehicle script. Instead the kit is "mounted":
-- the car's ModData keeps the car phone's record { token, number, state, holder }, and while a player sits in that
-- car the server puts the handset (a phone item) in their hands; leaving the car puts its state back in the car.
local CarPhone = {}

CarPhone.ITEM = "KnoxMobile.CarPhone"
CarPhone.KIT = "KnoxMobile.CarPhoneKit"
CarPhone.KEY = "KnoxMobileCarPhone"   -- vehicle ModData (and the kit's, once taken out)
-- Car battery uses per game minute while the phone is on and the engine off: about three and a half days of standby
-- on a full battery (a car phone drew well under an amp waiting for calls).
CarPhone.STANDBY_DRAIN = 0.0002

-- May `key` take the handset? Yes when nobody holds it, they hold it already, or the holder isn't in the car.
function CarPhone.mayHold(record, key, holderSeated)
    return record.holder == nil or record.holder == key or not holderSeated
end

-- The handset runs off the car: full while the car has a live battery, dead without one. Returns the handset's
-- charge and the car battery's uses after `minutes` (drained only while the phone is on and the engine off).
function CarPhone.power(liveBattery, engineRunning, phoneOn, batteryUses, minutes)
    batteryUses = batteryUses or 0
    if not liveBattery or batteryUses <= 0 then return 0, batteryUses end
    if phoneOn and not engineRunning and minutes > 0 then
        batteryUses = math.max(0, batteryUses - CarPhone.STANDBY_DRAIN * minutes)
    end
    return 100, batteryUses
end

return CarPhone
