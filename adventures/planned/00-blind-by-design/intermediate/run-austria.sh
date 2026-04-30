#!/usr/bin/env bash
# Start the lab as a Phase trial registered in Austria. Same shape as
# run-germany.sh; only the country code differs. The country=at branch is
# not in flags.json by default — every subject without a species override falls
# through to the "blurry" default. Useful for proving the country-targeting
# branch only fires when the country matches.
set -e
cd "$(dirname "${BASH_SOURCE[0]}")"
COUNTRY=at exec ./mvnw spring-boot:run "$@" 2>&1 | tee app.log
