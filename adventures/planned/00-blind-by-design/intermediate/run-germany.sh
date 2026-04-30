#!/usr/bin/env bash
# Start the lab as a Phase trial registered in Germany. Pipes through tee so
# verify.sh can grep the audit-hook lines from app.log.
set -e
cd "$(dirname "${BASH_SOURCE[0]}")"
COUNTRY=de exec ./mvnw spring-boot:run "$@" 2>&1 | tee app.log
