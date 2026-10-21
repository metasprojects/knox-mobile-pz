-- Name pools for generated people (1990s Kentucky flavour). Sample set for Round 1; Round 3 grows it.
return {
    female = {
        "Amanda", "Angela", "April", "Brandy", "Carla", "Crystal", "Dana", "Debbie", "Donna", "Heather",
        "Jennifer", "Jessica", "Kelly", "Kimberly", "Lisa", "Melissa", "Michelle", "Misty", "Nicole", "Pam",
        "Rhonda", "Sandra", "Shannon", "Sherry", "Stacy", "Tammy", "Tina", "Tonya", "Wanda", "Wendy",
    },
    male = {
        "Billy", "Bobby", "Brandon", "Brian", "Chad", "Chris", "Dale", "Darrell", "Dewayne", "Doug",
        "Eddie", "Gary", "Greg", "Jason", "Jeff", "Jimmy", "Joey", "Keith", "Larry", "Mike",
        "Randy", "Rick", "Ronnie", "Scott", "Shane", "Steve", "Terry", "Todd", "Travis", "Wayne",
    },
    surnames = {
        "Adkins", "Baker", "Bowling", "Burkhart", "Caudill", "Collins", "Combs", "Cornett", "Day", "Fields",
        "Gibson", "Hall", "Hensley", "Howard", "Jenkins", "Johnson", "Lewis", "Mullins", "Napier", "Osborne",
        "Pennington", "Prater", "Ritchie", "Sexton", "Slone", "Smith", "Stamper", "Turner", "Webb", "Wilson",
    },
    -- Pet names people save family under in their phones. Texts about a parent always say "Mom" or "Dad"
    -- (Story.familyPlan), the way parents talk to their kids.
    mom = { "Mom", "Mama", "Mom", "Mother", "Mommy" },
    dad = { "Dad", "Daddy", "Dad", "Pop", "Pops" },
    -- Hometowns: towns on the Build 42 map (vanilla Translate/EN/<Town>, KY.json), plus Louisville.
    towns = { "Muldraugh", "West Point", "Riverside", "Rosewood", "March Ridge", "Louisville", "Ekron", "Irvington",
        "Brandenburg", "Echo Creek", "Valley Station", "Fallas Lake" },
}
