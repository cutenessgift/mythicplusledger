# M+ Ledger

M+ Ledger is a personal Mythic+ and dungeon journal for World of Warcraft. It records the details that are easy to lose between runs and turns them into a practical history for reviewing routes, pacing, repairs, deaths, and group performance.

## Features

- Tracks Mythic+, normal, heroic, timewalking, dungeon, and raid runs.
- Records dungeon, difficulty, key level, duration, completion status, deaths, repairs, bosses, enemy forces, loot, and party members when the game exposes the data.
- Provides a compact, movable live tracker during a run.
- Stores party and raid roster snapshots with names, classes, levels, roles, guilds, and GUIDs when available.
- Shows Mythic+ score, Great Vault progress, season dungeon scores, best keys, best times, completion rates, and deaths per run.
- Provides dungeon history, boss pacing, travel and pull history, search, and run comparison views.
- Supports manual run creation and editing when a run was missed or needs correction.
- Keeps personal player history, notes, optional ratings, and Applicant Reputation information.
- Shares a selected run summary to the current chat edit box without sending it automatically.
- Includes a dungeon, raid, boss, and mob reference catalogue built from the game’s Encounter Journal.
- Offers Gold, Silver, Neutral, Garnet, Midnight Violet, and Garnet & Silver themes.
- Tracks interrupts using successful interrupt casts, party addon messages, and a fallback interrupted-cast correlation path.

## Installation

1. Download or clone this repository.
2. Place the `MPlusLedger` folder in:

   `World of Warcraft/_retail_/Interface/AddOns/`

3. Enable **M+ Ledger** from the AddOns list at character selection.
4. Reload the UI if the addon was installed while the game was running.

The addon currently targets WoW interface versions `120005`, `120007`, and `120100`.

## Commands

Use `/dl` to open the addon and print the current command list. Common commands include:

| Command | Action |
| --- | --- |
| `/dl` | Open or close the main ledger window |
| `/dl status` | Show the current or most recent run |
| `/dl mplus` | Open the Mythic+ overview and Great Vault dashboard |
| `/dl mobs` | Open the Mob & Boss Browser |
| `/dl bosses` | Show the boss checklist for the current or selected dungeon |
| `/dl catalog` | Build or refresh the Encounter Journal reference catalogue |
| `/dl share` | Insert a run summary into the active chat edit box |
| `/dl repair` | Record a repair cost manually |
| `/dl members` | Show recorded party or raid members |
| `/dl bar` | Show the live tracker bar |
| `/dl bar hide` | Hide the live tracker bar |
| `/dl complete` | Mark the active run as completed |
| `/dl end` | End the active run manually |
| `/dl debug` | Toggle diagnostic messages |

## Data and privacy

The ledger is stored locally in World of Warcraft SavedVariables under `MPlusLedgerDB`. The previous `InstanceLedgerDB` name is carried forward automatically where applicable.

The addon does not require an external account or web service. Party interrupt synchronization uses WoW addon messages between group members running M+ Ledger. Run data, personal notes, and ratings remain local to the user unless the user chooses to share a run summary in chat.

Manual entries are kept separate from Blizzard score and Great Vault data. The addon does not replace Blizzard’s score, rating, or group-finder systems.

## Accuracy and limitations

Some fields depend on data exposed by the WoW client. A run may therefore contain partial or missing boss, enemy-force, death, loot, roster, or interrupt information. Interrupt tracking is designed to provide the most reliable available count under current API restrictions, but it should still be treated as observed history rather than an authoritative combat-log replacement.

Repair tracking matches the repair merchant quote against the player’s money change. If the quote and money change cannot be matched, the repair may need to be entered manually.

## Contributing

Bug reports, feature ideas, testing notes, and pull requests are welcome. When reporting a tracking problem, include:

- WoW version and interface version.
- Addon version.
- Dungeon, difficulty, and key level.
- Whether the run was automatic or manually created.
- Relevant debug output from `/dl debug`.
- A description of what was expected and what was recorded.

Please remove character names or other personal information from logs before posting them publicly.

## License

M+ Ledger is released under the **GNU General Public License v3.0**. See [LICENSE](LICENSE).

The license applies to the project’s original code and original artwork. Blizzard-owned game assets and third-party libraries remain subject to their own rights and licenses.
