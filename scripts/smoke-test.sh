#!/usr/bin/env bash
# ============================================================================
# Smoke Test — Vérifie les routes critiques et le contenu attendu
# ============================================================================
# Usage:
#   ./smoke-test.sh <base_url> <routes_file>
#
# Le fichier de routes est un CSV : chemin,code_http_attendu,contenu_attendu
# Exemple (routes.csv) :
#   /,200,Bienvenue
#   /about,200,À propos
#   /contact,200,Formulaire
#   /api/health,200,ok
#   /page-inexistante,404,
#
# Codes de retour:
#   0 = Toutes les routes OK
#   1 = Au moins une route en erreur
# ============================================================================

set -euo pipefail

BASE_URL="${1:?Usage: $0 <base_url> <routes_file>}"
ROUTES_FILE="${2:?Usage: $0 <base_url> <routes_file>}"
TIMEOUT="${SMOKE_TEST_TIMEOUT:-15}"
MAX_RESPONSE_TIME="${SMOKE_MAX_RESPONSE_TIME:-5000}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ ! -f "$ROUTES_FILE" ]; then
    echo -e "${RED}❌ Fichier de routes introuvable : $ROUTES_FILE${NC}"
    exit 1
fi

FAILED=0
SLOW=0
TOTAL=0

echo "══════════════════════════════════════════"
echo "  Smoke Test : $BASE_URL"
echo "══════════════════════════════════════════"
echo ""

while IFS=',' read -r path expected_code expected_content || [ -n "$path" ]; do
    # ignorer les commentaires et lignes vides
    [[ "$path" =~ ^#.*$ || -z "$path" ]] && continue

    path=$(echo "$path" | xargs)
    expected_code=$(echo "$expected_code" | xargs)
    expected_content=$(echo "$expected_content" | xargs)
    TOTAL=$((TOTAL + 1))

    URL="${BASE_URL}${path}"

    RESPONSE=$(curl -s -w "\n%{http_code}\n%{time_total}" --max-time "$TIMEOUT" "$URL" 2>/dev/null || echo -e "\n000\n0")

    BODY=$(echo "$RESPONSE" | sed '$d' | sed '$d')
    HTTP_CODE=$(echo "$RESPONSE" | tail -2 | head -1)
    TIME_TOTAL=$(echo "$RESPONSE" | tail -1)
    TIME_MS=$(echo "$TIME_TOTAL" | awk '{printf "%.0f", $1 * 1000}')

    PASS=true
    DETAILS=""

    # Vérifier le code HTTP
    if [ -n "$expected_code" ] && [ "$HTTP_CODE" != "$expected_code" ]; then
        PASS=false
        DETAILS="HTTP $HTTP_CODE (attendu $expected_code)"
    fi

    # Vérifier le contenu
    if [ -n "$expected_content" ] && ! echo "$BODY" | grep -qi "$expected_content"; then
        PASS=false
        if [ -n "$DETAILS" ]; then
            DETAILS="$DETAILS + contenu '$expected_content' absent"
        else
            DETAILS="contenu '$expected_content' absent"
        fi
    fi

    # Vérifier le temps de réponse
    if [ "$TIME_MS" -gt "$MAX_RESPONSE_TIME" ] 2>/dev/null; then
        SLOW=$((SLOW + 1))
        DETAILS="${DETAILS:+$DETAILS + }${TIME_MS}ms (lent, seuil: ${MAX_RESPONSE_TIME}ms)"
    fi

    if [ "$PASS" = true ]; then
        echo -e "  ${GREEN}✅${NC} $path → HTTP $HTTP_CODE (${TIME_MS}ms)"
    else
        echo -e "  ${RED}❌${NC} $path → $DETAILS"
        FAILED=$((FAILED + 1))
    fi

done < "$ROUTES_FILE"

echo ""
echo "══════════════════════════════════════════"
PASSED=$((TOTAL - FAILED))
echo "  Résultat : $PASSED/$TOTAL routes OK"

if [ $SLOW -gt 0 ]; then
    echo -e "  ${YELLOW}⚠️  $SLOW route(s) lente(s)${NC}"
fi

if [ $FAILED -gt 0 ]; then
    echo -e "  ${RED}❌ $FAILED route(s) en erreur${NC}"
    echo "══════════════════════════════════════════"
    exit 1
else
    echo -e "  ${GREEN}✅ Tout est fonctionnel !${NC}"
    echo "══════════════════════════════════════════"
    exit 0
fi
