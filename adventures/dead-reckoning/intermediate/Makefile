.DEFAULT_GOAL := help

.PHONY: help backstage apply verify ahoi

help:
	@echo "Dead Reckoning - Intermediate: Available Commands:"
	@echo "  make backstage   Start Backstage (the commission office)"
	@echo "  make apply       Re-apply the platform/ manifests (reload your edits)"
	@echo "  make verify      Run the verification script"
	@echo "  make ahoi        Send a request to a vessel (VESSEL=<name>, or the newest)"

# Foreground start so you get live logs and can restart with Ctrl-C + make backstage.
# The vessel page's Argo CD card reaches Argo CD through the backend proxy, which
# needs a session cookie. We mint one from the read-only account here and pass it
# in as ARGOCD_AUTH_TOKEN, so the token lives only for this process and never
# lands in a committed file.
# In a Codespace these ports must be public: 7007 so the browser SPA can reach the
# backend, 30112 so browser and scaffolder can reach Gitea at its forwarded URL,
# and 30100 / 30113 so the card's "open in Argo CD" link and the Argo Workflows UI
# resolve. 30112 (Gitea) is already up so it flips immediately; the others retry
# until they forward. We also layer the Codespaces overlay so baseUrls point at
# forwarded URLs.
backstage:
	@echo "⚓ Starting Backstage. First start compiles for ~30-60s, then open port 3000."
	@ARGOCD_AUTH_TOKEN="argocd.token=$$(curl -s --max-time 10 http://localhost:30100/api/v1/session \
		-H 'Content-Type: application/json' \
		-d '{"username":"readonly","password":"a-super-secure-password"}' | jq -r '.token // empty')"; \
	export ARGOCD_AUTH_TOKEN; \
	configs="--config $(CURDIR)/backstage/app-config.yaml"; \
	if [ -n "$$CODESPACE_NAME" ]; then \
		configs="$$configs --config $(CURDIR)/backstage/app-config.codespaces.yaml"; \
		( for p in 30112 7007 30100 30113; do \
			until gh codespace ports visibility $$p:public -c "$$CODESPACE_NAME" >/dev/null 2>&1; do sleep 3; done; \
		  done ) & \
	fi; \
	cd backstage && COREPACK_ENABLE_DOWNLOAD_PROMPT=0 yarn start $$configs

apply:
	@kubectl apply -R -f platform/

verify:
	@./verify.sh

# Ahoi a vessel: port-forward its Service and curl it. Defaults to the most
# recently deployed vessel; override with `make ahoi VESSEL=<name>`.
ahoi:
	@vessel="$(VESSEL)"; \
	if [ -z "$$vessel" ]; then \
		vessel=$$(kubectl get deploy -n default -o jsonpath='{range .items[*]}{.metadata.creationTimestamp}{" "}{.metadata.name}{"\n"}{end}' | sort | tail -1 | awk '{print $$2}'); \
	fi; \
	if [ -z "$$vessel" ]; then echo "⚓ No vessel found. Commission one first, or run 'make ahoi VESSEL=<name>'."; exit 1; fi; \
	echo "⚓ Ahoi, $$vessel..."; \
	kubectl port-forward -n default "svc/$$vessel" 18090:8080 >/dev/null 2>&1 & \
	pf=$$!; \
	trap "kill $$pf 2>/dev/null || true" EXIT; \
	out=""; \
	for i in 1 2 3 4 5 6; do out=$$(curl -s --max-time 3 http://localhost:18090/ || true); [ -n "$$out" ] && break; sleep 1; done; \
	if [ -z "$$out" ]; then echo "No response from $$vessel (is it running and healthy?)"; else echo "$$out" | jq . 2>/dev/null || echo "$$out"; fi
