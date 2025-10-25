# ShellCraft: Game Design Document

**Design Philosophy:** "Every byte matters. Every command is earned. Death is real."

This document covers the implemented game design decisions that make ShellCraft engaging, educational, and strategically interesting.

---

## 1. Core Design Pillars

### 1.1 Tactile Progression
- **Commands are physical skills** - You don't "know" `ls -l` until you've earned it through combat
- **Bytes are XP** - Every file manipulation, every enemy defeated, translates to measurable progress
- **File size = HP** - Your savefile's size IS your health (the "telomere" mechanic)

### 1.2 Meaningful Danger
- **Permadeath** - Your soul.dat gets deleted when you die
- **Strategic combat** - Can't just spam attacks; enemies hit back
- **Risk/reward grinding** - Bigger enemies give more XP but deal more damage

### 1.3 Educational Transparency
- **Real UNIX commands** - Everything works like actual shell commands
- **Progressive unlocking** - Learn simple → complex (ls before ls -l before grep)
- **Fantasy metaphors** - "Spells" and "mana" make technical concepts approachable

---

## 2. Combat System Design

### 2.1 Turn-Based Flow
Combat alternates between player and enemy turns with dramatic pacing:

```
1. Player's Turn:
   - "You swing at <enemy>..." (1s delay)
   - "You strike <enemy> for X damage!" (1s delay)
   - Show enemy HP remaining (1s delay)

2. Enemy's Turn:
   - "<Enemy> strikes back!" (1s delay)
   - "<Enemy> hits you for Y damage!"
   - Show player HP remaining (1s delay)

3. Repeat until victory or death
```

**Design Rationale:**
- **Delays create tension** - 1-second pauses give combat weight and drama
- **Alternating turns** - Prevents instant-kill cheese; makes combat strategic
- **Live HP tracking** - Players see consequences immediately

### 2.2 Damage Formulas

#### Player Damage
```perl
damage = 20 * log2(level + 2)
```

**Scaling:**
- L0: 20 bytes
- L1: 31 bytes
- L5: 56 bytes
- L10: 72 bytes
- L20: 92 bytes
- L30: 106 bytes
- L42: 118 bytes

**Design Rationale:**
- **Logarithmic scaling** - Prevents exponential power creep
- **Early-game viability** - Even L0 players can fight rats (100-500 bytes)
- **Late-game challenge** - Even L42 max-level still takes multiple turns for big enemies

#### Enemy Damage
```perl
damage = 10 + (enemy_max_hp / 50)
```

**Enemy Tiers:**
- **Rats** (100-500 bytes): 12-20 damage
- **Skeleton** (800 bytes): 26 damage
- **Daemon** (1200 bytes): 34 damage

**Design Rationale:**
- **File size = difficulty** - Bigger files are mechanically harder
- **Meaningful choice** - Players must pick appropriate enemies for their level
- **Discourages rushing** - Can't just attack the hardest enemy immediately

### 2.3 Death Mechanics

When player HP reaches 0:
1. Dramatic death screen displayed
2. `soul.dat` is **deleted** (telomeres destroyed!)
3. Game exits immediately

**Design Rationale:**
- **Real consequences** - Death isn't just a setback; it's permadeath
- **Telomere metaphor** - HP as file padding makes death literal file destruction
- **Encourages strategic play** - Players can't be reckless

---

## 3. HP System ("Telomeres")

### 3.1 The Telomere Concept

Player HP is stored as **null-byte padding** at the end of `soul.dat`.

See `SOUL_SPEC.md` for complete binary format details.

**Design Rationale:**
- **Poetic biology metaphor** - Telomeres shorten with age/damage
- **Visible in filesystem** - You can literally `ls -l` and see your HP!
- **Death is file deletion** - When telomeres are gone, the file dies
- **Unix philosophy** - "Everything is a file" taken to extreme

### 3.2 HP Scaling
```perl
max_hp = 100 + (level * 20)
```

**Level Progression:**
- L0: 100 HP
- L1: 120 HP
- L5: 200 HP
- L10: 300 HP
- L20: 500 HP
- L30: 700 HP
- L42: 940 HP

**Design Rationale:**
- **Linear scaling** - Simple, predictable growth
- **Survives multiple rats** - L0 player with 100 HP can fight ~5 rats (14 dmg each)
- **Late-game buffer** - L42 with 940 HP can survive extended combat sequences

### 3.3 HP Restoration

**On Level Up:**
- HP fully restored to new max
- Displayed: "HP restored to 120!"

**Design Rationale:**
- **Strategic leveling** - Smart players grind near level-ups for free healing
- **Comeback mechanic** - Low HP isn't permanent; level up to recover
- **Encourages persistence** - Even if you're hurt, keep fighting to level

---

## 4. XP and Progression Design

### 4.1 XP Sources

**What is XP?**
XP represents **"bytes of knowledge"** - the fundamental unit of data manipulated, removed, or created in the game world. Every byte matters.

**Combat XP:**
- **Partial damage:** Awarded each turn for damage dealt (bytes removed from enemy file)
- **Kill bonus:** Full enemy max HP awarded on victory (complete file deletion)
- **Example:** 214-byte rat gives 214 XP total (20+20+20+... per hit, then bonus)

**Quest XP:**
- Awarded in bytes (e.g., Sewer Cleanse: 500 XP)
- Represents knowledge gained from completing objectives
- See §10 for quest system details

**Design Rationale:**
- **Incremental rewards** - Even losing fights gives partial XP
- **Encourages completion** - Kill bonus rewards finishing fights
- **Natural pacing** - Can't grind infinitely; enemies must respawn/repopulate
- **Tangible abstraction** - "Bytes of knowledge" makes XP feel concrete

### 4.2 Level-Up Formula
```perl
xp_needed = fibonacci(level + 2) * 1000
```

**Thresholds:**
- L0→L1: 1000 XP (fib(2) = 1)
- L1→L2: 2000 XP (fib(3) = 2)
- L2→L3: 3000 XP (fib(4) = 3)
- L3→L4: 5000 XP (fib(5) = 5)
- L4→L5: 8000 XP (fib(6) = 8)
- L5→L6: 13000 XP (fib(7) = 13)
- L10→L11: 144000 XP (fib(12) = 144)

**Design Rationale:**
- **Fibonacci progression** - Natural scaling that feels balanced
- **Early levels accessible** - First few levels are quick (1-3k XP)
- **Later levels challenging** - Growth accelerates but remains achievable
- **Prevents level rushing** - Can't trivially reach high levels
- **Matches skill complexity** - Advanced commands (awk, sed) require more mastery

---

## 5. Command Unlocking System

### 5.1 Progression Philosophy

Commands unlock in **pedagogical order**, from simple to complex. The progression from L0 → L42 gradually teaches all essential UNIX tools.

**See LEVELS.md for the complete command unlock table and stat progression.**

**Key Principles:**
- **One unlock per level** - Each level grants exactly one new command, flag, or argument
- **Pedagogical order** - Simple → complex, following real-world learning paths
- **Flag validation** - Flags require specific unlocks, but filenames don't (see §5.3)
- **Fibonacci XP scaling** - Later levels require exponentially more experience
- **Level 42 significance** - Complete UNIX mastery + full man page access

**Progression Tiers:**
- **Tier 1 (L0-L6):** File navigation and manipulation (`ls`, `cd`, `mkdir`, `mv`, `cp`)
- **Tier 2 (L7-L11):** Text processing basics (`grep`, `sort`, `uniq`, `wc`, `head`, `tail`)
- **Tier 3 (L12-L19):** Advanced tools (`find`, `awk`, `sed`, `chmod`, `ps`, `tar`)
- **Tier 4 (L20-L30):** Scripting, advanced flags, specialized utilities
- **Tier 5 (L31-L42):** Systems mastery, networking, pipeline complexity

### 5.2 Man Page Mechanic

**"Fragmentary Knowledge" System:**

The `man` command is wrapped by the game shell to simulate incomplete understanding. Players see progressively more of each man page as they level up.

**Mechanic:**
- `man` shows a **random snippet** of the actual man page
- **Snippet size scales with level**: `visible_lines = base_lines + (level * scaling_factor)`
- At **L0**: Tiny fragments (maybe 5-10 lines from a random section)
- At **L42**: Full man page visible (complete mastery)

**Design Rationale:**
- **Progressive documentation** - Mirrors real learning (you don't understand everything at once)
- **Replayability** - Random snippets mean different runs show different info
- **Encourages experimentation** - Can't rely solely on docs; must try commands
- **Thematic fit** - "Ancient scrolls" are fragmentary until mastery achieved
- **L42 reward** - Full documentation access is a tangible benefit of max level

**Implementation Notes:**
- Shell intercepts `man` command before execution
- Selects random contiguous section of real man page
- Returns only that fragment with "..." indicators for missing content
- Higher levels = larger contiguous sections
- At L42, passes through to real `man` command unmodified

### 5.3 Flag Validation

**Key Innovation:** Flags require specific unlocks, but filenames don't.

**Examples:**
- L0: `ls /home` ✅ (filename OK)
- L0: `ls -l` ❌ (flag blocked)
- L1: `ls -l /home` ✅ (flag unlocked)
- L6: `grep pattern file.txt` ✅ (args OK)
- L6: `grep -i pattern file.txt` ❌ (flag blocked)
- L7: `grep -i pattern file.txt` ✅ (flag unlocked)

**Design Rationale:**
- **Differentiates skill** - Knowing flags is distinct from knowing base command
- **Natural learning** - Players discover why flags matter (ls -l shows permissions)
- **Prevents premature optimization** - Can't use advanced features too early

---

## 6. File-Based Enemies

### 6.1 Enemy Design

Enemies are **literal files** with:
- **HP = file size in bytes**
- **Damage taken = file truncation**
- **Death = file deletion**

**Enemy Types:**

| Enemy | Location | Size | Damage | XP | Notes |
|-------|----------|------|--------|-----|-------|
| Rat | /sewer | 100-500 | 12-20 | 100-500 | Early grinding |
| Skeleton | /crypt | 800 | 26 | 800 | Mid-game |
| Daemon | /crypt | 1200 | 34 | 1200 | Late-game |

### 6.2 Combat Mechanics

**File Truncation:**
```perl
# Enemy takes damage
truncate($filepath, $enemy_hp);  # Shrink file

# Enemy defeated
unlink($filepath);  # Delete file
```

**Design Rationale:**
- **Unix-native combat** - Uses real file operations (truncate, unlink)
- **Persistent damage** - Half-dead enemies stay damaged between sessions
- **Visible progression** - Can `ls -l` to see wounded enemies
- **Educational** - Teaches file manipulation through gameplay

---

## 7. Strategic Depth

### 7.1 Risk/Reward Decisions

**Early Game (L0-L2):**
- Fight small rats (100-200 bytes) safely
- Level up quickly with low risk
- Strategy: Grind for first few levels

**Mid Game (L5-L10):**
- Bigger rats (400-500 bytes) give more XP but hit harder
- Skeletons become viable but dangerous
- Strategy: Know when to fight vs. when to level first

**Late Game (L15+):**
- Daemons give massive XP (1200+)
- Still dangerous even at high levels
- Strategy: Use newly-unlocked commands for efficiency

### 7.2 HP Management

**Healing Sources:**
- ✅ Level up (full restore)
- ❌ No potions or rest commands
- ❌ No HP regen over time

**Consequences:**
- **Careful pull management** - Can't just chain-fight enemies
- **Level-up timing** - Fight to near level-up, then finish for heal
- **Know when to stop** - Low HP means retreat and level elsewhere

### 7.3 Command Utility

Even non-combat commands matter:

**Status monitoring:**
```bash
status              # Check HP before fighting
ls -l /home         # See soul.dat size (header + HP)
```

**World exploration:**
```bash
ls /sewer           # Count available enemies
cat /etc/scrolls/*  # Find lore hints
```

**File inspection:**
```bash
ls -l rat_1.rat     # Check enemy HP (file size)
file daemon.elf     # Identify enemy type
```

---

## 8. Thematic Consistency

### 8.1 Fantasy Metaphors

| UNIX Concept | Fantasy Equivalent | Why It Works |
|--------------|-------------------|--------------|
| Commands | Spells | Both are incantations that do things |
| Arguments | Mana/Power | Flags enhance base abilities |
| Pipes | Spell combinations | Chaining effects together |
| Files | Entities/Creatures | Everything is a tangible object |
| Bytes | XP/Life force | Fundamental unit of power |
| Telomeres | HP/Life essence | Biological metaphor for file size |
| Man pages | Ancient scrolls | Fragmented wisdom - shell wrapper shows random snippets that scale with level |

### 8.2 Tone and Voice

**In-game messages:**
- ✅ "You lack the wisdom to wield 'grep -r'. Train harder, apprentice."
- ✅ "You engage a Rat in combat!"
- ✅ "Your spellbook crumbles to dust..."
- ❌ "Error: Invalid command" (too technical)
- ❌ "You don't have permission" (breaks immersion)

**Design Rationale:**
- **Maintain fantasy** - Even errors are in-character
- **Encourage learning** - Locked commands feel like progression, not restriction
- **Playful tone** - Serious enough to care, silly enough to enjoy

---

## 9. Balance Considerations

### 9.1 Early Game

**L0 Player vs. Small Rat (100 bytes):**
- Player: 100 HP, 20 dmg
- Rat: 100 HP, 12 dmg
- **Outcome:** Player wins in 5 turns, takes 60 damage (40 HP remaining)

**L0 Player vs. 2 Rats sequentially:**
- First rat: 60 damage taken
- Second rat: 60 damage taken
- **Result:** Dies on second rat!

**Design Implication:** Must level between fights or choose smaller rats.

### 9.2 Mid Game

**L5 Player vs. Skeleton (800 bytes):**
- Player: 200 HP, 56 dmg
- Skeleton: 800 HP, 26 dmg
- **Outcome:** Player wins in 15 turns, takes 390 damage (survives barely!)

**Design Implication:** Skeletons are risky but rewarding around L5.

### 9.3 Late Game

**L10 Player vs. Daemon (1200 bytes):**
- Player: 300 HP, 72 dmg
- Daemon: 1200 HP, 34 dmg
- **Outcome:** Player wins in 17 turns, takes 578 damage (dies!)

**Design Implication:** Even at L10, daemons are deadly. Need L15+ to safely farm them.

---

## 10. Quest System Design

### 10.1 Quest Mechanics

**Quest Binary:**
- Location: `/home/quest`
- Rust binary using libsoul for soul.dat I/O
- Shows active quests with progress tracking
- Auto-accepts available quests when slots available

**Quest Slots:**
- Formula: `1 + (level / 6)`, max 8
- L0: 1 slot, L6: 2 slots, L12: 3 slots, L42: 8 slots
- Stored in soul.dat as u32[8] array
- Empty slots = 0, active quests = quest ID

**Design Rationale:**
- Gradual unlock encourages focusing on fewer quests early
- Max 8 slots prevents quest log bloat
- Slot unlocks align with major level milestones

### 10.2 Dungeon Master (Background Process)

**Purpose:** Orchestrate game world without player visibility

**Location:** `/usr/sbin/dungeon-master` (root-only, chmod 700)

**Schedule:** Runs every minute via cron

**Responsibilities:**
1. Check quest completion conditions
2. Award XP and remove completed quests
3. Repopulate world (rats, items, etc.)

**Quest Completion Flow:**
1. DM reads `/home/soul.dat` for active quests
2. Checks completion conditions (e.g., 0 rats in /sewer)
3. If complete: awards XP, removes quest, writes soul.dat
4. Player sees updated XP on next `status` or `./quest` check

**Design Rationale:**
- **Invisible orchestration** - Player can't see or kill DM
- **Stateless** - World IS the state (file counts, etc.)
- **Asynchronous rewards** - Quest completes automatically
- **Security model** - Root process, player cannot interfere

### 10.3 Quest: Sewer Cleanse

**Current Implementation:**

**Objective:** Kill all rats in `/sewer`

**Reward:** 500 XP

**Acceptance:** Auto-offered at L0 when player runs `./quest`

**Completion Detection:**
- DM counts rats: `ls /sewer/*.rat | wc -l`
- If count = 0: quest complete
- Awards 500 XP, removes quest from soul.dat

**Rat Respawn:**
- 25% chance per DM tick (every minute)
- Max 5 rats in /sewer
- Random HP: 100-500 bytes

**Design Rationale:**
- **Teaches exploration** - Player must find /sewer
- **Encourages thoroughness** - Must kill ALL rats
- **Dynamic world** - Rats respawn for future players/sessions
- **Substantial reward** - 500 XP = half of L0→L1 threshold (1000)

### 10.4 Quest Strategic Impact

**XP Efficiency:**
- Sewer Cleanse: 500 XP (guaranteed, one-time)
- 5 small rats (100 bytes each): ~500 XP total from kills
- **Combined:** ~1000 XP = instant level-up at L0

**Gameplay Flow:**
1. Player starts, runs `./quest`, sees Sewer Cleanse
2. Explores, finds /sewer with 5 rats
3. Kills all rats (gains ~500 combat XP)
4. Within 1 minute, DM awards 500 quest XP
5. Player checks `status`: Level 1! (1000 total XP)

**Strategic Depth:**
- Quest encourages complete clearing vs. selective grinding
- Respawn timer (25% chance) creates scarcity
- Multiple players competing for limited rats (future multiplayer)

---

## 11. World Design

### 11.1 Zone Structure

The player's environment is a **fake filesystem**, representing different zones:

| Directory | Description |
|-----------|-------------|
| `/home` | Player home, containing `soul.dat` (savefile) and the `quest` binary. |
| `/sewer` | Early-game rat grinding area. Contains `.rat` files (100-500 bytes). |
| `/crypt` | Mid-game challenge area with encrypted `.elf` files (skeletons, daemons). |
| `/tower` | Late-game environment for advanced text puzzles. |
| `/etc/scrolls` | Contains fragments of lore and command hints. |
| `/dev/null` | The Void — a location of philosophical significance. |

### 11.2 Zone Lore

**The Sewer:**
- Infested with rats (basic file-based enemies)
- Low-risk environment for early grinding
- First quest location (Sewer Cleanse)
- Rats respawn over time (25% per DM tick, max 5)

**The Crypt:**
- Ancient burial ground with undead `.elf` executables
- Mid-game danger zone (skeletons: 800 bytes, daemons: 1200 bytes)
- Contains encrypted files and hidden secrets
- Higher risk, higher reward

**The Tower:**
- Late-game text manipulation challenges
- Requires advanced commands (awk, sed, grep patterns)
- Lore-heavy environment with philosophical puzzles
- Final quest stages likely located here

**Scrolls of `/etc`:**
- Lore fragments about the world's history
- Philosophical musings on the nature of commands
- Cryptic hints for hidden quests
- Ancient tales of master shell wielders

**The Void (`/dev/null`):**
- Mysterious location mentioned in scrolls
- Philosophical significance (where deleted files go)
- Possible late-game quest interaction

---

## 12. Technical Constraints

### 12.1 Runtime Environment
- One Docker container per player session
- No external networking except for optional "final challenge" service
- Standard GNU tools preinstalled
- Restricted PATH filters out forbidden editors and network tools
- Alpine Linux base with minimal attack surface

### 12.2 Forbidden Commands

The following commands are blocked to maintain game integrity and security:

**Editors:** `vi`, `vim`, `nano`, `emacs` (would bypass progression system)

**Network Tools:** `curl`, `wget`, `scp`, `ssh` (except for endgame quest)

**Scripting Languages:** `python`, `ruby`, `node`, `pip` (would trivialize challenges)

**Development Tools:** `gcc`, `make`, `cargo`, `npm` (could compile arbitrary code)

**Package Managers:** `apk`, `apt`, `yum` (could install forbidden tools)

### 12.3 Allowed "Endgame" Magic

The following advanced tools are permitted for late-game progression:

- `perl -e` (one-liners only, unlocked at L20)
- `awk` (unlocked at L13)
- `sed` (unlocked at L14)
- Small subsets of `bash` builtins (loops, conditionals)
- `nc` or `telnet` (for final quest network daemon connection)

**Design Rationale:**
- `perl` one-liners teach scripting without full language access
- Text processing tools are pedagogical (core UNIX skills)
- Network commands only matter for final challenge
- Bash builtins enable quest logic without external interpreters

---

## 13. Endgame & Win Condition

### 13.1 Final Quest

The ultimate victory requires the player to:

1. **Discover a hidden hostname** - Embedded in one of the ancient file formats (`.adz`, `.dms` archives in `/tower`)
2. **Use network command** - Connect locally using `nc` to a "daemon" service running in the container
3. **Receive secret argument** - Daemon provides a cryptographic key or passphrase
4. **Invoke victory command** - Run the final spell: `ascend --key <value>` (or similar)

### 13.2 Design Rationale

**Why this works:**
- **Requires mastery of file analysis** - Player must use `file`, `strings`, `grep`, `awk` to extract hostname
- **Introduces networking concepts** - `nc` (netcat) is a fundamental hacker tool
- **Teaches command chaining** - Extracting → connecting → authenticating requires pipeline mastery
- **Ceremonial reward** - Victory command provides satisfying conclusion

**Future Expansion:**
- Multiple endings based on player choices
- Hidden "true ending" for completionists
- Speedrun mode with leaderboard integration
- Permadeath hall of fame (player souls immortalized)

---

## 14. Future Design Considerations

### 14.1 Potential Additions

**Healing mechanics:**
- Rest command (1/day heal)
- Food items (consume files for HP)
- "Meditation" in /tower (slow regen)

**Combat variety:**
- Enemy special abilities (poison, stun)
- Player equipment (damage modifiers)
- Environmental effects (crypt deals passive damage)

**Progression depth:**
- Skill trees (specialize in combat vs. utility)
- Achievement unlocks (hidden commands)
- Prestige system (restart at higher difficulty)

**World expansion:**
- Procedurally generated quests and file hierarchies
- Daily challenges with unique filesystem puzzles
- More quest types: Boss fights, riddles, CTF exploits
- Randomized lore fragments and hidden secrets

**Social features:**
- Multiplayer leaderboard (XP totals, speedruns)
- Shared world state (limited rats create competition)
- Player ghosts (see where others died)
- Cooperative quests (future)

**Educational integration:**
- Optional "learning mode" with detailed explanations
- Real UNIX tutorial integration
- AI "Lorekeeper" NPC (text-based mentor giving hints)
- Achievement-based skill certifications

### 14.2 Design Challenges

**Current issues:**
- No healing means one bad fight can end run
- Early game is repetitive (spam rats)
- No escape from combat once initiated

**Potential solutions:**
- Flee command (costs XP, saves HP)
- Daily HP restoration checkpoint
- Defensive commands (dodge, block)

---

## 12. Design Success Metrics

**A good game session should include:**
- ✅ Tension (low HP decisions)
- ✅ Progression (level ups)
- ✅ Learning (new command unlocked)
- ✅ Risk (possibility of death)
- ✅ Reward (enemy defeated, XP gained)

**What makes combat engaging:**
- Turn-based pacing (not instant)
- Visible consequences (HP tracking)
- Strategic choices (which enemy to fight)
- Real stakes (permadeath)

**What makes progression satisfying:**
- Earned unlocks (not handed out)
- Visible power growth (damage increases)
- New capabilities (commands enable new strategies)
- Meaningful milestones (level 10 feels important)

---

## 13. Design Philosophy Summary

| Principle | Implementation | Effect |
|-----------|----------------|--------|
| **Bytes are tangible** | HP = file size, XP = bytes manipulated | Makes abstract concepts concrete |
| **Commands are skills** | Progressive unlocking, validation | Learning curve mirrors real UNIX mastery |
| **Death is real** | Permadeath, file deletion | Creates meaningful tension |
| **Combat is strategic** | Turn-based, damage formulas | Prevents mindless grinding |
| **Fantasy serves education** | Spell metaphors, wizard tone | Makes technical learning approachable |
| **File system is world** | Enemies are files, locations are directories | Unix philosophy embodied |

---

**Core Design Insight:**
"By making UNIX mechanics *tactile* (you can see/touch your HP as file size), *progressive* (you earn each command), and *dangerous* (permadeath matters), ShellCraft transforms command-line learning from rote memorization into an engaging RPG experience."

---

**Version:** 1.0
**Last Updated:** 2025-10-24
**Implemented Features:** Combat, HP system, command validation, permadeath, turn-based mechanics
