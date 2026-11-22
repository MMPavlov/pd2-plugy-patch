# How it works (for the curious)

Back to the [README](../README.md).

`ProjectDiablo.dll` checks the command line for `-plugy` (stored as UTF-16, so a
plain-text search of the file won't find it). When present, PD2 enters a
compatibility mode and **skips installing its runtime hook table** — and one of those
hooks is what feeds item descriptions through BH's augmentation.

The awkward part is the **panel hook**: it replaces D2Client's inventory/stash panel
draw (`D2Client+0x99440`), which is the exact function PlugY patches *inside* to add
its stash pages. Both mods want the same function.

The patch:

1. **Gate** — `jne` → `nop nop`, so the hook table installs even under `-plugy`.
2. **New panel code** — packed into unused `int3` padding in `.text` (spread over
   several small gaps and chained with jumps):
   ```asm
   push esi
   call $+5 / pop eax          ; where am I? (position-independent)
   mov  esi, [eax + d]         ; PD2's module table, slot 0 = D2Client base
   ; Season 14 only: hide the mouse from D2's own panel draw, so it doesn't print
   ; its plain tooltip next to PD2's
   push [esi + MouseX] / push [esi + MouseY]
   mov  [esi + MouseX], 7FFFh / mov [esi + MouseY], 7FFFh
   lea  eax, [esi + 0x99440]   ; D2Client's panel draw (PlugY's stash pages live here)
   call eax                    ;   1. run it
   pop  [esi + MouseY] / pop  [esi + MouseX]    ; (Season 14 only)
   call <PD2 renderer>         ;   2. PD2's renderer (BH augmentation, PD2's frame)
   cmp  dword [esi + uiState+0x19*4], 0   ; stash open?
   jz   done                   ; Season 14 only: ...and on PD2's Stash category?
   call <PD2 IsStashTab>       ;   (PD2's "cmp dword [tab], 9 / setbe al / ret")
   test al, al                 ;
   jnz  buttons
   done: pop esi / ret
   buttons:                    ;   3. PlugY's stash-button routine again, on top
   mov  eax, [esi + 0x99A56]   ;      (the call PlugY redirected - read at run time)
   lea  eax, [esi + eax + 0x99A5A]
   pop  esi / jmp eax
   ```
   On Season 14 a second routine, the **click gate**, takes over the hit test that
   D2Client's stash mouse-down handler calls just before PlugY's button check:
   ```asm
   ; D2Client+0x9B885:  mov eax,ebx / call <hit test>   <- now calls the gate
   ;                    test eax,eax / je ... / mov edi,ebx / call <PlugY's check> / test eax,eax
   call <D2's hit test>        ; as before (D2Client base via the module table)
   test eax, eax / jnz ret     ; D2 takes this click itself
   call <PD2 IsStashTab> / test al, al / jz noplugy
   xor  eax, eax / ret         ; Stash category: on to PlugY's check, as before
   noplugy:
   mov  edi, ebx               ; what D2 does next...
   call <D2's own target of the call PlugY took over>
   add  dword [esp], 1Eh / ret ; ...and carry on after that call, skipping PlugY's check
   ```
   A third, the **draw gate**, does the same for PlugY's own button draw inside step 1
   (drawn under PD2's frame, its top still showed above it on the categories). It
   takes over D2's item-draw call that comes just before the call PlugY took over:
   ```asm
   ; D2Client+0x99A42:  push eax / mov byte [flag],4 / call <item draw>   <- now calls the gate
   ;                    mov [flag],bl / call <PlugY's buttons> / ...
   call <PD2 IsStashTab> / test al, al / jz nobuttons   ; (eax kept around it)
   jmp  <D2's item draw>       ; Stash category: as before, then PlugY's buttons
   nobuttons:
   call <D2's item draw>       ; with the same argument
   mov  [flag], bl             ; what D2 does next...
   call <D2's own target of the call PlugY took over>
   add  dword [esp], 0Bh / ret 4   ; ...and carry on after that call, skipping PlugY's
   ```
   Then the **handler switches**. PD2 has its own handlers for the stash's left click,
   right click, left release, mouse move, Esc and Space; putting a material in a
   category happens there. PD2 writes them into D2Client's stash message table
   (`D2Client+0xDBDB8`, rows of `{type, message, handler}`), in place of the D2
   handlers PlugY hooks into. Each row gets a switch instead:
   ```asm
   call <PD2 IsStashTab> / test al, al / jz pd2
   mov  eax, <D2's handler>    ; Stash category: D2's handler, with PlugY's buttons
   call $+5 / pop ecx / mov ecx, [ecx + d]   ; D2Client base via the module table
   add  eax, ecx / jmp eax
   pd2:
   jmp  <PD2's handler>        ; other categories: PD2's own
   ```
   And the **file switch**. PD2 checks for PlugY (the flag the gate tests) in 18 places
   around its stash. The 14 around its material storage get their `jne` turned into
   `nop`s: depositing, taking out, showing the counts, and saving and loading them.
   The 4 around PD2's own stash pages (switching them, putting items on them) stay, so
   the Stash category stays PlugY's. Saving and loading would then use
   `pd2_shared.stash`, which also holds PD2's own shared pages. So the 7 calls that
   build the path of that file and of `pd2_shared.compendium` call the file switch,
   which skips the name's first 4 characters under PlugY:
   ```asm
   call $+5 / pop eax
   cmp  byte [eax + d], 0      ; the PlugY flag (position-independent)
   jz   path
   add  dword [esp+4], 4       ; "pd2_shared.stash" -> "shared.stash"
   path: jmp <PD2's path builder>
   ```
   Last, the **tabs check**. PD2's panel draw skips its stash page tabs (P, I–IX) when
   `cmp dword [esp+24h], 0` finds its flag set, as on the categories. That `cmp` becomes
   a call to:
   ```asm
   cmp  dword [esp+28h], 0     ; its [esp+24h]: set -> skipped, as before
   jnz  done
   push eax / call $+5 / pop eax
   cmp  byte [eax + d], 0      ; under PlugY: skipped too
   pop  eax
   done: ret                   ; its jne acts on these flags
   ```
   Nothing in any of them is an absolute address, so they still work if Windows loads
   ProjectDiablo.dll or D2Client.dll somewhere other than their usual address.
3. **Redirect and cut the table** — only hooks tested alongside PlugY stay:
   - **Season 13** (35 entries): entries 0–13 stay, entry 14 (the panel hook) now
     points at the code above, and the table ends after it. Later hooks assume PD2
     owns the panel and would conflict.
   - **Season 14** (65 entries): entries 0–13 are the same as Season 13's, then 21 new
     hooks (PD2's rewrite of the party portraits), then the panel hook at entry 35.
     The panel record is moved up to entry 13, the click and draw gates go in entries
     14 and 15 (relative-call records on `D2Client+0x9B888` and `+0x99A4B`, like PD2's
     own), the handler switches in 16–21 (copies of PD2's records 52–57 for the stash
     message table, pointing at the switches), and the table ends after them. Every
     record goes in a slot that held a pointer, so Windows relocates it with the DLL.
     Entry 13 is left out because PlugY hooks
     the same call (`D2Client+0x4437C`): on Season 14 PD2 installs after PlugY, and its
     Season 14 version of that hook made every stash page button go to the next page.

Everything is located by signature at run time:

| what | how it's found |
|---|---|
| `-plugy` gate | `80 3D ?? ?? ?? ?? 00  75 ??  B9 ?? ?? ?? ??  E8`, the match whose table holds the panel hook entry (Season 14 has two matches) |
| hook table address | read from the `B9` operand above |
| panel hook entry | 20-byte record `{0, 0x000C3B18, handler, 1}`; on Season 14 the last one in the table is PD2's original |
| first 14 hooks | checked against Season 13's list — anything else is refused |
| module base table | `8B 04 C5 ?? ?? ?? 10` inside the hook installer the gate calls (Season 14 has other matches earlier in the file) |
| panel-draw target | decoded from the `call` at `D2Client.dll` RVA `0xC3B17` |
| stash-button call | `call` at `D2Client.dll` RVA `0x99A55` (the one PlugY hooks), checked |
| stash-open flag | D2Client's `GetUIState` (`83 F8 26 … 8B 04 85 ???????? C3`), UI index `0x19` |
| mouse position | the `mov eax,[MouseX]` / `mov ecx,[MouseY]` at the start of the panel draw (Season 14) |
| Stash-category check | PD2's `push 19h / call GetUIState / … / call IsStashTab / …`, its callee checked to be `cmp dword [tab], 9 / setbe al / ret` (Season 14) |
| stash click site | `mov eax,ebx / call` at `D2Client.dll` RVA `0x9B885`, then `je` to `mov edi,ebx / call` at `0x9B8A3` (PlugY's mouse-down check), checked (Season 14) |
| stash draw site | `push eax / mov byte [flag],4 / call / mov [flag],bl` at `D2Client.dll` RVA `0x99A42`, right before the stash-button call, checked (Season 14) |
| PD2's stash handlers | PD2's records after its panel record that write a handler field of D2Client's stash message table (`+0xDBDB8`); D2's handler read from that row; the left click must be among them (Season 14) |
| PD2's checks for PlugY | every `cmp byte [flag], 0/al/dl/bl` + `jne` on the gate's flag in `.text`, with at most one `mov` to or from `[ebp+d8]`/`[esp+d8]` between them: 18, of the same forms in the same order on every Season 14 build; the 4 kept are recognised by what follows them (Season 14) |
| material files | `mov reg, <"pd2_[hc_]shared.stash" / ".compendium">`, then the next call into `.text`: 7, all to one path builder, which the save and load checks lead to (Season 14) |
| stash page tabs | `cmp [esp+20h],0 / mov [esp+10h],edi / jne X / cmp [esp+24h],0 / jne X / mov eax,[img] / … / push <"…\panel\stashtabs">`, once (Season 14) |
| code caves | runs of `0xCC` at least as long as the longest instruction + a 5-byte jump, in the mapped part of `.text` |

Running it on a DLL patched by an older version upgrades it automatically, starting
from `ProjectDiablo.dll.stock-backup`.

Before writing anything the script checks every site; after writing it re-reads the
file and verifies each change, restoring the backup automatically if anything is off.
No patched `PlugY.dll` is needed — stock PlugY 14.03 works.
