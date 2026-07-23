# ==============================================================================
# Open Ecosystem Challenges
# ==============================================================================

.PHONY: help new-adventure docs accessibility-nightmare-beginner

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


accessibility-nightmare-beginner:
	$(MAKE) -C adventures/planned/adventure-accessibility-nightmare/beginner app
