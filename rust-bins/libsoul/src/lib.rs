//! ShellCraft Soul File I/O Library
//!
//! This library provides safe, zero-copy reading and writing of soul.dat files
//! according to SOUL_SPEC.md.
//!
//! # Format
//! - Magic bytes: "SHC!" (4 bytes)
//! - Version: u16 LE (2 bytes)
//! - Checksum: u64 LE (8 bytes, currently unused)
//! - Level: u32 LE (4 bytes)
//! - XP: u32 LE (4 bytes)
//! - Quest slots: [u32; 8] LE (32 bytes)
//! - HP telomere: null bytes (variable length)
//!
//! Total header: 54 bytes
//! File size = 54 + HP

use std::fs::File;
use std::io::{self, Read, Seek, SeekFrom, Write};
use std::path::Path;

/// Magic bytes identifying a soul file
pub const MAGIC: &[u8; 4] = b"SHC!";

/// Current soul file format version
pub const VERSION: u16 = 1;

/// Size of the fixed header (everything except HP telomere)
pub const HEADER_SIZE: u64 = 62;

/// Maximum player level
pub const MAX_LEVEL: u32 = 42;

/// Number of quest slots
pub const QUEST_SLOTS: usize = 8;

/// Player soul data
#[derive(Debug, Clone, PartialEq)]
pub struct Soul {
    /// Player level (0-42)
    pub level: u32,

    /// Current experience points
    pub xp: u64,

    /// Active quest IDs (0 = empty slot)
    pub quests: [u32; QUEST_SLOTS],

    /// Current hit points (encoded as file size)
    pub hp: u32,
}

impl Soul {
    /// Create a new soul with default values
    pub fn new() -> Self {
        Self {
            level: 0,
            xp: 0,
            quests: [0; QUEST_SLOTS],
            hp: Self::max_hp(0),
        }
    }

    /// Calculate maximum HP for a given level
    ///
    /// Formula: 100 + (level * 20)
    pub fn max_hp(level: u32) -> u32 {
        100 + (level * 20)
    }

    /// Get maximum HP for this soul's level
    pub fn max_hp_for_level(&self) -> u32 {
        Self::max_hp(self.level)
    }

    /// Calculate XP required for next level
    ///
    /// Formula: 1000 * (2.0 ^ level)
    pub fn xp_for_next_level(&self) -> u64 {
        (1000.0 * 2.0_f64.powi(self.level as i32)) as u64
    }

    /// Get number of quest slots unlocked at this level
    ///
    /// Unlocking: 1 slot at L0, +1 every 6 levels, max 8 at L42
    pub fn unlocked_quest_slots(&self) -> usize {
        let slots = 1 + (self.level / 6) as usize;
        slots.min(QUEST_SLOTS)
    }

    /// Check if a quest slot index is unlocked
    pub fn is_quest_slot_unlocked(&self, slot: usize) -> bool {
        slot < self.unlocked_quest_slots()
    }

    /// Get active quests (non-zero quest IDs)
    pub fn active_quests(&self) -> Vec<u32> {
        self.quests
            .iter()
            .take(self.unlocked_quest_slots())
            .copied()
            .filter(|&q| q != 0)
            .collect()
    }

    /// Check if a quest is active
    pub fn has_quest(&self, quest_id: u32) -> bool {
        self.active_quests().contains(&quest_id)
    }

    /// Add a quest to the first available slot
    ///
    /// Returns Ok(slot_index) if successful, Err if no slots available
    pub fn add_quest(&mut self, quest_id: u32) -> Result<usize, SoulError> {
        if quest_id == 0 {
            return Err(SoulError::InvalidQuest);
        }

        if self.has_quest(quest_id) {
            return Err(SoulError::QuestAlreadyActive);
        }

        let unlocked = self.unlocked_quest_slots();
        for i in 0..unlocked {
            if self.quests[i] == 0 {
                self.quests[i] = quest_id;
                return Ok(i);
            }
        }

        Err(SoulError::NoQuestSlots)
    }

    /// Remove a quest from all slots
    ///
    /// Returns true if the quest was found and removed
    pub fn remove_quest(&mut self, quest_id: u32) -> bool {
        let mut removed = false;
        for quest in &mut self.quests {
            if *quest == quest_id {
                *quest = 0;
                removed = true;
            }
        }
        removed
    }

    /// Validate soul data
    pub fn validate(&self) -> Result<(), SoulError> {
        if self.level > MAX_LEVEL {
            return Err(SoulError::InvalidLevel(self.level));
        }

        let max_hp = self.max_hp_for_level();
        if self.hp > max_hp {
            return Err(SoulError::InvalidHP {
                hp: self.hp,
                max: max_hp
            });
        }

        Ok(())
    }

    /// Load soul from file
    pub fn load<P: AsRef<Path>>(path: P) -> Result<Self, SoulError> {
        let mut file = File::open(path)?;

        // Get file size to calculate HP
        let file_size = file.metadata()?.len();

        if file_size < HEADER_SIZE {
            return Err(SoulError::FileTooSmall(file_size));
        }

        // Read and validate magic bytes
        let mut magic = [0u8; 4];
        file.read_exact(&mut magic)?;
        if &magic != MAGIC {
            return Err(SoulError::InvalidMagic(magic));
        }

        // Read version
        let mut version_buf = [0u8; 2];
        file.read_exact(&mut version_buf)?;
        let version = u16::from_le_bytes(version_buf);

        if version != VERSION {
            return Err(SoulError::UnsupportedVersion(version));
        }

        // Skip checksum (8 bytes)
        file.seek(SeekFrom::Current(8))?;

        // Read level
        let mut level_buf = [0u8; 4];
        file.read_exact(&mut level_buf)?;
        let level = u32::from_le_bytes(level_buf);

        // Read XP
        let mut xp_buf = [0u8; 8];
        file.read_exact(&mut xp_buf)?;
        let xp = u64::from_le_bytes(xp_buf);

        // Read quest slots
        let mut quests = [0u32; QUEST_SLOTS];
        for quest in &mut quests {
            let mut quest_buf = [0u8; 4];
            file.read_exact(&mut quest_buf)?;
            *quest = u32::from_le_bytes(quest_buf);
        }

        // HP is file size minus header
        let hp = (file_size - HEADER_SIZE) as u32;

        let soul = Soul {
            level,
            xp,
            quests,
            hp,
        };

        // Validate and clamp HP if needed
        soul.validate()?;

        Ok(soul)
    }

    /// Save soul to file
    pub fn save<P: AsRef<Path>>(&self, path: P) -> Result<(), SoulError> {
        // Validate before saving
        self.validate()?;

        let mut file = File::create(path)?;

        // Write magic
        file.write_all(MAGIC)?;

        // Write version
        file.write_all(&VERSION.to_le_bytes())?;

        // Write checksum (placeholder)
        file.write_all(&0u64.to_le_bytes())?;

        // Write level
        file.write_all(&self.level.to_le_bytes())?;

        // Write XP
        file.write_all(&self.xp.to_le_bytes())?;

        // Write quest slots
        for quest in &self.quests {
            file.write_all(&quest.to_le_bytes())?;
        }

        // Write padding
        file.write_all(&[0u8; 4])?;

        // Write HP telomere (null bytes)
        let hp_padding = vec![0u8; self.hp as usize];
        file.write_all(&hp_padding)?;

        file.sync_all()?;

        Ok(())
    }
}

impl Default for Soul {
    fn default() -> Self {
        Self::new()
    }
}

/// Soul file errors
#[derive(Debug)]
pub enum SoulError {
    /// I/O error
    Io(io::Error),

    /// File too small to be valid
    FileTooSmall(u64),

    /// Invalid magic bytes
    InvalidMagic([u8; 4]),

    /// Unsupported version
    UnsupportedVersion(u16),

    /// Invalid level (> 42)
    InvalidLevel(u32),

    /// Invalid HP for level
    InvalidHP { hp: u32, max: u32 },

    /// Invalid quest ID (0)
    InvalidQuest,

    /// Quest already active
    QuestAlreadyActive,

    /// No available quest slots
    NoQuestSlots,
}

impl std::fmt::Display for SoulError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Io(e) => write!(f, "I/O error: {}", e),
            Self::FileTooSmall(size) => write!(f, "File too small: {} bytes (need >= 54)", size),
            Self::InvalidMagic(magic) => write!(f, "Invalid magic bytes: {:?}", magic),
            Self::UnsupportedVersion(v) => write!(f, "Unsupported version: {}", v),
            Self::InvalidLevel(l) => write!(f, "Invalid level: {} (max 42)", l),
            Self::InvalidHP { hp, max } => write!(f, "Invalid HP: {} (max {} for level)", hp, max),
            Self::InvalidQuest => write!(f, "Invalid quest ID (cannot be 0)"),
            Self::QuestAlreadyActive => write!(f, "Quest already active"),
            Self::NoQuestSlots => write!(f, "No available quest slots"),
        }
    }
}

impl std::error::Error for SoulError {}

impl From<io::Error> for SoulError {
    fn from(e: io::Error) -> Self {
        Self::Io(e)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;

    #[test]
    fn test_new_soul() {
        let soul = Soul::new();
        assert_eq!(soul.level, 0);
        assert_eq!(soul.xp, 0);
        assert_eq!(soul.quests, [0; 8]);
        assert_eq!(soul.hp, 100); // L0 max HP
    }

    #[test]
    fn test_max_hp() {
        assert_eq!(Soul::max_hp(0), 100);
        assert_eq!(Soul::max_hp(1), 120);
        assert_eq!(Soul::max_hp(5), 200);
        assert_eq!(Soul::max_hp(10), 300);
        assert_eq!(Soul::max_hp(42), 940);
    }

    #[test]
    fn test_unlocked_quest_slots() {
        let mut soul = Soul::new();

        soul.level = 0;
        assert_eq!(soul.unlocked_quest_slots(), 1);

        soul.level = 5;
        assert_eq!(soul.unlocked_quest_slots(), 1);

        soul.level = 6;
        assert_eq!(soul.unlocked_quest_slots(), 2);

        soul.level = 12;
        assert_eq!(soul.unlocked_quest_slots(), 3);

        soul.level = 42;
        assert_eq!(soul.unlocked_quest_slots(), 8);
    }

    #[test]
    fn test_quest_management() {
        let mut soul = Soul::new();

        // Add quest
        assert!(soul.add_quest(1).is_ok());
        assert!(soul.has_quest(1));
        assert_eq!(soul.active_quests(), vec![1]);

        // Can't add duplicate
        assert!(soul.add_quest(1).is_err());

        // Can't add quest 0
        assert!(soul.add_quest(0).is_err());

        // Remove quest
        assert!(soul.remove_quest(1));
        assert!(!soul.has_quest(1));
        assert_eq!(soul.active_quests(), vec![]);
    }

    #[test]
    fn test_save_load_roundtrip() {
        let tmp = std::env::temp_dir().join("test_soul.dat");

        let mut original = Soul::new();
        original.level = 5;
        original.xp = 750;
        original.hp = 200;
        original.quests[0] = 42;

        original.save(&tmp).unwrap();
        let loaded = Soul::load(&tmp).unwrap();

        assert_eq!(original, loaded);

        std::fs::remove_file(tmp).ok();
    }

    #[test]
    fn test_invalid_magic() {
        let tmp = std::env::temp_dir().join("test_bad_magic.dat");
        let mut file = File::create(&tmp).unwrap();
        file.write_all(b"BAD!").unwrap();
        file.write_all(&vec![0u8; 58]).unwrap();

        let result = Soul::load(&tmp);
        assert!(matches!(result, Err(SoulError::InvalidMagic(_))));

        std::fs::remove_file(tmp).ok();
    }
}
