#!/bin/bash
set -e

# Dispatch parameters (provided by the update-docs workflow)
APP_NAME="${APP_NAME:-}"
SECTION_MAP="${SECTION_MAP:-}"
SOURCE_REPO="${SOURCE_REPO:-}"
SOURCE_DIR="${SOURCE_DIR:-source}"
MERGE_SHA="${MERGE_SHA:-$1}"
PR_NUMBER="${PR_NUMBER:-}"
PR_TITLE="${PR_TITLE:-}"

# 'changelog' (default) writes a single semester page; 'general' scans pages/ instead.
# Set from the 'general docs' label on the source PR.
DOCS_MODE="${DOCS_MODE:-changelog}"
# Term code (W26, S26, ...) resolved from public.terms by the workflow. Required in changelog mode.
SEMESTER_TAG="${SEMESTER_TAG:-}"

if [ -z "$MERGE_SHA" ]; then
  echo "Error: MERGE_SHA environment variable or merge SHA argument is required"
  exit 1
fi

if [ -z "$APP_NAME" ] || [ -z "$SOURCE_REPO" ]; then
  echo "Error: APP_NAME and SOURCE_REPO environment variables are required"
  exit 1
fi

if [ ! -d "$SOURCE_DIR" ]; then
  echo "Error: source repository checkout not found at '$SOURCE_DIR'"
  exit 1
fi

# Generate diff of the merged PR from the source repo checkout
EXCLUDE_ARGS=()
while IFS= read -r pattern; do
  EXCLUDE_ARGS+=(":!$pattern")
done < "$(dirname "$0")/.diffignore"

git -C "$SOURCE_DIR" diff "$MERGE_SHA^1" "$MERGE_SHA" -- "${EXCLUDE_ARGS[@]}" > changes.diff

# Resolve the changelog page for this term, scaffolding it on the first PR of a new
# term. Nobody labels PRs any more, so nothing else would ever create the page.
CHANGELOG_FILE=""
if [ "$DOCS_MODE" != "general" ]; then
  if [ -z "$SEMESTER_TAG" ]; then
    echo "Error: SEMESTER_TAG is required in changelog mode (resolve it from public.terms first)"
    exit 1
  fi

  CHANGELOG_FILE="pages/changelog/${SEMESTER_TAG}.mdx"
  echo "Active term: $SEMESTER_TAG"
  echo "Will update changelog: $CHANGELOG_FILE"

  if [ ! -f "$CHANGELOG_FILE" ]; then
    case "${SEMESTER_TAG:0:1}" in
      F) SEASON_NAME="Fall" ;;
      W) SEASON_NAME="Winter" ;;
      S) SEASON_NAME="Spring" ;;
      *) SEASON_NAME="${SEMESTER_TAG:0:1}" ;;
    esac
    SEASON_YEAR="20${SEMESTER_TAG:1:2}"

    mkdir -p "$(dirname "$CHANGELOG_FILE")"
    cat > "$CHANGELOG_FILE" <<EOF
# ${SEASON_NAME} ${SEASON_YEAR} Updates

Work across the UWDSC applications. Details will grow as PRs land through the term.

---

_From merged PRs tagged \`${SEMESTER_TAG}\`._
EOF

    echo "Created new changelog page: $CHANGELOG_FILE"
    echo "Remember to add '${SEMESTER_TAG}: \"${SEASON_NAME} ${SEASON_YEAR}\"' to pages/changelog/_meta.js"
  fi
else
  echo "Docs mode: general. Will update general documentation only."
fi

# Section placement rules for the changelog
if [ -n "$SECTION_MAP" ]; then
  SECTION_RULES="This source repository hosts multiple applications. Use the file paths in changes.diff to decide which section each changelog point belongs to, based on these '<path-prefix> => <heading>' rules:

${SECTION_MAP}

If a change does not match any prefix, place it under the '## ${APP_NAME}' section."
else
  SECTION_RULES="Place ALL changelog points under the '## ${APP_NAME}' section."
fi

# Build the prompt for copilot
PROMPT="You are a technical writer focused on documenting features from a business/functional perspective for a university data science club.

BE BRIEF AND CONCISE: Keep all summaries and descriptions short. One or two sentences per item maximum. Avoid long paragraphs or unnecessary detail.

Read the 'changes.diff' file to understand the latest code updates from PR #${PR_NUMBER}: ${PR_TITLE}, merged in the '${SOURCE_REPO}' repository (the ${APP_NAME} application).

The source repository is checked out at '${SOURCE_DIR}/' in the current directory.

IMPORTANT: Before making any modifications to existing documentation:
- Review the changes.diff to see exactly what code changed
- Search the source repository checkout at '${SOURCE_DIR}/' to verify the current implementation state
- Only modify existing entries when code changes clearly warrant documentation updates
- Ensure all modifications accurately reflect the actual code changes"

if [ "$DOCS_MODE" != "general" ]; then
  PROMPT="$PROMPT

CRITICAL: This PR belongs to semester ${SEMESTER_TAG}. You MUST ONLY update the changelog file at: ${CHANGELOG_FILE}

DO NOT modify any other files in the documentation. The PR should show only ONE file changed: ${CHANGELOG_FILE}

## Changelog Structure Context

The changelog is organized by semester (F25, W26, S26, etc.) and each semester file groups features under a heading per application:

# [Semester] Updates

[Introduction paragraph]

## 🎯 Main Website
[Features for the main UWDSC website]

## 🛠️ Admin
[Features for the admin app]

## 💘 Speed Dataing
[Features for the Speed Dataing app]

## 🧮 Estimathon
[Features for the Estimathon app]

## 🏆 CxC
[Features for the CxC hackathon app]

---

_Features documented from merged PRs tagged with \`${SEMESTER_TAG}\`..._

## Instructions for Updating the Changelog

1. **Focus on business value**: Document WHAT was built and WHY it matters to users/admins, NOT technical implementation details
2. **Use business language**: Write in terms like 'Users can now...', 'Admins can...', 'Added feature X that allows Y'
3. **Group by application**: ${SECTION_RULES}
4. **Create missing sections**: If a needed application section does not exist yet in ${CHANGELOG_FILE}, add it as a '## [heading]' section before the closing '---' line. NEVER add points to another application's section, and never remove or reorder existing sections
5. **Format as bullet points**: Use markdown bullet points (-) for each feature
6. **Maintain structure**: Keep the existing section headings and formatting
7. **Primary focus on additions**: Prioritize adding new features and updates. When modifications are necessary:
  - Use changes.diff to understand what code actually changed. If it were minor bug fixes and improvements, do not modify the documentation.
  - Search the source repository checkout at '${SOURCE_DIR}/' to verify the current state of features before modifying documentation
  - Only modify existing entries when the code changes clearly indicate updates, corrections, or removals
  - Ensure modifications accurately reflect the actual code changes - cross-reference with the source repository
8. **One feature per bullet**: Each feature should be a separate bullet point
9. **Be brief and concise**: Summaries must be short-one or two sentences max. No long paragraphs; focus only on user impact

## Example Format

- **Feature Name**: Brief description of what users/admins can now do or what was improved

Do not ask for confirmation. Just make the edits to ${CHANGELOG_FILE} only."
else
  PROMPT="$PROMPT

Scan the 'pages/' folder (EXCLUDING '${SOURCE_DIR}/') and update the markdown files to reflect these code changes.

Keep all documentation updates brief and concise-short summaries only, no long paragraphs.

IMPORTANT: When updating documentation:
- Primary focus: Add new documentation for new features
- Modifications: When modifying existing documentation:
  - Use changes.diff to understand what code actually changed. If it were minor bug fixes and improvements, do not modify the documentation.
  - Search the source repository checkout at '${SOURCE_DIR}/' to verify current implementation before modifying docs
  - Only modify existing entries when code changes clearly indicate updates are needed
  - Ensure modifications accurately reflect the actual code changes
- NEVER modify anything inside '${SOURCE_DIR}/' - it is a read-only reference checkout"
fi

PROMPT="$PROMPT

Do not ask for confirmation. Just make the edits."

# Run copilot to update docs
copilot -p "$PROMPT" --allow-all-tools

rm -f changes.diff
