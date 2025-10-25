mod quest_data;

use libsoul::Soul;
use quest_data::{load_quests, QuestData};
use std::collections::HashMap;
use std::fs;
use std::process;

const SOUL_PATH: &str = "/home/soul.dat";
const SEWER_PATH: &str = "/sewer";

// Quest IDs
const QUEST_SEWER_CLEANSE: u32 = 1;
const QUEST_THE_CRACK: u32 = 2;
const QUEST_LOCKED_DOOR: u32 = 3;
const QUEST_PORTAL_HOME: u32 = 4;
const QUEST_NAVIGATE_MAZE: u32 = 5;

fn main() {
    // Load quest data at startup
    let quests = load_quests();

    // Load soul
    let mut soul = match Soul::load(SOUL_PATH) {
        Ok(s) => s,
        Err(e) => {
            eprintln!("Error: Cannot read your soul: {}", e);
            process::exit(1);
        }
    };

    println!();
    println!("=== Quest Journal ===");
    println!();

    // Show active quests
    let active = soul.active_quests();
    if active.is_empty() {
        println!("No active quests.");
    } else {
        for quest_id in &active {
            show_quest_progress(&soul, *quest_id, &quests);
        }
    }

    println!();

    // Check if we have empty slots
    let unlocked_slots = soul.unlocked_quest_slots();
    let used_slots = active.len();

    if used_slots < unlocked_slots {
        println!("You have {} empty quest slot{}.",
            unlocked_slots - used_slots,
            if unlocked_slots - used_slots == 1 { "" } else { "s" }
        );
        println!();

        // Auto-offer available quests based on level
        let level = soul.level;

        if !soul.has_quest(QUEST_SEWER_CLEANSE) {
            offer_quest(&mut soul, QUEST_SEWER_CLEANSE, &quests);
        } else if level >= 2 && !soul.has_quest(QUEST_THE_CRACK) {
            offer_quest(&mut soul, QUEST_THE_CRACK, &quests);
        } else if level >= 3 && !soul.has_quest(QUEST_LOCKED_DOOR) {
            offer_quest(&mut soul, QUEST_LOCKED_DOOR, &quests);
        } else if level >= 5 && !soul.has_quest(QUEST_PORTAL_HOME) {
            offer_quest(&mut soul, QUEST_PORTAL_HOME, &quests);
        } else if level >= 6 && !soul.has_quest(QUEST_NAVIGATE_MAZE) {
            offer_quest(&mut soul, QUEST_NAVIGATE_MAZE, &quests);
        } else {
            println!("No new quests available at your level.");
        }
    } else {
        println!("All quest slots full ({}/{}).", used_slots, unlocked_slots);
        println!("Complete a quest to free up a slot.");
    }

    println!();
}

/// Check quest-specific progress logic
/// Returns (is_complete, optional_progress_message)
fn check_quest_progress(quest_id: u32) -> (bool, Option<String>) {
    match quest_id {
        QUEST_SEWER_CLEANSE => {
            let rats = count_rats();
            let is_complete = rats == 0;
            let msg = format!("Progress: {} rats remaining", rats);
            (is_complete, Some(msg))
        }
        // Other quests don't have dynamic progress tracking yet
        _ => (false, None),
    }
}

fn show_quest_progress(_soul: &Soul, quest_id: u32, quests: &HashMap<u32, QuestData>) {
    let quest_data = match quests.get(&quest_id) {
        Some(q) => q,
        None => {
            println!("Quest {}: Unknown quest", quest_id);
            println!();
            return;
        }
    };

    println!("Quest: {}", quest_data.name);

    // Print description with proper indentation
    for line in quest_data.journal_description.lines() {
        println!("  {}", line);
    }
    println!();

    // Check progress based on quest type
    let (is_complete, progress_msg) = check_quest_progress(quest_id);

    if let Some(msg) = progress_msg {
        println!("  {}", msg);
    }

    // Show objective and reward if provided
    if let Some(ref obj) = quest_data.journal_objective {
        println!("  Objective: {}", obj);
    }
    if let Some(ref reward) = quest_data.journal_reward {
        println!("  Reward: {}", reward);
    }

    if is_complete {
        println!();
        println!("  *** QUEST COMPLETE! ***");
        if let Some(ref msg) = quest_data.completion_message {
            println!("  {}", msg);
        }
    }

    println!();
}

fn offer_quest(soul: &mut Soul, quest_id: u32, quests: &HashMap<u32, QuestData>) {
    let quest_data = match quests.get(&quest_id) {
        Some(q) => q,
        None => {
            eprintln!("Error: Quest {} not found in quest data", quest_id);
            process::exit(1);
        }
    };

    println!("=== New Quest Available ===");
    println!();
    println!("{}", quest_data.offer_title);
    println!();

    // Print narrative with proper line wrapping
    for line in quest_data.offer_narrative.lines() {
        println!("{}", line);
    }
    println!();

    println!("Objective: {}", quest_data.offer_objective);
    println!("Reward: {}", quest_data.offer_reward);
    println!();
    println!("Quest accepted!");

    // Auto-accept quest
    if let Err(e) = soul.add_quest(quest_id) {
        eprintln!("Error accepting quest: {}", e);
        process::exit(1);
    }

    // Save updated soul
    if let Err(e) = soul.save(SOUL_PATH) {
        eprintln!("Error saving soul: {}", e);
        process::exit(1);
    }

    println!("Quest added to your journal.");
}

fn count_rats() -> usize {
    let entries = match fs::read_dir(SEWER_PATH) {
        Ok(e) => e,
        Err(_) => return 0,
    };

    entries
        .filter_map(|e| e.ok())
        .filter(|e| {
            e.file_name()
                .to_str()
                .map(|s| s.ends_with(".rat"))
                .unwrap_or(false)
        })
        .count()
}
