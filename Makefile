MAKEFLAGS = --no-print-directory --always-make --silent
MAKE = make $(MAKEFLAGS)

combine:
	@echo "Combining all guides into rules.md ..."
	cat guides/*.md > gen/guides/rules.md

gen-claude:
	@echo "Generating files for Claude Code"
	@mkdir -p gen/session/claude-code
	# @echo "Generating CLAUDE.md..."
	@cat session/claude-intro.txt > gen/session/claude-code/CLAUDE.md
	@echo "" >> gen/session/claude-code/CLAUDE.md
	@cat session/shared-prompt.txt >> gen/session/claude-code/CLAUDE.md
	# @echo "Generating instant-rules.md..."
	@cat session/instant-rules.txt > gen/session/claude-code/instant-rules.md

gen-cursor:
	@mkdir -p gen/session/cursor
	@echo "Generating cursor file..."
	@cat session/cursor-frontmatter.txt > gen/session/cursor/instant.mdc
	@echo "" >> gen/session/cursor/instant.mdc
	@cat session/cursor-intro.txt >> gen/session/cursor/instant.mdc
	@echo "" >> gen/session/cursor/instant.mdc
	@cat session/shared-prompt.txt >> gen/session/cursor/instant.mdc
	@echo "" >> gen/session/cursor/instant.mdc
	@cat session/instant-rules.txt >> gen/session/cursor/instant.mdc

