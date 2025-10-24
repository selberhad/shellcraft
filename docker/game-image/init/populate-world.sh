#!/bin/sh
# Populate the game world with enemies and lore

# Create sewer enemies (early game)
mkdir -p /sewer
for i in 1 2 3 4 5; do
    # Create rat files with random data (100-500 bytes)
    dd if=/dev/urandom of=/sewer/rat_$i.rat bs=1 count=$((100 + RANDOM % 400)) 2>/dev/null
done

# Create crypt enemies (mid game)
mkdir -p /crypt
dd if=/dev/urandom of=/crypt/skeleton.elf bs=1 count=800 2>/dev/null
dd if=/dev/urandom of=/crypt/daemon.elf bs=1 count=1200 2>/dev/null

# Create tower challenges (late game)
mkdir -p /tower
echo "The answer lies in the shadows..." > /tower/riddle_1.txt
echo "Seek the pattern within the chaos." > /tower/riddle_2.txt

# Create lore scrolls
mkdir -p /etc/scrolls
cat > /etc/scrolls/welcome.txt << 'EOF'
Greetings, Adventurer.

You have entered the realm of ShellCraft, where the command line
is your greatest weapon and knowledge is power.

The sewers below teem with vermin. Practice your skills there.
When you are ready, descend into the crypt.

Remember: every byte manipulated grants you experience.
Every command mastered unlocks new possibilities.

May your PATH be clear and your pipes unbroken.

-- The Lorekeeper
EOF

cat > /etc/scrolls/commands.txt << 'EOF'
Basic Incantations:

ls      - Reveal what is hidden
cat     - Speak the contents of ancient texts
echo    - Project your voice into the void
rm      - Banish entities from existence
cd      - Traverse the realms
pwd     - Know your place in the world
whoami  - Remember your identity

More powerful spells unlock as you gain experience.
Type 'status' to see your progress.
EOF

chmod -R 755 /sewer /crypt /tower /etc/scrolls
