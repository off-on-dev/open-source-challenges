.DEFAULT_GOAL := help

.PHONY: help app test verify

help:
	@echo "The Accessibility Nightmare - Expert: Available Commands:"
	@echo "  make app      Start the ShopSmart application"
	@echo "  make test     Run the compliance gate"
	@echo "  make verify   Run the verification script"

app:
	@npm run dev

test:
	@npm run test:a11y

verify:
	@./verify.sh
