# Knox Mobile: Phones, Calls & Camera for Project Zomboid (Build 42, Viewpoint, A-Life)

![Knox Mobile: STILL ONE BAR.](media/key-art.png)

**Knox Mobile** is a phone mod for Project Zomboid **Build 42 (42.21+)**, single player and multiplayer, made for
first person with Project Viewpoint. Seven phones from 1993 to 2013, calls and texts between players, a real camera,
and a cell network that dies with the grid.

- **Steam Workshop:** https://steamcommunity.com/sharedfiles/filedetails/?id=3818422092 (Mod ID `KnoxMobile`)
- **Everything for first person in one click:** https://steamcommunity.com/sharedfiles/filedetails/?id=3823860296
- **Version:** 0.2.1, early access (released 2026-10-24): lighter on the game, and a sandbox switch to turn phone PINs off.
- **Made by:** Meta

Players should install it from the Steam Workshop. This repository holds the mod exactly as it ships there.

## Features

![A first-person selfie and a found phone's photo](media/first-person-pair.png)

- **Seven phones, 1993 to 2013, in 19 colors:** Motormouth DoorStop 8000 (1993), Sisu 3301 (2000), Sisu 6606
  "Soapbar" (2003), Sisu 5320 XpressoMusic (2009), Bramble Bend 2580 (2009), PearPhone 4 (2010) and Daebak
  Supernova IV (2013). A "1993 only" sandbox mode keeps the world to the brick phone.
- **Your own number.** Call and text other players, plus group chats. Texts wait until they can be delivered.
- **Family.** Your SIM holds your family's numbers, and they text you through the first weeks. Call them: sometimes
  they pick up.
- **A network that dies with the grid.** 18 cell sites on the map fail after the collapse, rural ones first. A
  generator at a dead site brings it back, and a craftable repeater gives your crew service. Higher floors get more
  bars.
- **Power.** Batteries drain and wear. Each phone has its own plug, with wall, car, solar, hand-crank, AA and
  power-bank chargers.
- **Danger.** Ringing and the camera flash draw zombies. Phones can be dropped, rained on, cracked and repaired
  (rice works). The Alarm app makes a zombie lure.
- **Found phones belong to someone:** their PIN, calls, texts, notes and, on newer phones, their last photos.
  The PIN is often on their body: the birthday on their ID card, or digits on a scrap of paper in their wallet.
- **Nearly 1,000 texts, voicemails and notes** written for Knox County in July 1993, with 30 recurring people whose
  stories cross between phones. Put your SIM in a dead person's phone and text their family back; some answer.
- **The world rings back:** call 911, 411 and the town's businesses as the county falls; phones ring in zombies'
  pockets; the first week's jammed network; answering machines; a ringtone composer.
- **Project A-Life compatible:** A-Life NPCs carry phones of their own, with their faction's live group chat, raid
  warnings and their crew on the Map; a robbed phone shows in Find my crew and comes back as itself.
- **Apps:** Messages, Phone, Alarm, Snake, Calculator, Map, Photos, Camera, and a Flashlight on the smartphones.
- **First person with Project Viewpoint.** The phone stays in your hand while you walk and look around.
- **With ZombieBuddy:** the phone in your hand shows its live screen, and the Camera takes real photos of exactly
  what you see. Older phones take older pictures (the 2003 Soapbar shoots 160x120), and the PearPhone 4 and
  Supernova IV take selfies.
- **1993 extras:** payphones, a numeric pager, a car phone kit, repair magazines and a Cell Tower Technician
  occupation.
- **Multiplayer:** the server has the final say. Admin broadcasts, classifieds, "find my crew" and SOS.
- **Sandbox:** 51 options on six pages.

| | |
|---|---|
| ![A dead owner's photos](media/found-photos.png) | ![Front camera selfie](media/selfie.png) |
| ![Night flash](media/night-flash.png) | ![Camera viewfinder](media/camera-viewfinder.png) |

### Shot on the in-game camera

| | | |
|---|---|---|
| ![Rain and flash](media/photo-01-rain-flash-zombie.jpg) | ![Horde in the fog](media/photo-02-horde-fog-31W.jpg) | ![Selfie with a horde](media/photo-03-selfie-horde.jpg) |

<img src="media/lineup.gif" alt="The phone lineup" width="240">

## Requirements and compatibility

- Project Zomboid Build 42.21 or later.
- **Calls between players need voice chat set to Push to talk** (Options, Audio), and voice chat on for servers.
- Optional: [Project Viewpoint](https://steamcommunity.com/sharedfiles/filedetails/?id=3809306528) for first and
  third person.
- Optional: [ZombieBuddy](https://steamcommunity.com/sharedfiles/filedetails/?id=3619862853) for the live screen and
  the camera. Install it the way its page explains, then allow Knox Mobile's Java part when it asks. Without it,
  everything else works.
- Optional: [Project A-Life](https://steamcommunity.com/sharedfiles/filedetails/?id=3803984183) for NPC phones and
  faction chatter. Without it nothing changes.
- Adds its own items and doesn't replace vanilla files.
- Press **0** to open the phone (rebind under Options > Mods). Right-click a phone for everything else.

## What's in this repository

```
Contents/mods/KnoxMobile/
  42/         mod.info, icon, poster, and the Build 42 parts (items, models, textures, sounds, the Java part)
  common/     Lua: shared game logic, server (state, messaging, photo store), client (phone UI, apps, camera)
preview.png   the Workshop thumbnail
media/        screenshots for this page
```

Under the hood: client/server Lua for Build 42's networked multiplayer, a small Java part loaded through ZombieBuddy
for the live screen and the camera, scripted 3D models and textures, and 51 sandbox options. The build tools and
test suite are kept separately.

## Bugs and feedback

Please use the Workshop page's comments or Discussions tab, and include your `console.txt` (in your Zomboid folder).

## License

Copyright (c) 2026 Meta. All rights reserved. The mod is free to play from the Steam Workshop. Please don't
re-upload it or reuse its code or art without permission.
