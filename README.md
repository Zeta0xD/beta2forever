# beta2forever

Copies your addons and settings from the World of Warcraft: Forever beta client to the Forever client (`_forever_`) on Windows: addons, graphics and sound settings, keybinds, macros, game options, addon settings, and one character's settings onto another character. It asks before each part, backs up everything it replaces, and checks every copy.

## Quick start

1. **Download.** On the GitHub page, click the green **Code** button, then **Download ZIP**.
2. **Extract.** Right-click the downloaded ZIP, choose **Extract All**, and open the extracted folder. The script does not run from inside the ZIP.
3. **Quit the game fully.** Close World of Warcraft. The script stops if the game is still running.
4. **Log in once on Forever.** Start the Forever client, log in with each character you want to copy settings onto, then quit. This creates the folders the script copies into.
5. **Run it.** Double-click `beta2forever.bat`. If Windows shows a security warning, click **More info** and **Run anyway** (SmartScreen) or **Run** (file security warning).
6. **Answer the questions.** Type `y` or `n` and press Enter for each part, and type a number to pick an account or character from a list. Each entry shows when it was last changed, which tells your accounts apart. The script lists what it will do and waits for `y` before changing anything.
7. **Start the game** and log in when it says `Done`.

The script finds the World of Warcraft folder on its own when it is in a usual place; otherwise it asks you to paste the folder's path (the folder that holds `_classic_beta_` and `_forever_`).

## What it copies

| Question | Copied |
|---|---|
| Copy your addons? | Every addon folder. An addon in both clients is replaced by the beta's copy; addons only in Forever stay. |
| Copy graphics and sound settings? | `WTF\Config.wtf`, except its login and client lines (`portal`, `agentUID`, `accountName`, `accountList`, `lastCharacterIndex`), which keep Forever's values so the client still logs in to Forever. |
| Copy account settings? | Keybinds, macros, game options, chat setup, Edit Mode layouts, and every addon's account-wide settings, into the Forever account you pick. |
| Copy one character's settings to another character? | That character's game options, keybinds and macros if it has its own, chat windows, click bindings, Edit Mode choice, addon list, and addon settings, onto the Forever character you pick. Repeat for more characters. |

Characters and accounts can have different names in the two clients.

## Backup and undo

Before copying, the script saves the Forever `WTF` folder (and `Interface\AddOns` when you copy addons) to `beta2forever-backup-<date>-<time>` inside your World of Warcraft folder. To undo, quit the game and copy the contents of that backup folder over `_forever_`, replacing files. Each run makes a new backup the size of your settings plus addons; delete old backup folders once the game works.

If something fails partway, the script says what failed and where the backup is. If the backup itself fails, nothing is changed.

## Known limits

- **Server copies.** The game server keeps its own copy of keybinds, macros, game options and Edit Mode layouts and can replace the copied ones when you log in. If they come back as defaults, change one keybind in-game, quit, run the script again, and log in.
- **Action bars** are stored on the server only and are not copied.
- **Character-specific keybinds.** If the Forever character already uses its own keybinds, the copied account keybinds do not apply to it. Copy that character's settings too, or switch it back to account keybinds in the game's keybinding options.
- **Per-character choices inside addon settings.** Some addons record per-character choices (such as which layout a character uses) under the old character's name, so the new character starts on that addon's defaults for those choices.
- **Different addon versions.** Settings are copied as they are. An addon version on Forever that cannot read the beta version's settings resets them.
- Whether the client accepts the copied files without their matching `cache.md5` is not verified in-game.
- Windows only.

## Advanced

Run from PowerShell or a command prompt in the extracted folder:

```bash
powershell -NoProfile -ExecutionPolicy Bypass -File beta2forever.ps1 -WowDir "D:\World of Warcraft"
```

- `-WowDir`: the World of Warcraft folder, when the script does not find it.
- `-From`, `-To`: the client folder names; defaults `_classic_beta_` and `_forever_`.
- `-Answers`, `-SkipProcessCheck`: for the test only.

The script exits with code 0 when every copy matches its source, and 1 on cancel, error, or mismatch. `beta2forever.bat` runs the script with `-ExecutionPolicy Bypass` for that one run, so Windows' script setting is not changed.

## Test

Builds a fake install in `%TEMP%`, runs the script with scripted answers, and prints `PASS`:

```bash
powershell -NoProfile -ExecutionPolicy Bypass -File test\test.ps1
```
