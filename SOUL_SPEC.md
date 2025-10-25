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
| 0x3A   | N    | u8[]      | hp_telomere    | HP encoded as null bytes (0x00) |

**Total header size**: 58 bytes (0x3A)
**File size formula**: `58 + hp`

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

### XP (0x12-0x19)
- **Type**: 64-bit unsigned integer, little-endian
- **Size**: 8 bytes
- **Range**: 0 to 2^64-1 (~18 quintillion)
- **Purpose**: Current experience points
- **Formula**: Next level requires `fibonacci(level + 2) * 1000` XP
- **Notes**: u64 required - cumulative XP to L42 is ~1.1 trillion, exceeds u32 max

### Quest Slots (0x1A-0x39)
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

### HP Telomere (0x3A to EOF)
- **Type**: Sequence of null bytes (0x00)
- **Size**: Variable (equals current HP)
- **Purpose**: HP encoded as file size
- **Formula**:
  - Current HP = `file_size - 58`
  - Max HP = `100 + (level * 20)`
- **Design**:
  - Inspired by biological telomeres
  - HP visible via `ls -l` (file size)
  - Death = file deletion (telomeres destroyed)
  - Level up restores HP (regenerates telomeres)


## Implementation Notes

- Use little-endian byte order for all integers
- HP is derived from file size: `hp = file_size - 58`
- Set HP by padding file with null bytes to desired size
- Always validate magic bytes and version on read

## Validation Rules

### File Integrity
- File size must be ≥ 58 bytes
- Magic bytes must be "SHC!"
- Version must be ≤ current parser version
- HP (file_size - 58) must be ≤ max_hp for level

### Data Constraints
- Level: 0 ≤ level ≤ 42
- XP: 0 ≤ xp < 2^64
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
