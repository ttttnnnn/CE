#!/bin/bash

###############################################################################
# check_git_update.sh
#
# FR:
# Vérifie périodiquement si un nouveau commit est disponible sur un dépôt Git
# distant. Si un nouveau commit est détecté, le script peut effectuer un
# traitement personnalisé puis enregistrer le commit comme traité.
#
# EN:
# Periodically checks whether a new commit is available on a remote Git
# repository. If a new commit is detected, the script can perform custom
# processing and then record the commit as processed.
###############################################################################

# ---------------------------------------------------------------------------
# FR: Déterminer l'emplacement du script et charger la configuration.
# EN: Determine script location and load configuration.
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
CONFIG_FILE="$SCRIPT_DIR/config.conf"

if [ -f "$CONFIG_FILE" ]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Missing configuration file: $CONFIG_FILE"
    exit 1
fi

# ---------------------------------------------------------------------------
# FR: Empêcher plusieurs exécutions simultanées.
# EN: Prevent multiple simultaneous executions.
# ---------------------------------------------------------------------------
exec 200>"$LOCK_FILE"

flock -n 200 || {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: Another instance is already running."
    exit 0
}

# ---------------------------------------------------------------------------
# FR: Lire le dernier commit traité localement.
# EN: Read the last processed commit recorded locally.
# ---------------------------------------------------------------------------
LOCAL_KNOWN_COMMIT=""

if [ -f "$LAST_COMMIT_FILE" ]; then
    LOCAL_KNOWN_COMMIT="$(cat "$LAST_COMMIT_FILE")"
fi

# ---------------------------------------------------------------------------
# FR: Interroger le dépôt distant pour connaître le dernier commit.
# EN: Query the remote repository to obtain the latest commit SHA.
# ---------------------------------------------------------------------------
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Checking remote repository..."

REMOTE_COMMIT="$(git ls-remote "$REPO_URL" "refs/heads/$BRANCH" 2>/dev/null | cut -f1)"

if [ -z "$REMOTE_COMMIT" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Unable to retrieve remote commit."
    echo "Verify repository URL, branch name, and credentials."
    exit 1
fi

# ---------------------------------------------------------------------------
# FR: Comparer le commit distant avec le dernier commit connu.
# EN: Compare the remote commit with the last known commit.
# ---------------------------------------------------------------------------
if [ "$LOCAL_KNOWN_COMMIT" = "$REMOTE_COMMIT" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Repository is already up to date."
    exit 0
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] New commit detected: $REMOTE_COMMIT"

# ---------------------------------------------------------------------------
# FR:
# Zone de traitement personnalisée.
# Ajoutez ici votre logique future (clone, téléchargement, déploiement, etc.).
#
# EN:
# Custom processing section.
# Add your future logic here (clone, download, deployment, etc.).
# ---------------------------------------------------------------------------

PROCESS_SUCCESS=true

# Example:
#
# git clone --depth 1 ...
# rsync ...
# deploy ...
#
# and set:
#
# PROCESS_SUCCESS=false
#
# if something fails.

# ---------------------------------------------------------------------------
# FR:
# N'enregistrer le commit que si le traitement a réussi.
#
# EN:
# Record the commit only if processing completed successfully.
# ---------------------------------------------------------------------------
if [ "$PROCESS_SUCCESS" = true ]; then

    TMP_FILE="${LAST_COMMIT_FILE}.tmp"

    echo "$REMOTE_COMMIT" > "$TMP_FILE"

    if mv "$TMP_FILE" "$LAST_COMMIT_FILE"; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Commit successfully recorded."
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Failed to update commit file."
        exit 1
    fi

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Update completed successfully."

else

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Processing failed."
    echo "Commit will not be recorded and will be retried later."
    exit 1

fi

exit 0
