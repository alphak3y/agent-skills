#!/usr/bin/env bash
# repo-slot.sh — Manage isolated repo clones for parallel agent work
# Usage:
#   repo-slot.sh acquire <repo-name> <branch> <label>   — Clone/reuse a named slot, checkout branch
#   repo-slot.sh release <slot-path>                     — Release and reset a slot (keeps clone)
#   repo-slot.sh done    <slot-path>                     — Release + delete clone (use after push)
#   repo-slot.sh list    <repo-name>                     — Show all slots and status
#   repo-slot.sh cleanup <repo-name>                     — Remove unlocked slots
#
# Slots:  ~/gitalt/<repo-name>--<label>/
# Locks:  ~/gitalt/.slot-locks/<repo-name>--<label>.lock
#
# The label should match the subagent session name (e.g., "stack-docs", "stack-legal")
# so it's immediately obvious which agent owns which clone.
#
# Examples:
#   repo-slot.sh acquire renta-backend feat/docs-site stack-docs
#   repo-slot.sh acquire renta-backend feat/legal-pages stack-legal
#   repo-slot.sh release ~/gitalt/renta-backend--stack-docs
#   repo-slot.sh list renta-backend

set -euo pipefail

SLOTS_ROOT="${SLOTS_ROOT:-$HOME/gitalt}"
LOCK_DIR="${SLOTS_ROOT}/.slot-locks"
ACTION="${1:?Usage: repo-slot.sh <acquire|release|list|cleanup> ...}"
shift

lock_path() { echo "${LOCK_DIR}/$(basename "$1").lock"; }

case "$ACTION" in
  acquire)
    REPO_NAME="${1:?repo-name required}"
    BRANCH="${2:?branch required}"
    LABEL="${3:?label required (e.g., stack-docs, stack-legal)}"
    mkdir -p "$LOCK_DIR"

    SLOT_DIR="${SLOTS_ROOT}/${REPO_NAME}--${LABEL}"
    LF=$(lock_path "$SLOT_DIR")

    # Check if already locked by someone else
    if [[ -f "$LF" ]]; then
      echo "ERROR: Slot ${REPO_NAME}--${LABEL} is already locked:" >&2
      cat "$LF" >&2
      exit 1
    fi

    # Clone if doesn't exist yet
    if [[ ! -d "$SLOT_DIR" ]]; then
      PRIMARY="${SLOTS_ROOT}/${REPO_NAME}"
      if [[ ! -d "$PRIMARY/.git" ]]; then
        echo "ERROR: Primary repo not found at $PRIMARY" >&2
        exit 1
      fi

      REMOTE_URL=$(git -C "$PRIMARY" remote get-url origin 2>/dev/null || echo "")
      if [[ -n "$REMOTE_URL" ]]; then
        git clone "$REMOTE_URL" "$SLOT_DIR" 2>&1 | tail -1
      else
        git clone "$PRIMARY" "$SLOT_DIR" 2>&1 | tail -1
      fi

      # Copy env files from primary
      for f in .env .env.local .env.development.local; do
        [[ -f "$PRIMARY/$f" ]] && cp "$PRIMARY/$f" "$SLOT_DIR/$f"
      done
    fi

    # Lock it
    echo "{\"agent\":\"${LABEL}\",\"branch\":\"${BRANCH}\",\"acquired\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"pid\":$$}" > "$LF"

    # Fetch and checkout
    cd "$SLOT_DIR"
    git fetch origin --prune 2>/dev/null

    if git show-ref --verify --quiet "refs/remotes/origin/${BRANCH}" 2>/dev/null; then
      git checkout -B "$BRANCH" "origin/${BRANCH}" 2>/dev/null
    elif git show-ref --verify --quiet "refs/heads/${BRANCH}" 2>/dev/null; then
      git checkout "$BRANCH" 2>/dev/null
    else
      DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")
      git checkout -B "$BRANCH" "origin/${DEFAULT_BRANCH}" 2>/dev/null
    fi

    git reset --hard HEAD 2>/dev/null
    git clean -fd 2>/dev/null

    # Ensure git identity is set (prevents "No GitHub account matching commit" errors)
    if [[ -z "$(git config user.name 2>/dev/null)" ]]; then
      GLOBAL_NAME=$(git config --global user.name 2>/dev/null || echo "")
      GLOBAL_EMAIL=$(git config --global user.email 2>/dev/null || echo "")
      if [[ -n "$GLOBAL_NAME" ]]; then
        git config user.name "$GLOBAL_NAME"
        git config user.email "$GLOBAL_EMAIL"
      else
        # Fallback: copy from primary repo
        PRIMARY="${SLOTS_ROOT}/${REPO_NAME}"
        P_NAME=$(git -C "$PRIMARY" config user.name 2>/dev/null || echo "")
        P_EMAIL=$(git -C "$PRIMARY" config user.email 2>/dev/null || echo "")
        if [[ -n "$P_NAME" ]]; then
          git config user.name "$P_NAME"
          git config user.email "$P_EMAIL"
        fi
      fi
    fi

    echo "SLOT:${SLOT_DIR}"
    echo "OK: Acquired ${SLOT_DIR} on branch ${BRANCH} for ${LABEL}"
    ;;

  release)
    SLOT_PATH="${1:?slot-path required}"
    SLOT_PATH="${SLOT_PATH%/}"
    LF=$(lock_path "$SLOT_PATH")

    if [[ -f "$LF" ]]; then
      rm -f "$LF"
    else
      echo "WARN: $SLOT_PATH was not locked" >&2
    fi

    if [[ -d "$SLOT_PATH/.git" ]]; then
      cd "$SLOT_PATH"
      DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")
      git checkout "$DEFAULT_BRANCH" 2>/dev/null || true
      git reset --hard HEAD 2>/dev/null || true
      git clean -fd 2>/dev/null || true
    fi

    echo "OK: Released $SLOT_PATH"
    ;;

  list)
    REPO_NAME="${1:?repo-name required}"
    mkdir -p "$LOCK_DIR"
    echo "Slots for $REPO_NAME:"
    echo "---"

    FOUND=0
    for SLOT_DIR in "${SLOTS_ROOT}/${REPO_NAME}--"*/; do
      [[ ! -d "$SLOT_DIR" ]] && continue
      # Skip numbered slots from old pool format
      SLOT_DIR="${SLOT_DIR%/}"
      SLOT_NAME=$(basename "$SLOT_DIR")
      LF=$(lock_path "$SLOT_DIR")
      FOUND=1

      if [[ -f "$LF" ]]; then
        AGENT=$(python3 -c "import json;print(json.load(open('$LF')).get('agent','?'))" 2>/dev/null || echo "?")
        BRANCH=$(python3 -c "import json;print(json.load(open('$LF')).get('branch','?'))" 2>/dev/null || echo "?")
        ACQUIRED=$(python3 -c "import json;print(json.load(open('$LF')).get('acquired','?'))" 2>/dev/null || echo "?")
        echo "🔒 $SLOT_NAME — branch: $BRANCH, since: $ACQUIRED"
      else
        CURRENT=$(git -C "$SLOT_DIR" branch --show-current 2>/dev/null || echo "?")
        echo "🟢 $SLOT_NAME — free (on: $CURRENT)"
      fi
    done

    [[ $FOUND -eq 0 ]] && echo "(no slots)"
    ;;

  done)
    # Release lock AND remove the clone (branch already pushed, no longer needed)
    SLOT_PATH="${1:?slot-path required}"
    SLOT_PATH="${SLOT_PATH%/}"
    LF=$(lock_path "$SLOT_PATH")

    rm -f "$LF" 2>/dev/null || true

    if [[ -d "$SLOT_PATH" ]]; then
      rm -rf "$SLOT_PATH"
      echo "OK: Cleaned up $SLOT_PATH (lock removed + directory deleted)"
    else
      echo "OK: $SLOT_PATH already gone"
    fi
    ;;

  cleanup)
    REPO_NAME="${1:?repo-name required}"
    for SLOT_DIR in "${SLOTS_ROOT}/${REPO_NAME}--"*/; do
      [[ ! -d "$SLOT_DIR" ]] && continue
      SLOT_DIR="${SLOT_DIR%/}"
      LF=$(lock_path "$SLOT_DIR")

      if [[ ! -f "$LF" ]]; then
        rm -rf "$SLOT_DIR"
        echo "REMOVED: $SLOT_DIR"
      else
        echo "SKIP: $SLOT_DIR (locked)"
      fi
    done
    echo "DONE: Cleanup complete"
    ;;

  *)
    echo "ERROR: Unknown action: $ACTION" >&2
    exit 1
    ;;
esac
