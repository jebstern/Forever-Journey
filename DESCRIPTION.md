# Forever Journey

**A personal adventure journal for World of Warcraft: Forever.** It records where your
character has been, what you have accomplished and suggests what you could do next, all in
one window. It is not a game database. Questie and the Dungeon Journal already are. This is
the story of *your* character.

Open it with `/journey`, the minimap button or a keybinding.

## What it records

From the moment you install it, Forever Journey quietly keeps track of:

* **Levels and XP**: time per level, XP per session, where the XP came from.
* **Zones**: first visits, time spent, areas discovered, flight paths learned, map exploration.
* **Quests**: completed per level and per zone, and which zone you handed them in.
* **Deaths**: where, when, to what, your longest deathless streaks and resurrections.
* **Dungeons and raids**: runs started and finished, time inside, boss kills and first kills,
  your fastest clear of each dungeon.
* **Gold**: earned and spent, by source and purpose, over time.
* **Professions**: skill-ups and caps, your first ride, hearthstone homes over time.
* **Companions**: who you grouped with, how often and for how long.
* **Little things**: emotes, hugs, jumps, distance travelled, camping, sitting by the fire.

Lifetime numbers such as quests completed and `/played` come from the game itself and include
time before you installed the addon. Everything else is "since recording began".

## Pages

* **Dashboard**: level and XP, `/played`, headline numbers, recent chapters, this session,
  professions.
* **Journey**: a timeline of milestones grouped by level. Levels, first visits, dungeons, boss
  kills, professions, flight paths, notable loot, deaths and a "you are here" marker.
* **World**: continents and zones with visited state, time spent, quests, deaths, exploration
  percentage, known flight paths and the places you discovered.
* **Statistics**: charts. Level over time played, time per level, deaths, quests and kills per
  level, XP per session, how and where you spend your time, when you play (hour of day and
  weekday), gold over sessions, XP sources, emotes, camping and personal records.
* **Almanac**: every number in one place. Character and time, deaths, combat, quests, travel and
  exploration, dungeons and raids, economy, professions, consumables, social and rest.
* **Next**: gentle suggestions. Quests in your log by zone, dungeons for your level you have not
  finished, zones you have not visited, half-explored zones, missing flight paths, profession caps.
* **Wrapped**: a "Forever Wrapped" summary of the whole journey, ready to share.
* **Characters**: every character on the account side by side, with account totals.

Click any stat tile, almanac line, record, Wrapped fact or chapter to get it in a box ready for
Ctrl+C. Almanac and Wrapped have a "Copy all" button.

## Badges

36 personal milestones that become chapters on your timeline when earned: Untouchable (finish
a level without dying), Cartographer (uncover every area of a zone), Night Owl, Nomad (travel
1,000 km on foot or mount), Happy Camper, Good Company, The Summit and more. `/journey badges`
lists them all.

## Outside the window

* **Banners**: a small, movable banner for new chapters, badges and personal bests, a "Back in
  Westfall" memory banner when you return to a zone, and a dungeon run recap.
* **World map**: tombstones where you died (hover for the killer) and footprints on the
  continent maps sized by the time you spent in each zone.
* **Chat recaps**: a short line when you level ("Level 20 after 1d 2h. Level 19 took 3h:
  23 quests, 412 kills, 3 deaths.") and a welcome-back line at login with "a week ago today"
  chapters.

Every banner and chat line can be switched off individually.

## Works well with

* **Questie**: quests completed per zone on the World page ("Westfall 28 / 61"), computed from
  the Questie database in the background without hitching.
* **Forever Dungeon Journal**: boss lists for the new Forever dungeons.

Neither is required.

## Light on your client

Forever Journey keeps counters, not logs, so the saved data stays small no matter how long you
play. It never registers the combat log (a protected action on this client) and does heavy work
in small slices in the background.

Everything is stored locally in your SavedVariables. Nothing is sent anywhere.

## Commands

```text
/journey                 open or close
/journey wrapped         open Forever Wrapped
/journey minimap         show or hide the minimap button
/journey scale 0.9       window scale (0.6 to 1.5)
/journey deaths          show or hide single deaths on the timeline
/journey map             toggle world map tombstones and footprints
/journey toasts          toggle banners
/journey recaps          toggle chat recaps
/journey badges          list all badges
/journey probe           print client capabilities for a bug report
/journey reset           erase this character's data
```

## Requirements

Made for the **World of Warcraft: Forever** client (Interface 16001). It will not work on
Retail or Classic.

## Reporting problems

Install BugSack and BugGrabber, reproduce the problem and post the error together with the
output of `/journey probe`, either in the comments here or as an issue on
[GitHub](https://github.com/jebstern/Forever-Journey/issues). Feature ideas are welcome too.
