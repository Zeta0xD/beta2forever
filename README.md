# beta2forever

Copies addons and settings from the World of Warcraft: Forever beta client (`_classic_beta_`) to the Forever stress test client (`_forever_`) on Windows. It asks which parts to copy, which accounts and characters to copy between, backs up what it replaces, and checks every copied file against its source.

## Run

1. Quit the game fully. The script refuses to run while any `Wow*` process, or any program inside the install folder, is running.
2. Log in once on the Forever client with each character you want to copy into, then quit. This creates the folders the script copies into.
3. Double-click `beta2forever.bat`, or run:

```bash
powershell -NoProfile -ExecutionPolicy Bypass -File beta2forever.ps1
```

The script finds the install folder from the Blizzard registry entry, `Program Files`, or `<drive>:\World of Warcraft` and `<drive>:\Games\World of Warcraft`; otherwise it asks for it. Pass `-WowDir "D:\World of Warcraft"` to set it. `-From` and `-To` change the client folder names (defaults `_classic_beta_` and `_forever_`).

## What it copies

Each part is asked yes/no:

| Part | Copied | Into |
|---|---|---|
| Addons | every folder in `Interface\AddOns` | same-named Forever addon folders are replaced; Forever-only addons stay |
| Install-wide settings | `WTF\Config.wtf` | `WTF\Config.wtf` |
| Account settings | `bindings-cache.wtf`, `macros-cache.txt`, `config-cache.wtf`, `chat-frontend-cache.txt`, `edit-mode-cache-account.txt`, `tts-cache-account.txt`, `SavedVariables\*.lua` | the chosen Forever account |
| Character settings | `AddOns.txt`, `bindings-cache.wtf`, `macros-cache.txt`, `config-cache.wtf`, `chat-cache.txt`, `click-bindings-cache.txt`, `cooldownmanager.txt`, `edit-mode-cache-character.txt`, `layout-local.txt`, `tts-cache-character.txt`, `SavedVariables\*.lua` | the chosen Forever character; repeat for more pairs |

Source and target accounts and characters are picked from numbered lists; their names may differ. `cache.md5`, `.bak`/`.old` files and `WTF\Account\SavedVariables` are not copied.

## What it writes

- `<install>\beta2forever-backup-<yyyyMMdd-HHmmss>\WTF`: the Forever `WTF` folder before the copy, and `Interface\AddOns` when addons are copied. To undo, quit the game and copy these back over `_forever_`.
- The copied files in `_forever_`.

Exit code 0 when every copy matches its source; 1 on cancel, error, or mismatch.

## Known defects

- Addon settings that an addon keys by character name inside its account-wide file (for example a per-character layout choice) keep the old character's name, so the new character starts on that addon's defaults for those settings.
- Settings files are copied as they are; an addon version on Forever that cannot read the beta version's settings resets them.
- The server keeps its own copy of keybinds, macros, options and Edit Mode layouts and can replace the copied files at login. Action bars are stored on the server only and are not copied.
- Whether the client accepts the copied caches without the matching `cache.md5` is not verified in-game.
- Windows only.

## Test

Builds a fake install in `%TEMP%` and runs the script with scripted answers; prints `PASS` and exits 0:

```bash
powershell -NoProfile -ExecutionPolicy Bypass -File test\test.ps1
```
