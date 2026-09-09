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

# Decodes %XX escapes, leaving a bare '%' (i.e. one that isn't a valid escape) as-is, so
# this is safe on both an encoded and a raw credential.
urldecode() {
  local s=$1 out='' rest
  while [[ $s == *%* ]]; do
    out+=${s%%\%*}
    rest=${s#*%}
    if [[ ${rest:0:2} =~ ^[0-9A-Fa-f]{2}$ ]]; then
      out+=$(printf '%b' "\\x${rest:0:2}")
      s=${rest:2}
    else
      out+=%
      s=$rest
    fi
  done
  printf '%s' "$out$s"
}

# libpq splits a postgres:// URI at the FIRST '@', so a password containing an unescaped
# '@' is swallowed into the host name ("could not translate host name ...@aws-1-....
# pooler.supabase.com"). The shared website credential isn't percent-encoded, so split the
# URL here — at the LAST '@', the way the rest of the world reads it — and hand psql the
# pieces through PG* variables, which are taken literally and need no escaping at all.
rest=${DATABASE_URL#*://}
case "$rest" in
  */*) authority=${rest%%/*}; path=${rest#*/} ;;
  *)   authority=$rest;       path= ;;
esac

query=
case "$authority" in *\?*) query=${authority#*\?}; authority=${authority%%\?*} ;; esac
case "$path"      in *\?*) query=${path#*\?};      path=${path%%\?*} ;; esac

case "$authority" in
  *@*) userinfo=${authority%@*}; hostport=${authority##*@} ;;
  *)   userinfo=;                hostport=$authority ;;
esac

PGUSER=$(urldecode "${userinfo%%:*}")
case "$userinfo" in *:*) PGPASSWORD=$(urldecode "${userinfo#*:}") ;; *) PGPASSWORD= ;; esac
PGHOST=$(urldecode "${hostport%%:*}")
case "$hostport" in *:*) PGPORT=${hostport##*:} ;; *) PGPORT=5432 ;; esac
PGDATABASE=$(urldecode "$path")
export PGUSER PGPASSWORD PGHOST PGPORT PGDATABASE

# Only the connection options that actually reach us in a URL; anything else (pgbouncer=true
# and friends) isn't a libpq setting and is ignored on purpose.
IFS='&' read -r -a params <<< "$query"
for param in "${params[@]:-}"; do
  value=$(urldecode "${param#*=}")
  case "${param%%=*}" in
    sslmode)          export PGSSLMODE="$value" ;;
    sslrootcert)      export PGSSLROOTCERT="$value" ;;
    options)          export PGOPTIONS="$value" ;;
    application_name) export PGAPPNAME="$value" ;;
    connect_timeout)  export PGCONNECT_TIMEOUT="$value" ;;
  esac
done

if [ -z "$PGHOST" ] || [ -z "$PGUSER" ] || [ -z "$PGDATABASE" ]; then
  echo "::error::DATABASE_URL is not a usable postgres:// URL (host/user/database missing)."
  exit 1
fi

# The password reached the logs once already, when libpq quoted the mangled host back at
# us. Mask it so a future connection error can't leak it again.
if [ -n "${GITHUB_ACTIONS:-}" ] && [ -n "$PGPASSWORD" ]; then
  echo "::add-mask::$PGPASSWORD"
fi

# Mirrors getActiveTerm() in the website's application.repository.ts, but prefers a term
# whose window actually contains now(): terms.is_active is maintained by a BEFORE
# INSERT/UPDATE trigger, so it can go stale between terms if nothing writes to the table.
CODE=$(psql -tAc "
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
