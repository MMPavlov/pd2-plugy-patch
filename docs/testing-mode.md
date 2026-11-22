# Testing mode (modpacks)

Back to the [README](../README.md).

Single-player packs such as [TDLofCC/PD2-PlugY](https://github.com/TDLofCC/PD2-PlugY)
include a **"testing" modpack** — modded text files in `ProjectD2\data\global\excel`
that add cube recipes for rerolling, duplicating, socketing and so on. The game only
loads them when started with `-direct -txt`, which is what the pack's
**`PlugY (testing)`** shortcut does (`cmd /c start PlugY.exe -direct -txt`).

That shortcut goes through `cmd.exe`, which is 64-bit, so on current Windows 11 it
fails with *Read process memory failed* like any other shortcut. Use these instead:

| to play | double-click |
|---|---|
| normally | `Launch-PD2-PlugY.bat` |
| with the testing modpack | **`Launch-PD2-PlugY (testing).bat`** |

The testing launcher adds `-direct -txt` and then works exactly like the normal one.
The stat-ranges patch works the same in both modes. **TDL's testing modpack is made for
Season 13**, so only use testing mode on the Season 13 rollback. For other
combinations, the launcher passes anything you give it on to the game:

```
Launch-PD2-PlugY.bat -GameArgs "-direct -txt -ns"
```

**Check it worked:** hover a unique or rare. You should see the green ranges,
e.g. `+297% Enhanced Damage [200 - 300]`, plus Max Sockets and the upgrade recipe.
Open the stash and PlugY's page arrows should be along the top.

Stale `.bin`/`.txt` files in `ProjectD2\data\global\excel` are the usual cause of
missing Season 14 content in testing mode — see
[troubleshooting.md](troubleshooting.md).
