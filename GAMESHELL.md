# ShellCraft: Game Specification (v0.1)

## 1. Overview

**ShellCraft** is a fantasy-themed UNIX shell RPG and teaching environment.  
Players inhabit a minimalistic UNIX-like world where they “grind” system commands to gain experience, unlock arguments, and advance their mastery of the shell.  
Gameplay unfolds entirely through a command-line interface — ideally via a custom shell or restricted Docker environment.

The tone is playful, mysterious, and pedagogical: the player learns *real* UNIX commands, but within a gamified fantasy world inspired by classic RPG progression and hacker CTF puzzles.

---

## 2. Core Concept

The player starts with a primitive shell containing only the most basic commands (`ls`, `cat`, `echo`, `rm`, `cd`, etc.).  
By executing these commands effectively — exploring directories, manipulating files, and solving simple text or filesystem-based puzzles — they gain XP (“bytes of knowledge”) and level up.  

Each level unlocks **one new command or argument**, gradually teaching real command-line skills.  
By level 42, the player has mastered an entire set of essential UNIX tools.

---

## 3. Gameplay Mechanics

### 3.1 Input Loop

- Player interacts via a restricted shell prompt (e.g., `$>`).  
- Commands are parsed and validated against the player’s current unlock level.  
- Unauthorized commands or arguments trigger in-world feedback, e.g.  
  “You lack the wisdom to wield `grep -r`. Train harder, apprentice.”

### 3.2 XP System

- **XP Unit:** Bytes removed, created, or manipulated.  
- **Combat XP:** Earned by “fighting” files (e.g., removing or truncating `.rat` files in `/sewer`).  
  Example: `rm 1.rat` → truncates the file by a level-scaled number of bytes.  
  XP gained = bytes truncated.  
- **Quest XP:** Awarded for completing higher-order objectives (e.g., extracting hidden data).  
  Scaled relative to XP-per-byte metrics (e.g., “12kB of XP”).

### 3.3 Leveling

- Player level determines all skill proficiencies.
- Level-up thresholds follow a Fibonacci progression:
  XP for next level = `fibonacci(level + 2) * 1000`
- Damage and XP scaling are logarithmic to keep files small.

### 3.4 Combat System

- “Enemies” are files (e.g., `/sewer/rat_1`, `/crypt/daemon.elf`).  
- Removing or transforming files deals “damage” measured in bytes.  
- Instead of deleting files outright, `rm` truncates them:  
  `truncate($file, $remaining_bytes)`  
- When file size reaches zero, it is “vanquished” and removed.

---

## 4. Command Progression

| Level | Unlock | Description |
|--------|---------|-------------|
| 0 | `ls`, `cat`, `echo`, `rm`, `cd`, `pwd`, `whoami` | Basic commands, no arguments |
| 1 | `ls -l` | Reveals file details (“Inspect deeper into reality”) |
| 2 | `mkdir` | Build directories (“Shape the world”) |
| 3 | `rmdir` | Destroy empty directories |
| 4 | `touch` | Create files (“Summon fragments into being”) |
| 5 | `mv` | Move/rename files |
| 6 | `cp` | Copy files |
| 7 | `grep` | Search text (“Divine hidden meanings”) |
| 8 | `sort` | Order chaos |
| 9 | `uniq` | Distill essence |
| 10 | `wc` | Weigh the text’s mass |
| 11 | `head` / `tail` | Peer into the beginnings and ends of things |
| 12 | `find` | Seek beyond sight |
| 13 | `awk` | Patterned spellcraft (structured manipulation) |
| 14 | `sed` | Transform incantations |
| 15 | `chmod` | Control permissions (“Invoke true ownership”) |
| 16 | `chown` | Bind entities to your name |
| 17 | `ps` | Sense processes |
| 18 | `kill` | Exorcise processes |
| 19 | `tar` | Contain multitudes |
| 20 | `perl -e` (one-liners only) | True spellcraft — the arcane mastery of the shell |

*(Further levels up to 42 may refine arguments and special flags.)*

---

## 5. Experience & Scaling

### 5.1 Damage and XP Formula
  damage_bytes = base_damage * log2(level + 2)
  xp_gain = damage_bytes

### 5.2 Quest XP
- Rewards specified in “kB of XP”.
- Examples:
  - “Purge the `/sewer`” quest: 10 kB XP.
  - “Extract the hidden message from `corrupted.adz`”: 20 kB XP.

---

## 6. Game Filesystem

The player’s environment is a **fake filesystem**, representing different zones:

| Directory | Description |
|------------|-------------|
| `/home` | Player home, containing `soul.dat` (savefile). |
| `/sewer` | Early-game rat grinding area. Contains `.rat` files. |
| `/crypt` | Mid-game challenge area with encrypted `.elf` files. |
| `/tower` | Late-game environment for advanced text puzzles. |
| `/etc/scrolls` | Contains fragments of lore and command hints. |
| `/dev/null` | The Void — a location of philosophical significance. |

---

## 7. Save System

### 7.1 File Format: `soul.dat`

Binary savefile representing player progress.
Stored in the player's `/home` directory.

| Offset | Field | Description |
|---------|--------|-------------|
| `0x00–0x03` | Magic bytes | “SHC!” (ShellCraft Header) |
| `0x04–0x05` | Version | 16-bit integer |
| `0x06–0x0F` | Checksum | XOR or CRC32 of payload |
| `0x10–0x1F` | Player level | Obfuscated (e.g. XOR with salt) |
| `0x20–0x3F` | XP counter | 64-bit little-endian |
| `0x40–…` | Learned commands bitmap | One bit per unlock |
| `…` | Lore fragments | Optional ASCII-encoded text blocks |

### 7.2 Encoding
- Endianness may vary per version.  
- All values XORed with player-specific salt derived from username.  
- "Corrupted" saves can still be partially read via `strings soul.dat`.

---

## 8. Infrastructure

### 8.1 Runtime Environment
- One Docker container per player.  
- No external networking except for an optional “final challenge” service.  
- Standard GNU tools preinstalled; restricted PATH filters out forbidden editors and network tools.

### 8.2 Forbidden Commands
`vi`, `vim`, `nano`, `emacs`, `curl`, `wget`, `scp`, `ssh`, `python`, `ruby`, `gcc`, `make`, `node`, `pip`, and any binaries capable of installing packages or fetching remote code.

### 8.3 Allowed “Endgame” Magic
`perl` (one-liners only), `awk`, `sed`, and small subsets of `bash` builtins.

---

## 9. Thematic Layer

- “XP” = bytes of data manipulated.  
- “Mana” = available command arguments.  
- “Spells” = command combinations (pipelines).  
- “Artifacts” = special files (e.g., `.adz`, `.dms`) that contain encoded secrets.  
- “Scrolls” = man pages, incomplete until higher levels (“fragmentary knowledge”).  

Low-level players see corrupted man pages — at higher levels, fragments are restored.

---

## 10. Win Condition

The final quest requires the player to:
1. Discover a hidden hostname in one of the ancient file formats.
2. Use a network command (e.g., `nc`) to connect locally to a “daemon” service.
3. Receive a secret argument or key to invoke a final command.
4. Run the victory command successfully (`ascend --key <value>` or similar).

---

## 11. Future Extensions

- Procedurally generated quests and file hierarchies.  
- Multiplayer leaderboard (XP totals, speedruns).  
- “Daily challenges” with unique filesystem puzzles.  
- Integration with real UNIX tutorials (opt-in learning mode).  
- Optional AI “Lorekeeper” NPC (text-based mentor giving hints).

---

## 12. Design Goals Summary

| Goal | Description |
|------|--------------|
| **Educational** | Teach real UNIX tools through progressive unlocks. |
| **Aesthetic** | Blend fantasy, hacker culture, and retro computing. |
| **Contained** | Runs safely in isolated Docker containers. |
| **Tactile** | Every byte of data manipulated *matters*. |
| **Replayable** | Randomized files and hidden lore. |
| **Expandable** | Future skill trees, more commands, and secret “schools” of ShellCraft. |