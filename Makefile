MAKEFLAGS = --no-print-directory --always-make --silent
MAKE = make $(MAKEFLAGS)

combine:
	@echo "Combining all guides into rules.md ..."
	cat guides/*.md > combined/rules.md

