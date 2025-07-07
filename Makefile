MAKEFLAGS = --no-print-directory --always-make --silent
MAKE = make $(MAKEFLAGS)

# Common files
CURSOR_INTRO = session/cursor-intro.txt
SHARED_PROMPT = session/shared-prompt.txt
INSTANT_RULES = session/instant-rules.txt


# Output files
CLAUDE_DIR = gen/session/claude-code
CLAUDE_MD = $(CLAUDE_DIR)/CLAUDE.md
CLAUDE_RULES = $(CLAUDE_DIR)/instant-rules.md

CURSOR_DIR = gen/session/cursor
CURSOR_RULES = $(CURSOR_DIR)/instant-rules.md

OTHER_RULES = gen/session/other/instant-rules.md

combine:
	@echo "Combining all guides into rules.md ..."
	cat guides/*.md > gen/guides/rules.md

gen-claude:
	@echo "Generating files for Claude Code"
	@mkdir -p $(CLAUDE_DIR)
	# Claude requires a CLAUDE.md file and an instant-rules.md file
	# Create the CLAUDE.md
	@cat session/claude-intro.txt > $(CLAUDE_MD)
	@echo "" >> $(CLAUDE_MD)
	@cat $(SHARED_PROMPT) >> $(CLAUDE_MD)
	# Add the instant rules
	@cat $(INSTANT_RULES) > $(CLAUDE_RULES)

gen-cursor:
	@echo "Generating cursor file..."
	@mkdir -p $(CURSOR_DIR)
	# Cursor is just one file so we combine everything into one mdc file
	@cat session/cursor-frontmatter.txt > $(CURSOR_RULES)
	@echo "" >> $(CURSOR_RULES)
	@cat $(CURSOR_INTRO) >> $(CURSOR_RULES)
	@echo "" >> $(CURSOR_RULES)
	@cat $(SHARED_PROMPT) >> $(CURSOR_RULES)
	@echo "" >> $(CURSOR_RULES)
	@cat $(INSTANT_RULES) >> $(CURSOR_RULES)

gen-other:
	@echo "Generating other files..."
	@mkdir -p gen/session/other
	# Other files are similar to cursor but don't have the frontmatter
	@cat $(CURSOR_INTRO) > $(OTHER_RULES)
	@echo "" >> $(OTHER_RULES)
	@cat $(SHARED_PROMPT) >> $(OTHER_RULES)
	@echo "" >> $(OTHER_RULES)
	@cat $(INSTANT_RULES) >> $(OTHER_RULES)

