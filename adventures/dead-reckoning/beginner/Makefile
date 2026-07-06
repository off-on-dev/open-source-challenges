.DEFAULT_GOAL := help

.PHONY: help backstage verify

help:
	@echo "Dead Reckoning - Beginner: Available Commands:"
	@echo "  make backstage   Start Backstage (the commission office)"
	@echo "  make verify      Run the verification script"

# Foreground start so you get live logs and can restart with Ctrl-C + make backstage.
# In a Codespace two ports must be public: 7007 so the browser SPA can reach the
# backend, and 30110 so both the browser and the scaffolder backend can reach Gitea
# at its forwarded URL. 30110 (Gitea) is already up, so it flips immediately; 7007
# only forwards once Backstage is listening, so that one retries. We also layer the
# Codespaces config overlay so the baseUrls point at forwarded URLs.
backstage:
	@echo "⚓ Starting Backstage. First start compiles for ~30-60s, then open port 3000."
	@configs="--config $(CURDIR)/backstage/app-config.yaml"; \
	if [ -n "$$CODESPACE_NAME" ]; then \
		configs="$$configs --config $(CURDIR)/backstage/app-config.codespaces.yaml"; \
		( until gh codespace ports visibility 30110:public -c "$$CODESPACE_NAME" >/dev/null 2>&1; do sleep 3; done; \
		  until gh codespace ports visibility 7007:public -c "$$CODESPACE_NAME" >/dev/null 2>&1; do sleep 3; done ) & \
	fi; \
	cd backstage && COREPACK_ENABLE_DOWNLOAD_PROMPT=0 yarn start $$configs

verify:
	@./verify.sh
