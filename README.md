# Forever Journey

A personal adventure journal for World of Warcraft: Forever. It records where your
character has been, what you have accomplished and suggests what you could do next.
It is not a game database; it is the story of *your* character.

Open it with `/journey`, the minimap button, or a keybinding (Options > Keybindings > Forever Journey).

## Pages

* **Dashboard** - level and XP, /played, eight headline numbers, recent chapters, this session, professions.
* **Journey** - a timeline of milestones grouped by level: levels, first visits, dungeons,
  boss kills, professions, flight paths, notable loot, deaths (collapsed), and "you are here".
* **World** - continents and zones with visited state, time spent, quests, deaths, map exploration
  percentage, known flight paths and the places you discovered.
* **Statistics** - charts: level over time played, time per level, deaths, quests and kills per
  level, XP per session, how and where you spend your time, when you play (hour of day and
  weekday), gold over sessions, XP sources, gold by source and purpose, emotes (donut chart),
  camping and sitting, personal records.
* **Almanac** - every number in one place: character and time (days played, streaks, pace per
  level), deaths (lifetime, per hour, by cause, deathless streaks, resurrections), combat, quests,
  travel and exploration (distance travelled, jumps, hearthstones, flights), dungeons and raids,
  economy, professions, consumables, social and rest.
* **Next** - gentle suggestions: quests in your log by zone, dungeons for your level you have not
  finished, zones you have not visited, half-explored zones, missing flight paths, profession caps.
* **Wrapped** - a "Forever Wrapped" summary of the whole journey.

* **Characters** - every character on the account side by side, with account totals.
* **Badges** - 36 personal milestones (deathless level, cartographer, night owl, nomad, ...)
  that become chapters when earned. `/journey badges` lists them.

Click any stat tile, almanac line, record, Wrapped fact or chapter to get it in a box ready
for Ctrl+C. Almanac and Wrapped have a "Copy all" button.

Outside the window:

* **Banners** - a small banner for new chapters, badges and personal bests; a "Back in
  Westfall" memory banner when you return to a zone; a dungeon run recap in chat and banner.
  Drag the banner where you like with `/journey toast`. Toggles: `/journey toasts`,
  `/journey banner`, `/journey runrecap`, `/journey deathline`.

* **World Map** - tombstones where you died (hover for the killer) and footprints on the
  continent maps sized by time spent in each zone. `/journey map` toggles them.
* **Chat recaps** - a short line when you level ("Level 20 after 1d 2h. Level 19 took 3h:
  23 quests, 412 kills, 3 deaths.") and a welcome-back line at login with "a week ago today"
  chapters. `/journey recaps` toggles them.
* **Companions** - who you grouped with, how often and for how long (Statistics and Almanac).
* **Gear and home** - the item you have worn the longest, average item level per level, your
  hearthstone homes over time, your first ride.
* **Zone completion** - with Questie installed, quests completed per zone on the World page
  ("Westfall 28 / 61"), computed from QuestieDB in the background without hitching.

## What is exact and what is not

* Lifetime quests completed and /played come from the game itself and include time before install.
* Everything else is recorded from the moment the addon is installed.
* "Enemies slain" counts killing blows by you or your pet.
* Quest counts per zone use the zone where you handed the quest in.
* Time by activity is based on where you were (instance, flight, resting, dead, away).

## Commands

```
/journey                 open or close
/journey wrapped         open Forever Wrapped
/journey minimap         show or hide the minimap button
/journey scale 0.9       window scale (0.6 to 1.5)
/journey deaths          show or hide single deaths on the timeline
/journey probe           print client capabilities for a bug report
/journey statdump        save the game's full statistics list to SavedVariables
/journey buffs           list your current buffs (to confirm the camping buff name)
/journey campbuff <name> set the buff name that counts as camping (default "Camping")
/journey reset           erase this character's data
```

## Reporting problems

Install BugSack + BugGrabber, reproduce, and paste the error together with the output of
`/journey probe`. See `docs/ARCHITECTURE.md` for the design and the data model.

## License

MIT, see `LICENSE`.
