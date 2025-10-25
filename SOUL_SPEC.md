# ShellCraft Soul Format Specification

**File**: `soul.dat`
**Location**: `/home/soul.dat`
**Encoding**: Binary, little-endian
**Current Version**: 1

## Overview

The soul is a binary file that stores player state. The file size itself encodes HP as "telomeres" - null byte padding at the end of the file.

## Binary Layout

| Offset | Size | Type      | Field          | Description |
|--------|------|-----------|----------------|-------------|
| 0x00   | 4    | char[4]   | magic          | Magic bytes: "SHC!" (0x53 0x48 0x43 0x21) |
| 0x04   | 2    | u16 LE    | version        | Format version number (currently 1) |
| 0x06   | 8    | u64 LE    | checksum       | Reserved for future use (currently 0) |
| 0x0E   | 4    | u32 LE    | level          | Player level (0-42) |
| 0x12   | 8    | u64 LE    | xp             | Current experience points |
| 0x1A   | 32   | u32[8] LE | quest_slots    | Active quest IDs (0 = empty slot) |
| 0x3E   | N    | u8[]      | hp_telomere    | HP encoded as null bytes (0x00) |

**Total header size**: 62 bytes (0x3E)
**File size formula**: `62 + hp`

## Field Details

### Magic Bytes (0x00-0x03)
- **Value**: ASCII "SHC!" (ShellCraft)
- **Purpose**: File format identification
- **Validation**: Must exactly match, otherwise file is corrupted

### Version (0x04-0x05)
- **Type**: 16-bit unsigned integer, little-endian
- **Current**: 1
- **Purpose**: Allow future format changes while maintaining backward compatibility

### Checksum (0x06-0x0D)
- **Type**: 64-bit unsigned integer, little-endian
- **Current**: 0 (reserved, not implemented)
- **Future**: May implement CRC64 or similar

### Level (0x0E-0x11)
- **Type**: 32-bit unsigned integer, little-endian
- **Range**: 0-42
- **Purpose**: Player's current level
- **Notes**: Level determines command unlocks and max HP

### XP (0x12-0x15)
- **Type**: 32-bit unsigned integer, little-endian
- **Range**: 0 to 2^32-1
- **Purpose**: Current experience points
- **Formula**: Next level requires `100 * (1.5 ^ level)` XP

### Quest Slots (0x16-0x35)
- **Type**: Array of 8 u32 LE integers
- **Size**: 32 bytes total (8 slots × 4 bytes)
- **Values**:
  - 0 = empty slot
  - 1-N = active quest ID
- **Purpose**: Track up to 8 active quests
- **Unlocking**:
  - Start with 1 slot at level 0
  - Gain 1 slot every 6 levels
  - Max 8 slots at level 42

### HP Telomere (0x36 to EOF)
- **Type**: Sequence of null bytes (0x00)
- **Size**: Variable (equals current HP)
- **Purpose**: HP encoded as file size
- **Formula**:
  - Current HP = `file_size - 54`
  - Max HP = `100 + (level * 20)`
- **Design**:
  - Inspired by biological telomeres
  - HP visible via `ls -l` (file size)
  - Death = file deletion (telomeres destroyed)
  - Level up restores HP (regenerates telomeres)

## Example Files

### New Level 0 Player (100 HP)
```
Offset    Bytes                                       Description
------    -----                                       -----------
0x00      53 48 43 21                                 Magic "SHC!"
0x04      01 00                                       Version 1
0x06      00 00 00 00 00 00 00 00                     Checksum (unused)
0x0E      00 00 00 00                                 Level 0
0x12      00 00 00 00                                 XP 0
0x16      00 00 00 00 ... (32 bytes)                  Quest slots (all empty)
0x36      00 00 00 ... (100 bytes)                    HP telomere (100 HP)

Total size: 154 bytes (54 header + 100 HP)
```

### Level 5 Player (200 HP, 1 Active Quest)
```
Offset    Bytes                                       Description
------    -----                                       -----------
0x00      53 48 43 21                                 Magic "SHC!"
0x04      01 00                                       Version 1
0x06      00 00 00 00 00 00 00 00                     Checksum (unused)
0x0E      05 00 00 00                                 Level 5
0x12      F8 02 00 00                                 XP 760
0x16      01 00 00 00                                 Quest 1 active
0x1A      00 00 00 00 ... (28 bytes)                  Quest slots 2-8 (empty)
0x36      00 00 00 ... (200 bytes)                    HP telomere (200 HP)

Total size: 254 bytes (54 header + 200 HP)
```

## Reading the File

### Perl Example
```perl
open my $fh, '<', '/home/soul.dat' or die $!;
binmode $fh;

# Get file size for HP
my $file_size = -s '/home/soul.dat';

# Read header
my $magic;
read($fh, $magic, 4);
die "Invalid magic" unless $magic eq 'SHC!';

my $version_bytes;
read($fh, $version_bytes, 2);
my $version = unpack('S<', $version_bytes);

# Skip checksum
seek($fh, 14, 0);

# Read player data
my $data;
read($fh, $data, 8);
my ($level, $xp) = unpack('L<L<', $data);

# Read quest slots
read($fh, $data, 32);
my @quests = unpack('L<8', $data);

# HP is file size minus header
my $hp = $file_size - 54;

close $fh;
```

### Rust Example
```rust
use std::fs::File;
use std::io::{Read, Seek, SeekFrom};

let mut file = File::open("/home/soul.dat")?;
let file_size = file.metadata()?.len();

// Read magic
let mut magic = [0u8; 4];
file.read_exact(&mut magic)?;
assert_eq!(&magic, b"SHC!");

// Read version
let mut version_buf = [0u8; 2];
file.read_exact(&mut version_buf)?;
let version = u16::from_le_bytes(version_buf);

// Skip to player data (offset 14)
file.seek(SeekFrom::Start(14))?;

// Read level and XP
let mut level_buf = [0u8; 4];
file.read_exact(&mut level_buf)?;
let level = u32::from_le_bytes(level_buf);

let mut xp_buf = [0u8; 4];
file.read_exact(&mut xp_buf)?;
let xp = u32::from_le_bytes(xp_buf);

// Read quest slots
let mut quests = [0u32; 8];
for i in 0..8 {
    let mut quest_buf = [0u8; 4];
    file.read_exact(&mut quest_buf)?;
    quests[i] = u32::from_le_bytes(quest_buf);
}

// HP is file size minus header
let hp = file_size - 54;
```

## Writing the File

### Key Points
- **Always** write the full 54-byte header
- Set HP by padding with null bytes
- Use little-endian byte order for all integers
- Truncate to 54 + hp bytes to set HP

### Perl Example
```perl
open my $fh, '>', '/home/soul.dat' or die $!;
binmode $fh;

# Write header
print $fh 'SHC!';                           # Magic
print $fh pack('S<', 1);                    # Version
print $fh pack('Q<', 0);                    # Checksum
print $fh pack('L<L<', $level, $xp);        # Level, XP
print $fh pack('L<8', @quests);             # Quest slots

# Write HP telomere
my $hp_bytes = "\0" x $hp;
print $fh $hp_bytes;

close $fh;
```

### Rust Example
```rust
use std::fs::File;
use std::io::Write;

let mut file = File::create("/home/soul.dat")?;

// Write header
file.write_all(b"SHC!")?;                   // Magic
file.write_all(&1u16.to_le_bytes())?;       // Version
file.write_all(&0u64.to_le_bytes())?;       // Checksum
file.write_all(&level.to_le_bytes())?;      // Level
file.write_all(&xp.to_le_bytes())?;         // XP

// Write quest slots
for quest_id in quests {
    file.write_all(&quest_id.to_le_bytes())?;
}

// Write HP telomere
let hp_padding = vec![0u8; hp as usize];
file.write_all(&hp_padding)?;

file.sync_all()?;
```

## Validation Rules

### File Integrity
- File size must be ≥ 54 bytes
- Magic bytes must be "SHC!"
- Version must be ≤ current parser version
- HP (file_size - 54) must be ≤ max_hp for level

### Data Constraints
- Level: 0 ≤ level ≤ 42
- XP: 0 ≤ xp < 2^32
- Quest slots: Each slot is 0 or a valid quest ID
- HP: 0 ≤ hp ≤ (100 + level * 20)

### Corruption Handling
If validation fails:
- Perl: Return new player with default values
- Rust: Return error or default player
- Never crash the game on corrupted save

## Version History

### Version 1 (Current)
- Initial format
- Magic bytes "SHC!"
- Level, XP, quest slots, HP telomere
- 54-byte fixed header

### Future Versions
Potential additions:
- Checksum implementation
- Inventory items
- Achievement flags
- Timestamp fields
- Statistics tracking

## Design Notes

### Why File Size = HP?
- **Poetic**: Biological telomere metaphor
- **Visible**: Players can see HP via `ls -l`
- **Tactile**: HP literally changes file size
- **Death**: Deleting file = death is literal
- **Unix Philosophy**: Everything is a file

### Quest Slot Design
- Fixed 8 slots (32 bytes) keeps header size predictable
- 0 = empty is simple and unambiguous
- Array allows direct indexing
- Future: Could add quest state flags

### Little-Endian Choice
- Most common architecture (x86, ARM)
- Matches Rust/C default on common platforms
- Perl pack/unpack supports it well
- Simpler than making format architecture-agnostic

## Compatibility

This format is designed to work across:
- **Perl 5.38+** (Alpine Linux package)
- **Rust 1.70+** (Alpine apk stable)
- **Any architecture** that Docker supports

Implementations must handle byte order explicitly (little-endian) to ensure cross-platform compatibility.
