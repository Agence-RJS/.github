#!/usr/bin/env bash
# ============================================================================
# Rollback — Restaurer un site vers un état précédent
# ============================================================================
# Usage:
#   ./rollback.sh <commit_sha> [branch]
#
# Exemples:
#   ./rollback.sh abc1234                    # Rollback vers ce commit sur la branche courante
#   ./rollback.sh abc1234 main               # Rollback vers ce commit sur main
#   ./rollback.sh HEAD~1                     # Rollback d'un commit en arrière
#
# Options (variables d'environnement):
#   ROLLBACK_METHOD     — "revert" (défaut, safe) ou "reset" (destructif)
#   MAX_ATTEMPTS        — Nombre max de tentatives (défaut: 2)
#   DRY_RUN             — "true" pour simuler sans modifier (défaut: false)
#   PUSH_AFTER_ROLLBACK — "true" pour pousser automatiquement (défaut: false)
#
# Codes de retour:
#   0 = Rollback réussi
#   1 = Rollback échoué
# ============================================================================

set -euo pipefail

TARGET="${1:?Usage: $0 <commit_sha|HEAD~N> [branch]}"
BRANCH="${2:-$(git rev-parse --abbrev-ref HEAD)}"
METHOD="${ROLLBACK_METHOD:-revert}"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-2}"
DRY_RUN="${DRY_RUN:-false}"
PUSH_AFTER="${PUSH_AFTER_ROLLBACK:-false}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "══════════════════════════════════════════"
echo "  Rollback"
echo "══════════════════════════════════════════"
echo ""
echo -e "  ${BLUE}Cible${NC}     : $TARGET"
echo -e "  ${BLUE}Branche${NC}   : $BRANCH"
echo -e "  ${BLUE}Méthode${NC}   : $METHOD"
echo -e "  ${BLUE}Dry run${NC}   : $DRY_RUN"
echo ""

# Vérifier qu'on est dans un repo git
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}❌ Ce n'est pas un dépôt Git${NC}"
    exit 1
fi

# Résoudre le SHA cible
TARGET_SHA=$(git rev-parse "$TARGET" 2>/dev/null || true)
if [ -z "$TARGET_SHA" ]; then
    echo -e "${RED}❌ Impossible de résoudre : $TARGET${NC}"
    exit 1
fi
echo -e "  ${BLUE}SHA cible${NC} : $TARGET_SHA"

# Sauvegarder l'état actuel
CURRENT_SHA=$(git rev-parse HEAD)
echo -e "  ${BLUE}SHA actuel${NC}: $CURRENT_SHA"
echo ""

if [ "$CURRENT_SHA" = "$TARGET_SHA" ]; then
    echo -e "${GREEN}✅ Déjà sur le commit cible, rien à faire.${NC}"
    exit 0
fi

if [ "$DRY_RUN" = "true" ]; then
    echo -e "${YELLOW}🔍 Mode DRY RUN — simulation uniquement${NC}"
    echo ""
    echo "Changements entre $TARGET_SHA et $CURRENT_SHA :"
    git log --oneline "$TARGET_SHA..$CURRENT_SHA"
    echo ""
    echo "Fichiers modifiés :"
    git diff --stat "$TARGET_SHA..$CURRENT_SHA"
    exit 0
fi

# Vérifier qu'il n'y a pas de changements non commités
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo -e "${YELLOW}⚠️  Changements non commités détectés. Stash en cours...${NC}"
    git stash push -m "rollback-auto-stash-$(date +%s)"
fi

# Basculer sur la branche cible
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" != "$BRANCH" ]; then
    echo -e "  Basculement sur $BRANCH..."
    git checkout "$BRANCH"
fi

# Tentatives de rollback
ATTEMPT=0
ROLLBACK_OK=false

while [ $ATTEMPT -lt "$MAX_ATTEMPTS" ] && [ "$ROLLBACK_OK" = "false" ]; do
    ATTEMPT=$((ATTEMPT + 1))
    echo -e "\n${BLUE}Tentative $ATTEMPT/$MAX_ATTEMPTS (méthode: $METHOD)${NC}"

    if [ "$METHOD" = "revert" ]; then
        echo "  Revert des commits entre $TARGET_SHA et HEAD..."
        if git revert --no-commit "$TARGET_SHA..HEAD" 2>/dev/null; then
            git commit -m "rollback: restauration vers $TARGET_SHA

Rollback automatique — les commits suivants ont été annulés :
$(git log --oneline "$TARGET_SHA..HEAD")"
            ROLLBACK_OK=true
        else
            echo -e "  ${YELLOW}⚠️  Revert a échoué, nettoyage...${NC}"
            git revert --abort 2>/dev/null || true

            if [ $ATTEMPT -ge "$MAX_ATTEMPTS" ]; then
                echo -e "  ${YELLOW}Fallback vers la méthode reset...${NC}"
                METHOD="reset"
                ATTEMPT=$((ATTEMPT - 1))
            fi
        fi
    elif [ "$METHOD" = "reset" ]; then
        echo -e "  ${YELLOW}⚠️  Reset dur vers $TARGET_SHA (irréversible)${NC}"
        if git reset --hard "$TARGET_SHA"; then
            ROLLBACK_OK=true
        fi
    fi
done

if [ "$ROLLBACK_OK" = "true" ]; then
    echo ""
    echo -e "${GREEN}✅ Rollback réussi !${NC}"
    echo "  Nouveau HEAD : $(git rev-parse HEAD)"

    if [ "$PUSH_AFTER" = "true" ]; then
        echo ""
        echo "  Poussée vers origin/$BRANCH..."
        if git push origin "$BRANCH" --force-with-lease; then
            echo -e "  ${GREEN}✅ Push réussi${NC}"
        else
            echo -e "  ${RED}❌ Push échoué${NC}"
            exit 1
        fi
    else
        echo ""
        echo -e "  ${YELLOW}ℹ️  N'oubliez pas de pousser : git push origin $BRANCH --force-with-lease${NC}"
    fi
else
    echo ""
    echo -e "${RED}❌ Rollback échoué après $MAX_ATTEMPTS tentatives${NC}"
    echo "  Actions manuelles recommandées :"
    echo "    git reset --hard $TARGET_SHA"
    echo "    git push origin $BRANCH --force-with-lease"
    exit 1
fi

echo ""
echo "══════════════════════════════════════════"
