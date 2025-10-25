use libsoul::Soul;
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

        // Auto-offer available quests based on level
        let level = soul.level;

        if !soul.has_quest(QUEST_SEWER_CLEANSE) {
            offer_sewer_cleanse(&mut soul);
        } else if level >= 2 && !soul.has_quest(QUEST_THE_CRACK) {
            offer_the_crack(&mut soul);
        } else if level >= 3 && !soul.has_quest(QUEST_LOCKED_DOOR) {
            offer_locked_door(&mut soul);
        } else if level >= 5 && !soul.has_quest(QUEST_PORTAL_HOME) {
            offer_portal_home(&mut soul);
        } else if level >= 6 && !soul.has_quest(QUEST_NAVIGATE_MAZE) {
            offer_navigate_maze(&mut soul);
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
                println!("  The Dungeon Master will grant your reward shortly.");
            }
        }
        QUEST_THE_CRACK => {
            println!("Quest: The Crack");
            println!("  Explore the hidden areas of the sewer.");
            println!("  Use 'ls -a' in /sewer to reveal what's hidden.");
            println!();
            println!("  Objective: Discover the .crack/ directory");
            println!("  Reward: 2000 XP");
        }
        QUEST_LOCKED_DOOR => {
            println!("Quest: The Locked Door");
            println!("  A locked door blocks your path in /sewer/.crack/");
            println!("  Find a way to unlock it.");
            println!();
            println!("  Objective: Create a key and unlock the door");
            println!("  Reward: 3000 XP");
        }
        QUEST_PORTAL_HOME => {
            println!("Quest: Portal Home");
            println!("  Create a symlink from /home to under_nix for quick access.");
            println!();
            println!("  Objective: ln -s /sewer/.crack/under_nix /home/portal");
            println!("  Reward: 8000 XP");
        }
        QUEST_NAVIGATE_MAZE => {
            println!("Quest: Navigate the Maze");
            println!("  The symlink maze in under_nix hides a treasure.");
            println!("  Use 'ls -l' to see where symlinks point.");
            println!();
            println!("  Objective: Find the treasure in the maze");
            println!("  Reward: 13000 XP");
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
    println!("Reward: 1000 XP");
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

fn offer_the_crack(soul: &mut Soul) {
    println!("=== New Quest Available ===");
    println!();
    println!("The Crack");
    println!();
    println!("You've mastered the basic commands. Now it's time to discover");
    println!("what lies hidden in the shadows. The sewers hold secrets that");
    println!("only reveal themselves to those who know where to look.");
    println!();
    println!("Objective: Discover the hidden .crack/ directory in /sewer");
    println!("Reward: 2000 XP");
    println!();
    println!("Quest accepted!");

    if let Err(e) = soul.add_quest(QUEST_THE_CRACK) {
        eprintln!("Error accepting quest: {}", e);
        process::exit(1);
    }

    if let Err(e) = soul.save(SOUL_PATH) {
        eprintln!("Error saving soul: {}", e);
        process::exit(1);
    }

    println!("Quest added to your journal.");
}

fn offer_locked_door(soul: &mut Soul) {
    println!("=== New Quest Available ===");
    println!();
    println!("The Locked Door");
    println!();
    println!("Beyond the crack in the wall lies a locked door. Ancient");
    println!("mechanisms guard the passage deeper. You'll need to create");
    println!("the right tool to open it.");
    println!();
    println!("Objective: Create a key and unlock the door in .crack/");
    println!("Reward: 3000 XP");
    println!();
    println!("Quest accepted!");

    if let Err(e) = soul.add_quest(QUEST_LOCKED_DOOR) {
        eprintln!("Error accepting quest: {}", e);
        process::exit(1);
    }

    if let Err(e) = soul.save(SOUL_PATH) {
        eprintln!("Error saving soul: {}", e);
        process::exit(1);
    }

    println!("Quest added to your journal.");
}

fn offer_portal_home(soul: &mut Soul) {
    println!("=== New Quest Available ===");
    println!();
    println!("Portal Home");
    println!();
    println!("You've discovered Under-Nix, but the journey is long.");
    println!("Create a shortcut from your home directory using the");
    println!("power of symbolic links.");
    println!();
    println!("Objective: Create a symlink from /home to under_nix");
    println!("Reward: 8000 XP");
    println!();
    println!("Quest accepted!");

    if let Err(e) = soul.add_quest(QUEST_PORTAL_HOME) {
        eprintln!("Error accepting quest: {}", e);
        process::exit(1);
    }

    if let Err(e) = soul.save(SOUL_PATH) {
        eprintln!("Error saving soul: {}", e);
        process::exit(1);
    }

    println!("Quest added to your journal.");
}

fn offer_navigate_maze(soul: &mut Soul) {
    println!("=== New Quest Available ===");
    println!();
    println!("Navigate the Maze");
    println!();
    println!("Under-Nix is a twisted labyrinth of symbolic links.");
    println!("Somewhere within lies a treasure, but you'll need to");
    println!("see where the paths truly lead to find it.");
    println!();
    println!("Objective: Find the treasure in the symlink maze");
    println!("Reward: 13000 XP");
    println!();
    println!("Quest accepted!");

    if let Err(e) = soul.add_quest(QUEST_NAVIGATE_MAZE) {
        eprintln!("Error accepting quest: {}", e);
        process::exit(1);
    }

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
