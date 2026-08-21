#!/bin/bash

# Déterminer le dossier où se trouve ce script pour localiser le fichier de config
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
CONFIG_FILE="$SCRIPT_DIR/config.conf"

# --- CHARGEMENT DE LA CONFIGURATION ---
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "[-] Erreur : Fichier de configuration manquant ($CONFIG_FILE)"
    exit 1
fi

# --- PROTECTION CONTRE LES EXÉCUTIONS SIMULTANÉES ---
exec 200>"$LOCK_FILE"
flock -n 200 || { echo "[-] Une instance du script tourne déjà."; exit 0; }

# --- LECTURE DU DERNIER COMMIT CONNU ---
LOCAL_KNOWN_COMMIT=""
if [ -f "$LAST_COMMIT_FILE" ]; then
    LOCAL_KNOWN_COMMIT=$(cat "$LAST_COMMIT_FILE")
fi

# --- RÉCUPÉRATION DU COMMIT DISTANT ---
echo "[~] Vérification du dépôt distant..."
REMOTE_COMMIT=$(git ls-remote "$REPO_URL" "refs/heads/$BRANCH" 2>/dev/null | cut -f1)

# Vérification si la commande Git a fonctionné
if [ -z "$REMOTE_COMMIT" ]; then
    echo "[-] Erreur : Impossible de joindre le dépôt distant. Vérifiez l'URL ou vos accès."
    exit 1
fi

# --- COMPARAISON ET EXÉCUTION ---
if [ "$LOCAL_KNOWN_COMMIT" != "$REMOTE_COMMIT" ]; then
    echo "[+] Nouveau commit détecté : $REMOTE_COMMIT"
    
    # Enregistrer immédiatement le nouveau commit
    echo "$REMOTE_COMMIT" > "$LAST_COMMIT_FILE"
    
    # Exécuter le script cible
    if [ -x "$SCRIPT_TO_RUN" ]; then
        echo "[+] Lancement du script personnalisé..."
        "$SCRIPT_TO_RUN"
    else
        echo "[-] Erreur : Le script cible n'existe pas ou n'est pas exécutable ($SCRIPT_TO_RUN)."
        exit 1
    fi
else
    echo "[~] Le dépôt est déjà à jour. Aucun changement."
fi
