 #!/usr/bin/env bash
# name=check_git_updates.sh
# Simple cronable checker that notifies when the remote branch has new commits.
# Configure REPO_DIR, BRANCH, REMOTE and NOTIFY_CMD below.

set -euo pipefail

# CONFIGURE THESE
REPO_DIR="/path/to/CE"                 # path to your local clone
REMOTE="origin"                        # remote name (usually origin)
BRANCH="main"                          # branch to track (e.g. main or master)
LOCKFILE="/var/lock/check_git_updates.lock"
# Example: send an email using mailx (must be installed & configured)
# NOTIFY_CMD='printf "Repo updated:\n\n%s\n" "$CHANGES" | mailx -s "Git updates in CE" you@example.com'
# Default: log to syslog
NOTIFY_CMD='logger -t git-check "git updates available in '"$REPO_DIR"' ('"$BRANCH"')"' 

# Acquire lock to prevent overlapping runs
exec 200>"$LOCKFILE"
flock -n 200 || { echo "Another instance is running — exiting."; exit 0; }

# Ensure repo dir exists
if [ ! -d "$REPO_DIR" ]; then
  echo "Repository directory $REPO_DIR does not exist" >&2
  exit 2
fi

cd "$REPO_DIR"

# Ensure this is a git repo
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not a git repository: $REPO_DIR" >&2
  exit 3
fi

# Check for uncommitted changes — we won't auto-pull in that case
if ! git diff-index --quiet HEAD --; then
  echo "Local working tree has uncommitted changes; skipping update check." >&2
  exit 0
fi

# Fetch updates quietly
if ! git fetch --prune "$REMOTE" >/dev/null 2>&1; then
  echo "git fetch failed" >&2
  exit 4
fi

# Resolve references (use fully-qualified refs to avoid ambiguity)
LOCAL_REF="refs/heads/$BRANCH"
REMOTE_REF="refs/remotes/$REMOTE/$BRANCH"

# Ensure branch exists locally and remotely
if ! git show-ref --verify --quiet "$LOCAL_REF"; then
  echo "Local branch $BRANCH does not exist." >&2
  exit 5
fi
if ! git show-ref --verify --quiet "$REMOTE_REF"; then
  echo "Remote branch $REMOTE/$BRANCH does not exist." >&2
  exit 6
fi

LOCAL_SHA=$(git rev-parse "$LOCAL_REF")
REMOTE_SHA=$(git rev-parse "$REMOTE_REF")

if [ "$LOCAL_SHA" = "$REMOTE_SHA" ]; then
  # No new commits
  exit 0
fi

# How many commits the remote is ahead of local
AHEAD_COUNT=$(git rev-list --count "$LOCAL_SHA".."$REMOTE_SHA")
CHANGES=$(git --no-pager log --pretty=format:'%h %s (%an)' "$LOCAL_SHA".."$REMOTE_SHA")

# Notification: the NOTIFY_CMD can use $AHEAD_COUNT and $CHANGES variables.
# Example NOTIFY_CMD values:
#  - logger: logger -t git-check "Repo updated: $AHEAD_COUNT new commits"
#  - mail: printf "New commits:\n\n%s\n" "$CHANGES" | mailx -s "Git updates in CE" you@example.com
eval "$NOTIFY_CMD"

# Print details (also logged if cron captures stdout)
printf '%s\n' "Remote $REMOTE/$BRANCH is ahead by $AHEAD_COUNT commit(s):"
printf '%s\n' "$CHANGES"

exit 0
