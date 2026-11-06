# Forever Journey – Architecture & MVP proposal

Forever Journey is a personal adventure tracker for World of Warcraft: Forever.
It answers three questions about *your* character: where have I been, what have I
accomplished, and what could I do next. It is not a game database; Questie,
Dungeon Journal and AtlasLoot already cover that.

## 1. Client facts that shape the design

Verified against the installed client and the sibling addons in this folder
(Questie, Leatrix Plus, Baganator, Forever Dungeon Journal):

| Fact | Consequence |
|---|---|
| Client is `wow_classic_beta` 1.60.1 (build 70170), Interface **16001** | TOC targets 16001; version gate is `toc >= 16000 and toc < 17000`. |
| `WOW_PROJECT_ID == WOW_PROJECT_MAINLINE` but the content is Classic | The API is **Retail-shaped** (`C_QuestLog.GetInfo`, `C_Item`, `C_Container`, `C_Reputation`, `Settings`, `ScrollUtil`) while zones, dungeons and the level curve are Classic. Every API call goes through a small compat layer so the addon also survives on Era/Anniversary. |
| `canaccessvalue` / `issecretvalue` / `C_Secrets` exist (12.0 "secret values") | Combat-log and unit data may be unreadable inside instances. All combat-log reads are guarded; nothing crashes if a value is secret, we just don't count it. **Verified in-game (4 Oct 2026):** even `UnitIsAFK("player")` returned a secret boolean during a heartbeat tick, so every boolean unit predicate (AFK, dead, taxi, resting, combat, mounted, target, group members) goes through `FJ.Bool(v, default)`, which checks `canaccessvalue` before the boolean test. An unreadable state reads as "no", except taxi transitions keep the previous state and the camp check treats it as "in combat". |
| Questie: `QUEST_ACCEPTED` sends only `questID` on Forever | Handle both signatures. |
| New Forever content exists (Skyborne races, Zephras Isle, Hall of Thanes, Ruins of Lordaeron, City of Dalaran) | Zone lists are built at runtime from `C_Map.GetMapChildrenInfo`, never hard-coded. Boss data for new dungeons is seeded from Dungeon Journal's published NPC IDs and extended at runtime if that addon is installed. |
| **Verified in-game (2 Oct 2026):** `GetStatistic` is populated on Forever and the full catalogue (195 statistics, read via `/journey statdump`) is the Wrath-era set plus Forever additions: deaths by cause, quests completed/abandoned, kills (total, XP-granting, killing blows, creatures, critters, favourite creature type), wealth (328 total acquired, 326 quest rewards, 333 looted, 921 vendors, 919 auctions, 1146 travel, 1148 postage, 334 most ever owned), travel (349 flights, 353 hearthstones), 932 dungeons entered, consumables, duels, battlegrounds (incl. Darkspear Islands), social emotes, and **final-boss kill counters for every dungeon** including Forever's Shaper's Terrace, Alcaz Prison, Barrow Deeps and Hyjal Summit | `Trackers/Lifetime.lua` reads ~70 of them at login and on `CRITERIA_UPDATE` into `db.lifetime`. Lifetime values are the headline numbers wherever they exist (quests, deaths, kills, gold, dungeons entered/conquered); since-install numbers stay in tooltips. Wrapped builds its fact list from them. The dump stays available for future IDs. |
| Emotes and camping | Emotes are counted from a `hooksecurefunc` on `DoEmote`, which every slash emote passes through (exact tokens, no text parsing); custom `/e` lines are one bucket via a `SendChatMessage` hook. Counts live in `db.emotes`; the Statistics page draws a donut from radial `Line` segments. Camping is detected from the buff itself: on `UNIT_AURA` (player, debounced, skipped in combat and when `C_Secrets.ShouldAurasBeSecret()`), a transition into a buff named `settings.campBuff` (default "Camping", or its remembered spell ID) counts one camp and times it until it fades. `/journey buffs` lists current buffs to confirm the name. Sitting, kneeling and sleeping are timed from the emote (or the sit/stand key toggle) until anything that makes a character stand: `PLAYER_STARTED_MOVING`, `JumpOrAscendStart`, `UNIT_SPELLCAST_SENT`, combat, NPC windows, death, loading screens, `/stand` or an animated emote; a heartbeat speed check is the fallback. There is no stance API, so this is an approximation that self-corrects on the first step. |
| World Map pins | `UI/MapPins.lua` registers two `MapCanvasDataProviderMixin` providers on `WorldMapFrame` with pin templates from `UI/MapPins.xml`. Deaths store the best map ID and normalised position at `PLAYER_DEAD`; tombstones appear on that map. Footprints are one pin per visited zone on continent and world maps, placed at the centre of `C_Map.GetMapRectOnMap` and sized by time share. Guarded so clients without the mixins skip the feature. |
| Chat recaps | `Character:OnLevelUp` prints the finished level's time, quests, kills and deaths; `Session:PrintWelcome` prints the previous session and "a week / month / year ago today" chapters from the timeline on real logins only (not reloads). `settings.chatRecaps`. |
| Companions | `Trackers/Companions.lua` keys on `GetUnitName(unit, true)` of party/raid members: time together per heartbeat, times grouped per roster change, class. Names that are secret (instances) are skipped for that tick. Capped at 200 by time. |
| Gear and home | `Trackers/Gear.lua` tracks the 17 equipment slots on `PLAYER_EQUIPMENT_CHANGED`, measuring worn time in /played seconds; `gearHistory` keeps the longest-worn items (capped 150). Average item level is stored per level. Homes come from `GetBindLocation` plus `HEARTHSTONE_BOUND` or the "is now your home" system message. First ride and time mounted from `IsMounted()` on the heartbeat. |
| Zone quest completion | `Trackers/ZoneQuests.lua` imports Questie's `ZoneDB` and `QuestieDB` through `QuestieLoader:ImportModule` once `Questie.started`, runs `ZoneDB.GetZonesWithQuests(true)` inside a coroutine resumed every 30 ms, drops repeatable quests, maps area IDs to UiMapIDs, and counts completion with `C_QuestLog.IsQuestFlaggedCompleted`; quests whose `exclusiveTo` partner is complete count as unobtainable. Per-zone totals are cached in `db.zoneQuests` so the World page has numbers before the rebuild finishes. Without Questie the feature reports "unavailable" and the UI falls back to turn-in counts. |
| Moments and toasts | `UI/Toast.lua` is one movable banner with a queue (capped at 5) and an alpha animation. `Trackers/Moments.lua` subscribes to `FJ_TIMELINE_ADDED` (chapters with priority >= `settings.toastMinPriority`, deaths and flight paths excluded), `FJ_ZONE_CHANGED` (zone memory banner on revisits, throttled 10 min per zone, uses `z.prevLast`), `FJ_RUN_ENDED` (run recap in chat and banner, with the party captured during the run and personal bests from `Dungeons:RecordCompletion`) and `FJ_PLAYER_DIED` (one chat line: streak ended, nemesis count, nth death in zone). |
| Badges | `Core/Badges.lua` holds 36 definitions with pure check functions over existing data; evaluated 30 s after login (quietly, so already-true badges do not spam banners), then debounced on data changes and on level-up with the previous level's bucket. Earned badges are chapters of kind `badge`. |
| Characters page and account totals | `FJ:UpdateRoster()` now stores kills, gold, zones, dungeons, flights, badges and first-seen per character (refreshed every 2 min while playing and at logout). `UI/Pages/Characters.lua` lists the roster with account totals; `FJ.AccountSummary()` feeds a Wrapped fact. |
| Small stats | Flight log (`TakeTaxiNode` hook for the route, `PLAYER_CONTROL_LOST/GAINED` plus the heartbeat for duration), loot rolls won (`LOOT_ROLL_YOU_WON*` chat lines), deadliest hour (`db.deathClock`), deaths per hour by level band (from time per level), abilities learned (`LEARNED_SPELL_*`), trainer spending (`TRAINER_SHOW` context), sunrises and sunsets (`GetGameTime` hour crossings on the heartbeat). |
| Click to copy | WoW has no clipboard API. `W.ShowCopyBox` shows the text in a multi-line edit box, selected, for Ctrl+C; `W.MakeCopyable` wires frames. Stat tiles, almanac rows, records, Wrapped facts, chapters and character rows are copyable; Almanac and Wrapped have "Copy all". |
| Gold attribution | Every purse change fires `PLAYER_MONEY`. The open window (vendor, auction house, mail, trade, flight master, kept 2 s after closing), a pending quest reward (`QUEST_TURNED_IN` money), the loot chat line (`CHAT_MSG_MONEY`) and a `RepairAllItems` hook classify each delta into `db.gold.earned` / `db.gold.spent` buckets; late explanations re-attribute the last "other" delta. The Statistics page shows lifetime income by source from the game's wealth statistics and spending by purpose from our buckets. |
| **Verified in-game (2 Oct 2026):** registering `COMBAT_LOG_EVENT_UNFILTERED` raises `ADDON_ACTION_FORBIDDEN` on Forever; a `pcall` does not prevent the "blocked action" report. Details! treats Forever (16001+) exactly like Retail 12.0 and uses Blizzard's `C_DamageMeter` instead | `FJ.RestrictedCombatLog` is true on Forever and `FJ:RegisterEvent` refuses the event outright. The combat-log code path stays for Era/Anniversary clients. Kills therefore have three sources with de-duplication: combat log `PARTY_KILL`, the chat line "You have slain X!", and the XP-gain line "X dies, you gain N experience". Boss kills use `UNIT_DIED` when readable and fall back to the "%s dies." chat message matched against the boss-name table. The probe reports how many combat-log events were secret. |
| Leatrix Maps ships map-exploration overlay data for 44 Forever zones | The per-zone overlay *counts* are embedded in `Data/Zones.lua` (`FJ.Data.Explore`) and compared with `C_MapExplorationInfo.GetExploredMapTextures` to give a real exploration percentage per zone, including the new zones Zephras Isle, Riverglades, Shen'dralas and Hyjal. |
| No Lua toolchain on this machine, no in-game testing from here | Code is written defensively (pcall around event registration, nil-safe API wrappers). First in-game run will need a BugSack pass. |

## 2. Overall architecture

```
Events (one frame, pcall-guarded registration)
   │
   ├── Trackers (event → in-memory SavedVariables tables, O(1) per event)
   │     Session · Character · Zones · Quests · Combat · Dungeons · Items
   │
   ├── Timeline (milestone journal with priorities + hard cap)
   │
   ├── Stats / Suggestions (pure read-only derivations, computed on demand)
   │
   └── UI (built lazily on first open; pages refresh only while visible)
         Dashboard · Journey · World · Statistics · Next · Wrapped
```

Principles:

* **Event-driven, never polling the game state.** The only timer is a 15 s
  heartbeat that attributes elapsed time to the current zone / activity /
  level bucket. No `OnUpdate`.
* **Aggregate at write time.** Every counter the UI shows is maintained
  incrementally. The UI never scans a log to compute a total.
* **Capped lists only.** Anything that grows with play time (sessions, deaths,
  runs, items, timeline) has a cap and a pruning rule.
* **No dependencies.** No Ace3, no LibDBIcon. The whole addon is ~20 small files.
* **Honest numbers.** Every metric below is labelled as exact, since-install or
  approximate, and the UI tooltips say which.

## 3. Feasibility matrix

| Metric | Source | Reliability |
|---|---|---|
| Level, XP, rested | `UnitLevel`, `UnitXP/UnitXPMax`, `GetXPExhaustion`, `PLAYER_LEVEL_UP`, `PLAYER_XP_UPDATE` | Exact |
| /played total and at level | `RequestTimePlayed()` → `TIME_PLAYED_MSG` (chat line suppressed for our own request) | Exact (includes time before install) |
| Quests completed (lifetime) | `C_QuestLog.GetAllCompletedQuestIDs()` count (fallback `GetQuestsCompleted`) | Exact, includes pre-install |
| Quests per zone / level / session | `QUEST_TURNED_IN(questID, xp, money)` + current zone | Since install; zone = turn-in zone (approximation, labelled) |
| XP by source | `QUEST_TURNED_IN` xp, `ERR_ZONE_EXPLORED_XP`, `CHAT_MSG_COMBAT_XP_GAIN` for kills, total from `PLAYER_XP_UPDATE` | Total exact; split approximate |
| Deaths (+ zone, level, killer) | `PLAYER_DEAD`, last damaging source from the combat log | Exact count; killer best-effort (unknown inside instances if secret) |
| Enemies killed | `COMBAT_LOG_EVENT_UNFILTERED` `PARTY_KILL` where source is you or your pet | Killing blows only, labelled as such; may be unavailable in instances |
| Boss kills / dungeon completion | `UNIT_DIED` + NPC ID table (`Data/Bosses.lua`); fallback `CHAT_MSG_COMBAT_HOSTILE_DEATH` name match | Good in open world; inside instances depends on secret-value rules (to be verified with the probe) |
| Dungeon runs, time, best time | `PLAYER_ENTERING_WORLD` + `IsInInstance()` + `GetInstanceInfo()` | Exact |
| Gold earned / spent | `PLAYER_MONEY` deltas of `GetMoney()` | Exact totals; sign-based classification (mail, AH, trades count by sign) |
| Zones visited, first visit, time per zone | `ZONE_CHANGED_NEW_AREA` + `C_Map.GetBestMapForUnit` walked up to the Zone-type map | Exact since install |
| Discoveries (sub-zones explored) | `UI_INFO_MESSAGE` with `ERR_ZONE_EXPLORED` / `ERR_ZONE_EXPLORED_XP` | Exact since install; no "total per zone" without data (later: Leatrix Maps data) |
| Flight points known | `TAXIMAP_OPENED` scan of `NumTaxiNodes`/`TaxiNodeGetType` (+ `ERR_NEWTAXIPATH`) | Exact once a flight master has been opened (includes pre-install) |
| Flights taken | `UnitOnTaxi` transition in heartbeat | Exact since install |
| Professions and milestones | `GetProfessions/GetProfessionInfo` (Retail API) or `GetNumSkillLines/GetSkillLineInfo`, on `SKILL_LINES_CHANGED`, `CHAT_MSG_SKILL` | Exact |
| Notable loot (rare+ quality) | `CHAT_MSG_LOOT` self patterns, quality from the link colour | Exact |
| Rare mobs encountered | `PLAYER_TARGET_CHANGED` + `UnitClassification` | Since install; only when targeted |
| Time by activity | Heartbeat classification: instance type, `UnitOnTaxi`, `IsResting`, `UnitIsDeadOrGhost`, `UnitIsAFK` | Approximate, labelled "based on where you were" |
| Zone completion % | Needs totals per zone (quests, discoveries, flight points) | **Not in MVP** – shown as absolute counts; later via optional QuestieDB / Leatrix Maps data |
| Quest chains completed | No API | Excluded |
| Character creation date | Not exposed | We record "journey began" only if first seen at level 1 with < 10 min played; otherwise "recording started at level N" |

## 4. Events and API used

Registration is wrapped in `pcall`, so an event missing on a given client is
simply skipped. Core set:

`ADDON_LOADED, PLAYER_LOGIN, PLAYER_ENTERING_WORLD, PLAYER_LOGOUT, PLAYER_LEVEL_UP,
PLAYER_XP_UPDATE, PLAYER_MONEY, PLAYER_DEAD, PLAYER_ALIVE, PLAYER_UNGHOST,
QUEST_TURNED_IN, QUEST_ACCEPTED, ZONE_CHANGED_NEW_AREA, ZONE_CHANGED,
ZONE_CHANGED_INDOORS, UI_INFO_MESSAGE, TAXIMAP_OPENED, TIME_PLAYED_MSG,
SKILL_LINES_CHANGED, CHAT_MSG_SKILL, LEARNED_SPELL_IN_SKILL_LINE,
LEARNED_SPELL_IN_TAB, COMBAT_LOG_EVENT_UNFILTERED, CHAT_MSG_COMBAT_XP_GAIN,
CHAT_MSG_COMBAT_HOSTILE_DEATH, CHAT_MSG_LOOT, PLAYER_TARGET_CHANGED, UNIT_PET`

## 5. SavedVariables

* `ForeverJourneyDB` (account): settings, minimap position, window position and a
  tiny roster summary per character (for a future "all characters" view).
* `ForeverJourneyCharDB` (per character): the journey itself.

```
char        name, realm, class, race, faction, firstSeen, firstSeenLevel
totals      ~25 counters (tracked time, xp by source, quests, kills, deaths, gold, ...)
levels      [level] = { t, played, zone, time, xp, q, k, d }          ≤ 60 rows
zones       [uiMapID] = { name, first, lvl, time, q, k, d, disc, discNames≤60 }
taxi        [nodeName] = epoch                                      ≤ ~100
professions [name] = { learned, rank, max, ms = {75=t,150=t,...} }
bosses      [npcID] = { name, n, first }
dungeons    [instanceName] = { runs, done, time, best, bosses, first, last }
runs        last 40 runs
deaths      last 40 deaths  (+ per-zone and per-level counters)
sessions    last 150 sessions { s, d, xp, q, k, dth, gold, lvl0, lvl1 }
timeline    ≤ 300 milestones { t, k(kind), p(priority), l(level), z(zone), a, b }
activity    7 time buckets
killsByName ≤ 300 names, deathsByKiller ≤ 100 names (for "nemesis" stats)
clock       [hour 0-23] = seconds;  weekday [0-6] = seconds;  days ["YYYYMMDD"] = seconds (≤ 730 days kept)
emotes      [token] = count;  gold.earned / gold.spent = per-source buckets;  lifetime = cached GetStatistic values
totals also carry: jumps, distance (yards, straight-line between heartbeat samples, flights and
            instances excluded), sitCount/sitTime/sitLongest/kneelTime/sleepTime, campCount/campTime/campLongest,
            trackedAtLastDeath/longestNoDeath (deathless streaks in tracked time)
```

Derived (never stored): time per level = difference of the /played anchors of consecutive
level-ups (exact), or the server's time-at-level for the current level; days played, streaks of
consecutive days, busiest day; play clock and weekday histograms; exploration summary over
visited zones; the Almanac (`Stats:Almanac()`), ~120 labelled rows in ten sections, built on demand.

Expected size: well under 100 KB per character after a full 1–60 journey.

## 6. Keeping SavedVariables small

* Counters, not logs: kills, XP and gold are never stored per event.
* Timeline cap of 300 with priority pruning: when full, the oldest entry with the
  lowest priority is dropped first (individual deaths and flight paths go first,
  level-ups and first boss kills last).
* Sessions shorter than 60 s are not stored. Reloads continue the same session.
* Deaths/runs/items keep only the last N details; totals live in counters.
* Per-zone discovery names are capped; the count is kept exactly.
* Pruning runs at logout and at login, never during play.

## 7. Computing statistics efficiently

* Every event updates at most a handful of integers (zone, level, session, total).
* Charts read pre-bucketed tables: level-vs-played from `levels`, XP/quests per
  session from `sessions`, time per zone from `zones`, activity split from
  `activity`. Nothing is scanned except these small tables.
* Derived stats (favourite zone, deadliest zone, average session, XP/h) are
  computed in `Core/Stats.lua` only when a page is shown and cached until the
  next data change (debounced 0.5 s message).
* The combat-log handler does one string compare on the sub-event before doing
  anything else and returns immediately for everything it doesn't need.

## 8. UI structure

One window (`ForeverJourneyFrame`, ESC-closable, movable, position saved) with a
left sidebar and a content area. Pages register themselves and are built on first
visit:

* **Dashboard** – hero card (class, level, XP bar, /played, journey start), eight
  stat tiles, recent chapters, this session, professions, where your time went.
* **Journey** – chronological timeline grouped by level ("LEVEL 20 … YOU ARE
  HERE"), deaths and flight paths collapsed into one row, filters.
* **World** – continents → zones with visited state and per-zone counts, detail
  panel for a zone (first visit, time, quests, deaths, discoveries, flight points).
* **Statistics** – level over /played (line), XP per session (bars), time by
  activity, time per zone, deaths per level, gold over sessions, records.
* **Next** – gentle suggestions (quest log by zone, dungeons for your level you
  haven't finished, unvisited zones for your level, profession caps, milestones).
* **Wrapped** – the "Forever Wrapped" summary.

Widgets are hand-built from textures and font strings (`UI/Widgets.lua`):
card, stat tile, progress bar, horizontal bars, vertical bars, line chart,
scroll area, timeline row. No Blizzard templates beyond `BackdropTemplate`,
`UIPanelButtonTemplate` and `UIPanelCloseButton`.

## 9. MVP vs later

**MVP (this version, 0.1):** all trackers above, Dashboard, Journey, World (visited
and counts), Statistics (6 charts), Next (5 suggestion types), Wrapped, minimap
button, slash commands, keybinding, addon-compartment entry.

**Later:**
* Zone completion % using optional data (QuestieDB quest totals, Leatrix Maps
  exploration overlays, flight-master tables).
* Account-wide "all characters" overview from the roster.
* Reading Blizzard statistics (`GetStatistic`) for pre-install history if the
  probe shows they are populated on Forever.
* Export/share of the Wrapped card as text.
* Localisation beyond the format-string parsing already done.

## 10. Risks

* **Secret values in instances.** Kill/boss detection inside dungeons may silently
  not work. The combat-log handler never errors; `/journey probe` reports whether
  combat-log arguments are secret in the current context.
* **Map hierarchy quirks.** `GetBestMapForUnit` can return nil right after a
  loading screen; zone resolution retries after 2 s.
* **Event signature differences** (`QUEST_ACCEPTED`) handled explicitly.
* **Chat-line suppression** of our own `/played` request hooks
  `ChatFrame_DisplayTimePlayed`; if that function is absent the line is simply shown.
* **Memory.** The UI is created on first open only; text pools are reused.

## 11. Folder structure

```
ForeverJourney/
  ForeverJourney.toc
  Bindings.xml
  docs/ARCHITECTURE.md
  Core/     Init, Events, Database, Timeline, Stats, Suggestions, Slash
  Data/     Bosses (NPC IDs), Zones (level ranges, capitals)
  Trackers/ Session, Character, Zones, Quests, Combat, Dungeons, Items
  UI/       Theme, Widgets, Minimap, MainFrame, Pages/{Dashboard,Journey,World,Statistics,Next,Wrapped}
```
