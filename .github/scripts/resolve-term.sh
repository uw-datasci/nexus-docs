#!/bin/bash
set -euo pipefail

# Resolves the club's current term code (W26, S26, F26, ...) from the main website's
# database. This replaces the semester labels that used to be applied to every PR by hand.
#
# Reads:  DATABASE_URL  (pulled from Infisical at /website/db by the calling workflow)
# Writes: "code=<TERM>" to $GITHUB_OUTPUT when running under Actions; the code is always
#         echoed to stdout, so this is runnable locally to check what CI would resolve.

DATABASE_URL="${DATABASE_URL:-}"

if [ -z "$DATABASE_URL" ]; then
  echo "Error: DATABASE_URL is required to resolve the active term"
  exit 1
fi

if ! command -v psql >/dev/null; then
  if [ -n "${CI:-}" ]; then
    sudo apt-get update -qq
    sudo apt-get install -y -qq postgresql-client
  else
    echo "Error: psql not found. Install the postgresql client to run this locally."
    exit 1
  fi
fi

# Mirrors getActiveTerm() in the website's application.repository.ts, but prefers a term
# whose window actually contains now(): terms.is_active is maintained by a BEFORE
# INSERT/UPDATE trigger, so it can go stale between terms if nothing writes to the table.
CODE=$(psql "$DATABASE_URL" -tAc "
  SELECT code
  FROM public.terms
  WHERE is_active = true OR (start_date <= now() AND now() <= end_date)
  ORDER BY (start_date <= now() AND now() <= end_date) DESC, created_at DESC
  LIMIT 1;
")
CODE="${CODE//[[:space:]]/}"

# Fail loudly rather than guess: writing to the wrong semester page is worse than a red build.
if ! [[ "$CODE" =~ ^[WSF][0-9]{2}$ ]]; then
  echo "::error::Could not resolve an active term from public.terms (got '${CODE}')."
  exit 1
fi

echo "Active term: $CODE"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "code=$CODE" >> "$GITHUB_OUTPUT"
fi
