# ShellCraft: Command Progression (L0 → L42)

**Design Philosophy:** Commands unlock in pedagogical order, from simple to complex. Each level grants one new command, argument, or flag, teaching real UNIX skills progressively.

---

## Command Unlock Table

| Level | Unlock | Pedagogical Goal | Related Quest |
|-------|---------|------------------|---------------|
| 0 | `ls`, `cat`, `echo`, `rm`, `cd`, `pwd`, `whoami` | **Navigation & observation** - Learn to explore filesystem, view files, understand location. Try all commands, then run `./quest` to get started. | *(Tutorial/onboarding - no quest)* |
| 1 | `ls -s` | **File sizes** - See file sizes in blocks; recognize enemies by size (file size = HP) | **"Sewer Cleanse"** (already implemented) - Use `ls -s` to scout rat HP before fighting |
| 2 | `ls -a` | **Hidden files** - Discover dotfiles and hidden directories | **"The Crack"** - Find hidden `/sewer/.crack/` directory |
| 3 | `touch` | **File creation** - Create files to solve puzzles | **"The Locked Door"** - In `.crack/`, find `locked_door` file. Create `key` file with `touch`, DM transforms door into directory portal to Under-Nix |
| 4 | `ls -R` | **Recursive listing** - Explore directory trees (and learn Ctrl+C when it hangs on circular symlinks) | **"The Symlink Maze"** - Enter Under-Nix, try `ls -R`, watch it hang on circular symlinks, realize you need better tools to navigate this |
| 5 | `ln -s` | **Symbolic links** - Create shortcuts/portals between directories | **"The Portal Home"** - Create symlink from `/home` to Under-Nix entrance for quick access (learning what symlinks are by making one) |
| 6 | `ls -l` | **File metadata** - Understand permissions, timestamps, and crucially: see where symlinks point (`->`) | **"Navigate the Maze"** - Use `ls -l` in Under-Nix to trace symlink targets and find the way through |

---

## Progression Strategy (L7-L42)

### L7-L20: Core UNIX Tools

| Level | Unlock | Pedagogical Goal | Related Quest |
|-------|---------|------------------|---------------|
| 7 | `grep` | **Text searching** - Find patterns, extract information | **"The Hidden Message"** - Extract secrets from `/etc/scrolls` |
| 8 | `sort` | **Text processing** - Organize data, understand ordering | **"The Census"** - Sort process list by PID |
| 9 | `uniq` | **Data deduplication** - Identify unique entries, filter | **"The Unique Paths"** - Find distinct daemon types |
| 10 | `wc` | **Text metrics** - Count lines, words, bytes | **"The Archive Audit"** - Measure scroll collection |
| 11 | `head` / `tail` | **Partial viewing** - Inspect start/end, monitor logs | **"The Prophecy"** - Read first lines of ancient scrolls |
| 12 | `find` | **Recursive search** - Locate files across entire filesystem | **"The Lost Artifact"** - Find hidden `.dotfiles` |
| 13 | `awk` | **Structured text processing** - Extract columns, perform calculations | **"The Ledger"** - Parse process memory usage |
| 14 | `sed` | **Stream editing** - Replace text, transform data | **"The Cipher"** - Decode ROT13 messages |
| 15 | `chmod` | **File permissions** - Understand rwx, numeric modes | **"The Locksmith"** - Fix broken permissions |
| 16 | `chown` | **Ownership** - Change file ownership (limited in game) | **"The Inheritance"** - Claim abandoned files |
| 17 | `ps` | **Process inspection** - Understand running programs | **"The Watcher"** - Identify suspicious daemons |
| 18 | `kill` | **Process management** - Terminate programs, send signals | **"The Daemon Hunt"** - Kill rogue background processes |
| 19 | `tar` | **Archiving** - Bundle files, compress data | **"The Archive"** - Extract ancient compressed lore |
| 20 | `perl -e` (one-liners only) | **Scripting basics** - Automation, text manipulation | **"The Perl Sage"** - Unlock Larry Wall's teachings |

### L21-L42: Advanced Mastery

The remaining 22 levels progressively unlock advanced functionality:

### Advanced Flags for Existing Commands
- `grep -r`, `grep -E`, `grep -v`, `grep -n`, `grep -i`
- `ls -a`, `ls -h`, `ls -t`, `ls -R`
- `find -name`, `find -type`, `find -exec`, `find -mtime`
- `tar -c`, `tar -x`, `tar -z`, `tar -j`, `tar -v`
- `chmod` numeric modes (644, 755, etc.)
- `head -n`, `tail -n`, `tail -f`
- `wc -l`, `wc -w`, `wc -c`

### Specialized Tools
- `diff` - Compare files
- `patch` - Apply differences
- `xargs` - Build and execute commands
- `cut` - Extract columns
- `tr` - Translate characters
- `paste` - Merge lines
- `join` - Join files on common fields
- `comm` - Compare sorted files
- `tee` - Split output streams
- `strings` - Extract printable strings
- `hexdump` / `xxd` - Binary file inspection
- `base64` - Encoding/decoding
- `file` - Identify file types

### Process Management
- `bg` - Background jobs
- `fg` - Foreground jobs
- `jobs` - List jobs
- `nohup` - Run immune to hangups
- `top` - Process monitor
- `pgrep` - Process grep
- `pkill` - Kill by name

### Network Commands (Endgame)
- `nc` (netcat) - Network connections
- `telnet` - Remote connections
- Used only for final quest

### Pipeline Mastery
- Complex multi-command chains
- Conditional execution (`&&`, `||`)
- Subshells and command substitution
- Redirection mastery (`>`, `>>`, `2>&1`, `<`)

---

## Level 42: Complete Mastery

**The Answer to Life, the Universe, and Everything**

At L42, the player achieves complete UNIX mastery:

- ✅ All commands unlocked
- ✅ All flags and arguments available
- ✅ Full man page access (no fragmentation)
- ✅ Maximum damage output (118 bytes)
- ✅ Maximum HP (940 HP)
- ✅ All 8 quest slots available
- ✅ Ready for final quest and ascension

---

## Quest Slot Progression

Quest slots unlock as you level up, allowing you to juggle more objectives:

| Level Range | Quest Slots | Formula |
|-------------|-------------|---------|
| L0-L5 | 1 slot | Base |
| L6-L11 | 2 slots | 1 + (level / 6) |
| L12-L17 | 3 slots | |
| L18-L23 | 4 slots | |
| L24-L29 | 5 slots | |
| L30-L35 | 6 slots | |
| L36-L41 | 7 slots | |
| L42 | 8 slots (max) | Cap |

---

## Man Page Visibility Progression

The `man` command shows progressively more of each man page as you level:

| Level Range | Approximate Visibility | Example |
|-------------|------------------------|---------|
| L0-L5 | ~5-10 lines | Tiny random snippets |
| L6-L15 | ~20-40 lines | Substantial fragments |
| L16-L30 | ~50-80 lines | Major sections visible |
| L31-L41 | ~100-150 lines | Nearly complete |
| L42 | Full man page | Complete mastery |

**Formula:** `visible_lines = base_lines + (level * scaling_factor)`

At L42, the shell passes through to the real `man` command unmodified.

---

## Stat Progression

### Damage Output
```
damage = 20 * log2(level + 2)
```

| Level | Damage (bytes) |
|-------|----------------|
| 0 | 20 |
| 1 | 31 |
| 5 | 56 |
| 10 | 72 |
| 20 | 92 |
| 30 | 106 |
| 42 | 118 |

### Health Points
```
max_hp = 100 + (level * 20)
```

| Level | Max HP |
|-------|--------|
| 0 | 100 |
| 1 | 120 |
| 5 | 200 |
| 10 | 300 |
| 20 | 500 |
| 30 | 700 |
| 42 | 940 |

### XP Requirements
```
xp_needed = fibonacci(level + 2) * 1000
```

| Level | XP to Next | Fibonacci |
|-------|------------|-----------|
| L0→L1 | 1,000 | fib(2) = 1 |
| L1→L2 | 2,000 | fib(3) = 2 |
| L2→L3 | 3,000 | fib(4) = 3 |
| L3→L4 | 5,000 | fib(5) = 5 |
| L4→L5 | 8,000 | fib(6) = 8 |
| L5→L6 | 13,000 | fib(7) = 13 |
| L10→L11 | 144,000 | fib(12) = 144 |
| L20→L21 | 17,711,000 | fib(22) = 17,711 |
| L41→L42 | ~433,494,437,000 | fib(43) = 433,494,437 |

**Note:** Late-game XP requirements become astronomical, encouraging strategic quest completion rather than pure grinding.

---

## Design Notes

### Flag Validation System

**Key Innovation:** Flags require specific unlocks, but filenames don't.

**Examples:**
- L0: `ls /home` ✅ (filename OK)
- L0: `ls -l` ❌ (flag blocked)
- L1: `ls -l /home` ✅ (flag unlocked)
- L6: `grep pattern file.txt` ✅ (args OK)
- L6: `grep -i pattern file.txt` ❌ (flag blocked until L7+)

### Pedagogical Order Rationale

The unlock order follows **real-world learning progression**:

1. **Tier 1 (L0-L6):** File navigation and manipulation
2. **Tier 2 (L7-L11):** Text processing basics
3. **Tier 3 (L12-L19):** Advanced searching and archiving
4. **Tier 4 (L20-L30):** Scripting and automation
5. **Tier 5 (L31-L42):** Systems mastery and networking

Each tier builds on the previous, ensuring players develop proper mental models.

---

**Version:** 1.0
**Last Updated:** 2025-10-24
**Status:** L0-L20 finalized, L21-L42 in design
