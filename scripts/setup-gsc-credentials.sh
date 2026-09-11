#!/usr/bin/env bash
# Installs a GSC service-account credential file from a base64-encoded
# environment variable, only inside Claude Code remote sessions.
#
# Never echoes, logs, or otherwise outputs the base64 value, decoded
# JSON, private key, service-account email, project ID, or any token.
set -u

TARGET_PATH="/tmp/gsc-service-account.json"

# Only run in Claude Code remote sessions.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
    exit 0
fi

# Nothing to do if the variable isn't set.
if [ -z "${GSC_SERVICE_ACCOUNT_B64:-}" ]; then
    exit 0
fi

TMP_FILE="$(mktemp)"
cleanup() {
    rm -f "$TMP_FILE"
}
trap cleanup EXIT

# Decode without ever passing the value through a command line or log.
# stderr is discarded so decode errors can't leak partial secret bytes.
if ! printf '%s' "$GSC_SERVICE_ACCOUNT_B64" | base64 -d > "$TMP_FILE" 2>/dev/null; then
    exit 0
fi

# Validate it's well-formed JSON (an object) before installing it.
if ! python3 -c "
import json, sys
try:
    with open(sys.argv[1], 'rb') as f:
        data = json.load(f)
except Exception:
    sys.exit(1)
sys.exit(0 if isinstance(data, dict) else 1)
" "$TMP_FILE" 2>/dev/null; then
    exit 0
fi

# Install with restrictive permissions. Create the file with 600 perms
# up front so it is never briefly world/group readable.
install -m 600 "$TMP_FILE" "$TARGET_PATH" 2>/dev/null || exit 0

exit 0
