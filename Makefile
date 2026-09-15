# ==============================================================================
# Open Ecosystem Challenges
# ==============================================================================

.PHONY: help new-adventure docs

# Default target - show help
help:
	@echo "Open Ecosystem Challenges - Available Commands:"
	@echo ""
	@echo "  make new-adventure   Scaffold a new adventure from an approved idea"
	@echo "  make docs            Start the MkDocs documentation server"

# ------------------------------------------------------------------------------

new-adventure:
	@scripts/new-adventure.sh

docs:
	@mkdocs serve
