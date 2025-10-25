use libsoul::Soul;
use std::fs;
use std::process;

const SOUL_PATH: &str = "/home/soul.dat";
const SEWER_PATH: &str = "/sewer";

// Quest IDs
const QUEST_SEWER_CLEANSE: u32 = 1;

fn main() {
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
            show_quest_progress(&soul, *quest_id);
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

        // Auto-offer available quest
        if !soul.has_quest(QUEST_SEWER_CLEANSE) {
            offer_sewer_cleanse(&mut soul);
        } else {
            println!("No new quests available at your level.");
        }
    } else {
        println!("All quest slots full ({}/{}).", used_slots, unlocked_slots);
        println!("Complete a quest to free up a slot.");
    }

    println!();
}

fn show_quest_progress(_soul: &Soul, quest_id: u32) {
    match quest_id {
        QUEST_SEWER_CLEANSE => {
            let rats = count_rats();
            let complete = rats == 0;

            println!("Quest: The Sewer Cleanse");
            println!("  The sewers beneath the city are infested with rats.");
            println!("  Venture into /sewer and eliminate every last one.");
            println!();
            println!("  Progress: {} rats remaining", rats);

            if complete {
                println!();
                println!("  *** QUEST COMPLETE! ***");
                println!("  Return to complete this quest and claim your reward.");
                println!("  (Run ./quest again)");
            }
        }
        _ => {
            println!("Quest {}: Unknown quest", quest_id);
        }
    }
    println!();
}

fn offer_sewer_cleanse(soul: &mut Soul) {
    println!("=== New Quest Available ===");
    println!();
    println!("The Sewer Cleanse");
    println!();
    println!("A terrible stench rises from the sewers beneath the city.");
    println!("The rat infestation has grown out of control. Someone must");
    println!("venture into the darkness and clear them out.");
    println!();
    println!("Objective: Eliminate all rats in /sewer");
    println!("Reward: 500 XP");
    println!();
    println!("Quest accepted!");

    // Auto-accept (only one quest available anyway)
    if let Err(e) = soul.add_quest(QUEST_SEWER_CLEANSE) {
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
