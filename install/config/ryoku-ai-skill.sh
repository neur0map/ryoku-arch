# Place in ~/.claude/skills since all tools populate from there as well as their own sources
mkdir -p ~/.claude/skills
ln -snf "$RYOKU_PATH/default/ryoku-skill" ~/.claude/skills/ryoku
