-- Jobs for generated people, and which vanilla zombie outfits imply which job (spec §5.1).
-- Each job names its workplace and a work contact who texts them (nil: nobody from work texts). Sample set for Round 1.
-- `place` reads mid-sentence ("Can you cover Saturday at the diner?"), so templates never start with {jobPlace}.
return {
    byOutfit = {
        Police = "police", PoliceState = "police", PoliceRiot = "police", Sheriff = "police",
        Nurse = "nurse", Doctor = "doctor", AmbulanceDriver = "paramedic",
        Fireman = "firefighter", FiremanFullSuit = "firefighter",
        ConstructionWorker = "construction", Foreman = "construction", Mechanic = "mechanic",
        Chef = "cook", Cook_Generic = "cook", Waiter_Diner = "waiter", Cashier = "cashier",
        Teacher = "teacher", OfficeWorker = "office", OfficeWorkerSkirt = "office", Farmer = "farmer",
        Postal = "postal", Security = "security", Army = "soldier", ArmyCamoGreen = "soldier",
    },
    list = {
        police = { title = "police officer", place = "the station", contact = "Sgt. {surnameA}", group = "Dispatch" },
        nurse = { title = "nurse", place = "the hospital", contact = "Charge Nurse {firstA}", group = "3rd Floor Nurses" },
        doctor = { title = "doctor", place = "the hospital", contact = "Dr. {surnameA}", group = "ER Attendings" },
        paramedic = { title = "paramedic", place = "the ambulance bay", contact = "{firstA} (EMS partner)", group = "EMS Crew" },
        firefighter = { title = "firefighter", place = "the firehouse", contact = "Capt. {surnameA}", group = "Station 2" },
        construction = { title = "construction worker", place = "the site", contact = "{firstA} (foreman)", group = "Site Crew" },
        mechanic = { title = "mechanic", place = "the shop", contact = "{firstA} (shop)", group = nil },
        cook = { title = "cook", place = "the diner", contact = "{firstA} (manager)", group = nil },
        waiter = { title = "waiter", place = "the diner", contact = "{firstA} (manager)", group = nil },
        cashier = { title = "cashier", place = "the store", contact = "{firstA} (shift lead)", group = nil },
        -- July: the schools are out, so a teacher works summer school.
        teacher = { title = "teacher", place = "summer school", contact = "Principal {surnameA}", group = "Staff" },
        office = { title = "office worker", place = "the office", contact = "{firstA} (boss)", group = "Team" },
        -- Farmers have no boss to text them.
        farmer = { title = "farmer", place = "the farm", contact = nil, group = nil },
        postal = { title = "mail carrier", place = "the post office", contact = "{firstA} (route lead)", group = nil },
        security = { title = "security guard", place = "the plant", contact = "{firstA} (night shift)", group = nil },
        -- March Ridge houses Fort Knox's soldiers; there are no checkpoints before July 6.
        soldier = { title = "soldier", place = "the base", contact = "Sgt. {surnameA}", group = "Squad" },
        unemployed = { title = "between jobs", place = "home", contact = nil, group = nil },
    },
    civilian = { "cashier", "office", "mechanic", "cook", "teacher", "construction", "unemployed", "farmer" },
    -- Job groups a template can ask for with `jobs = "<group>"` (Story/Templates.lua).
    groups = {
        -- Called in, never sent home, when things go wrong.
        emergency = { "police", "nurse", "doctor", "paramedic", "firefighter", "soldier" },
        -- Work in shifts someone can cover.
        shifts = { "police", "nurse", "doctor", "paramedic", "firefighter", "construction", "mechanic", "cook", "waiter",
            "cashier", "postal", "security" },
        -- Workplaces that close or cut hours.
        business = { "construction", "mechanic", "cook", "waiter", "cashier", "teacher", "office", "postal", "security" },
        -- Workplaces that count stock.
        retail = { "mechanic", "cook", "waiter", "cashier" },
    },
}
