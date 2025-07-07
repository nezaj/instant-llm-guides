MAKEFLAGS = --no-print-directory --always-make --silent
MAKE = make $(MAKEFLAGS)

# Input files
# These are files we likely will update across user sessions
SHARED_PROMPT = session/shared-prompt.txt
INSTANT_RULES = session/instant-rules.txt

# Static files
# These files probably don't need to change from user sessions
STATIC_DIR = session/static
CLAUDE_INTRO = ${STATIC_DIR}/claude-intro.txt
CURSOR_FRONTMATTER = ${STATIC_DIR}/cursor-frontmatter.txt
OTHER_INTRO = ${STATIC_DIR}/other-intro.txt

# Output files
CLAUDE_DIR = gen/session/claude-code
CLAUDE_MD = $(CLAUDE_DIR)/CLAUDE.md
CLAUDE_RULES = $(CLAUDE_DIR)/instant-rules.md

CURSOR_DIR = gen/session/cursor
CURSOR_RULES = $(CURSOR_DIR)/instant-rules.mdc

OTHER_RULES = gen/session/other/instant-rules.md

combine:
	@echo "Combining all guides into rules.md ..."
	cat guides/*.md > gen/guides/rules.md

rules: gen-claude gen-cursor gen-other
	@echo "Generated all session files"

gen-claude:
	@echo "Generating files for Claude Code"
	@mkdir -p $(CLAUDE_DIR)
	# Claude requires a CLAUDE.md file and an instant-rules.md file
	# Create the CLAUDE.md
	@cat $(CLAUDE_INTRO) > $(CLAUDE_MD)
	@echo "" >> $(CLAUDE_MD)
	@cat $(SHARED_PROMPT) >> $(CLAUDE_MD)
	# Add the instant rules
	@cat $(INSTANT_RULES) > $(CLAUDE_RULES)

gen-cursor:
	@echo "Generating cursor file..."
	@mkdir -p $(CURSOR_DIR)
	# Cursor is just one file so we combine everything into one mdc file
	@cat $(CURSOR_FRONTMATTER) > $(CURSOR_RULES)
	@echo "" >> $(CURSOR_RULES)
	@cat $(OTHER_INTRO) >> $(CURSOR_RULES)
	@echo "" >> $(CURSOR_RULES)
	@cat $(SHARED_PROMPT) >> $(CURSOR_RULES)
	@echo "" >> $(CURSOR_RULES)
	@cat $(INSTANT_RULES) >> $(CURSOR_RULES)

gen-other:
	@echo "Generating other files..."
	@mkdir -p gen/session/other
	# Other files are similar to cursor but don't have the frontmatter
	@cat $(OTHER_INTRO) > $(OTHER_RULES)
	@echo "" >> $(OTHER_RULES)
	@cat $(SHARED_PROMPT) >> $(OTHER_RULES)
	@echo "" >> $(OTHER_RULES)
	@cat $(INSTANT_RULES) >> $(OTHER_RULES)

