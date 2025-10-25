use std::collections::HashMap;

/// Quest text data loaded from quests.txt at compile time
#[derive(Debug, Clone)]
pub struct QuestData {
    pub id: u32,
    pub name: String,
    pub min_level: u32,
    pub reward_xp: u32,

    // Offer screen (when quest first becomes available)
    pub offer_title: String,
    pub offer_narrative: String,
    pub offer_objective: String,
    pub offer_reward: String,

    // Journal display (while quest is active)
    pub journal_description: String,

    // Optional fields (not all quests have these)
    pub journal_objective: Option<String>,
    pub journal_reward: Option<String>,
    pub progress_format: Option<String>,
    pub completion_message: Option<String>,
}

/// Load all quest data from embedded text file
/// Simple format: key=value pairs, multi-line with """, quests separated by %%
pub fn load_quests() -> HashMap<u32, QuestData> {
    const QUEST_DATA: &str = include_str!("../quests.txt");

    let mut quests = HashMap::new();

    for quest_block in QUEST_DATA.split("%% QUEST") {
        let quest_block = quest_block.trim();
        if quest_block.is_empty() || quest_block.starts_with('#') {
            continue;
        }

        let mut quest = QuestData {
            id: 0,
            name: String::new(),
            min_level: 0,
            reward_xp: 0,
            offer_title: String::new(),
            offer_narrative: String::new(),
            offer_objective: String::new(),
            offer_reward: String::new(),
            journal_description: String::new(),
            journal_objective: None,
            journal_reward: None,
            progress_format: None,
            completion_message: None,
        };

        let mut chars = quest_block.chars().peekable();
        let mut current_key = String::new();
        let mut current_value = String::new();
        let mut in_multiline = false;

        while let Some(ch) = chars.next() {
            if in_multiline {
                // Look for closing """
                if ch == '"' && chars.peek() == Some(&'"') {
                    chars.next(); // consume second "
                    if chars.peek() == Some(&'"') {
                        chars.next(); // consume third "
                        in_multiline = false;
                        set_field(&mut quest, &current_key, current_value.trim());
                        current_key.clear();
                        current_value.clear();
                    } else {
                        current_value.push('"');
                        current_value.push('"');
                    }
                } else {
                    current_value.push(ch);
                }
            } else if ch == '=' {
                current_key = current_value.trim().to_string();
                current_value.clear();

                // Check for """ multi-line string
                let mut peek_str = String::new();
                for _ in 0..3 {
                    if let Some(&c) = chars.peek() {
                        if c.is_whitespace() {
                            chars.next();
                        } else {
                            peek_str.push(c);
                            break;
                        }
                    }
                }

                if peek_str == "\"" {
                    chars.next(); // consume first "
                    if chars.peek() == Some(&'"') {
                        chars.next(); // consume second "
                        if chars.peek() == Some(&'"') {
                            chars.next(); // consume third "
                            in_multiline = true;
                        }
                    }
                }
            } else if ch == '\n' && !current_key.is_empty() && !current_value.trim().is_empty() {
                set_field(&mut quest, &current_key, current_value.trim());
                current_key.clear();
                current_value.clear();
            } else {
                current_value.push(ch);
            }
        }

        // Handle last field
        if !current_key.is_empty() && !current_value.trim().is_empty() {
            set_field(&mut quest, &current_key, current_value.trim());
        }

        if quest.id > 0 {
            quests.insert(quest.id, quest);
        }
    }

    quests
}

fn set_field(quest: &mut QuestData, key: &str, value: &str) {
    match key {
        "id" => quest.id = value.parse().unwrap_or(0),
        "name" => quest.name = value.to_string(),
        "min_level" => quest.min_level = value.parse().unwrap_or(0),
        "reward_xp" => quest.reward_xp = value.parse().unwrap_or(0),
        "offer_title" => quest.offer_title = value.to_string(),
        "offer_narrative" => quest.offer_narrative = value.to_string(),
        "offer_objective" => quest.offer_objective = value.to_string(),
        "offer_reward" => quest.offer_reward = value.to_string(),
        "journal_description" => quest.journal_description = value.to_string(),
        "journal_objective" => quest.journal_objective = Some(value.to_string()),
        "journal_reward" => quest.journal_reward = Some(value.to_string()),
        "progress_format" => quest.progress_format = Some(value.to_string()),
        "completion_message" => quest.completion_message = Some(value.to_string()),
        _ => {} // Ignore unknown fields
    }
}
