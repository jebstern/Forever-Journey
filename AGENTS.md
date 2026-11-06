# AGENTS.md - working on Forever Journey

Forever Journey is a World of Warcraft addon (Lua 5.1, WoW API) for the **WoW: Forever**
client. It records a character's personal journey: zones, levels, quests, deaths, dungeons,
gold, professions, emotes, camping, and shows it in one window. It is deliberately not a
game database; Questie and the Dungeon Journal already are.

Read `docs/ARCHITECTURE.md` before changing data flow. It holds the feasibility matrix,
the SavedVariables schema and every client fact verified in-game so far.

## The client is unusual. Do not assume Retail or Classic.

| Fact | Consequence for code |
|---|---|
| Interface **16001**, build 1.60.x. `WOW_PROJECT_ID` is not Retail's, but the API is Retail-shaped (`C_QuestLog.GetInfo`, `GetProfessions`, `C_Item`, `C_UnitAuras`, `Settings`). Classic-only globals like `GetSkillLineInfo`, `GetQuestsCompleted` do not exist. | Call modern APIs first, keep Classic fallbacks behind `if X then`. |
| **Secret values** exist (`canaccessvalue`, `issecretvalue`, `C_Secrets`). Combat and unit data can be unreadable in instances. | Wrap every value from combat/unit/aura/chat APIs in `FJ.canaccess(v)` before comparing, concatenating or indexing with it. |
| **Registering `COMBAT_LOG_EVENT_UNFILTERED` is a protected action** and raises `ADDON_ACTION_FORBIDDEN`. A `pcall` does not stop the error popup. | Never register it when `FJ.RestrictedCombatLog` is true. `FJ:RegisterEvent` refuses it. Kills and boss kills come from chat lines and encounter events instead. |
| `GetStatistic` works and is populated (Wrath-era statistics catalogue plus Forever additions, see `Trackers/Lifetime.lua`). | Lifetime numbers (quests, deaths, kills, gold, dungeons, final bosses) come from the game; our own counters are "since recording began". Keep that distinction visible in tooltips. |
| New Forever content exists (Zephras Isle, Riverglades, Shen'dralas, Hyjal, Hall of Thanes, Ruins of Lordaeron, City of Dalaran, Shaper's Terrace, Alcaz Prison, Barrow Deeps, Skyborne races). | Build zone lists from `C_Map.GetMapChildrenInfo` at runtime; never hard-code zone lists. Static tables only carry hints (level ranges, exploration totals, boss NPC IDs). |

## Layout

```
ForeverJourney.toc      load order matters: Core/Init -> Events -> Database -> Data -> Timeline -> Trackers -> Stats/Suggestions -> UI
Core/      Init (namespace, utils, compat), Events (one frame, pcall-guarded), Database (schema, caps, migrations),
           Timeline (milestones), Stats (read-only derivations), Suggestions ("Next" page), Slash (commands, /journey probe)
Data/      Bosses (NPC IDs, dungeon catalogue), Zones (level hints, capitals, exploration overlay totals)
Trackers/  Session, Character (level/XP/gold/professions), Zones, Quests, Lifetime (GetStatistic), Combat, Dungeons, Items,
           Social (emotes/sit/camp), Companions (group members), Gear (equipment, homes, riding),
           ZoneQuests (quest completion per zone from QuestieDB, coroutine-built),
           Moments (chapter toasts, zone banners, run recaps, death line; all via internal messages)
Core/      also Badges (36 pure checks over existing data, evaluated quietly at login then on data changes)
UI/        Theme, Widgets (all hand-built; W.ShowCopyBox / W.MakeCopyable for click-to-copy), Toast (one movable banner),
           Minimap, MainFrame (window + page registry),
           MapPins.lua + MapPins.xml (World Map data providers and pin templates; the only XML in the addon),
           Pages/ Dashboard, Journey (timeline), World (zones), Statistics (charts), Almanac (all numbers,
           from Stats:Almanac()), Characters (account roster + totals), Next (suggestions), Wrapped (summary)

Internal messages worth knowing: FJ_DATA_CHANGED (debounced UI refresh), FJ_TICK (15 s heartbeat, dt),
FJ_TIMELINE_ADDED (entry), FJ_ZONE_CHANGED (mapID, name, isInstance), FJ_RUN_STARTED/FJ_RUN_ENDED (run, valid),
FJ_BOSS_KILLED (npcID, boss, name, first), FJ_PLAYER_DIED (info).
```

Conventions:

* Modules: `local M = FJ:NewModule("Name")`; lifecycle hooks `OnInit` (ADDON_LOADED),
  `OnLogin`, `OnEnable` (first PLAYER_ENTERING_WORLD), `OnEnteringWorld`, `OnLogout`.
* Events: `FJ:RegisterEvent(event, fn)` only. It pcalls registration and skips unknown or
  restricted events. Internal messages: `FJ:SendMessage` / `FJ:RegisterMessage`. UI refresh is
  requested with `FJ:NotifyDataChanged()` (debounced), never by calling the UI directly.
* Data: everything the UI shows is a counter maintained at event time. No per-event logs.
  Growing lists use `FJ.PushCapped(list, item, FJ.CAPS.x)`. The timeline is pruned by priority.
  New fields go into `CHAR_DEFAULTS` in `Core/Database.lua`; `CopyDefaults` adds them to existing
  saves. One-time data fixes go into `FJ:MigrateDB()` behind a `flags.*` marker.
* UI: pages register with `FJ.UI:RegisterPage(key, {title, icon, order, build, refresh})`, build
  lazily, and must tolerate empty data. Use `FJ.Widgets` (frames, text, cards, bars, charts,
  scroll area, donut, timeline row). Only `UIPanelButtonTemplate` and `UIPanelCloseButton` from
  Blizzard. Fonts via `FJ.Theme.ApplyFont`; colours from `FJ.Theme.colors`.
* Text: no em-dashes in user-facing strings, say "since recording began" for our counters.
* Lua 5.1: no `goto`, no integer division, `#` only on arrays without holes, always pass a
  flags string to `SetFont`.

## Testing

There is no Lua interpreter or game runtime in the sandbox. Workflow:

1. Syntax-check all files with the luaparser script (a venv under `$TMPDIR/luaenv`; recreate with
   `python3 -m venv $TMPDIR/luaenv && $TMPDIR/luaenv/bin/pip install luaparser`), e.g.
   `python luacheck.py <addon dir>` parsing every `*.lua`. Also verify every TOC entry exists.
2. Ask the user to `/reload`, open `/journey`, and run `/journey probe`. BugSack + BugGrabber are
   installed; errors come back as pasted text.
3. Read the real SavedVariables when verifying persistence:
   `WTF/Account/<account>/<realm>/<char>/SavedVariables/ForeverJourney.lua` (per character) and
   `WTF/Account/<account>/SavedVariables/ForeverJourney.lua` (account: settings, roster, statdump).
4. `/journey statdump` + `/reload` writes the game's whole statistics catalogue to the account
   file; parse it from disk to discover statistic IDs instead of guessing.

Reference addons installed next to this one (read-only, useful for API questions on this client):
Questie (`Modules/QuestieCompat.lua`), Leatrix Plus and Leatrix Maps (Forever-only, 16001),
Details! (how it avoids the combat log on this client), Baganator/Syndicator, ForeverDungeonJournal
(boss NPC IDs for new dungeons; its namespace `ForeverDungeonJournal_NS.DB` is merged at runtime).

## Releasing

CurseForge packages the addon from GitHub when a tag is pushed (`docs/CURSEFORGE.md` has the
setup and the steps).

* Never hard-code a version in the TOC. `## Version: @project-version@` is replaced with the
  tag; `FJ.version` reads `dev` when running from source.
* A new top-level file or folder that is not part of the addon (docs, scripts, images) must be
  added to the `ignore` list in `.pkgmeta`, or it ships to players.
* Update `CHANGELOG.md` before tagging; it becomes the changelog on CurseForge.

## Commands worth knowing

`/journey` toggle, `/journey wrapped|journey|world|stats|next`, `/journey probe`,
`/journey statdump`, `/journey buffs`, `/journey campbuff <name>`, `/journey minimap`,
`/journey scale <n>`, `/journey deaths`, `/journey played`, `/journey reset`, `/journey debug`.
