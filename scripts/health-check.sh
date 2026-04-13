#!/usr/bin/env bash
# ============================================================================
# Health Check — Vérifie qu'un site web répond correctement
# ============================================================================
# Usage:
#   ./health-check.sh <base_url> [chemins séparés par des virgules]
#
# Exemples:
#   ./health-check.sh https://monsite.com
#   ./health-check.sh https://monsite.com /,/about,/contact,/api/health
#
# Codes de retour:
#   0 = Toutes les pages répondent correctement
#   1 = Au moins une page ne répond pas
# ============================================================================

set -euo pipefail

BASE_URL="${1:?Usage: $0 <base_url> [paths]}"
PATHS="${2:-/}"
TIMEOUT="${HEALTH_CHECK_TIMEOUT:-30}"
RETRIES="${HEALTH_CHECK_RETRIES:-3}"
RETRY_DELAY="${HEALTH_CHECK_RETRY_DELAY:-5}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

FAILED=0
TOTAL=0

check_url() {
    local url="$1"
    local attempt=0

    while [ $attempt -lt "$RETRIES" ]; do
        attempt=$((attempt + 1))
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT" "$url" 2>/dev/null || echo "000")

        if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 400 ]]; then
            echo -e "  ${GREEN}✅${NC} $url → HTTP $HTTP_CODE"
            return 0
        fi

        if [ $attempt -lt "$RETRIES" ]; then
            echo -e "  ${YELLOW}⏳${NC} $url → HTTP $HTTP_CODE (tentative $attempt/$RETRIES, retry dans ${RETRY_DELAY}s...)"
            sleep "$RETRY_DELAY"
        fi
    done

    echo -e "  ${RED}❌${NC} $url → HTTP $HTTP_CODE (échoué après $RETRIES tentatives)"
    return 1
}

echo "══════════════════════════════════════════"
echo "  Health Check : $BASE_URL"
echo "══════════════════════════════════════════"
echo ""

IFS=',' read -ra PATH_ARRAY <<< "$PATHS"

for path in "${PATH_ARRAY[@]}"; do
    path=$(echo "$path" | xargs)  # trim whitespace
    TOTAL=$((TOTAL + 1))
    if ! check_url "${BASE_URL}${path}"; then
        FAILED=$((FAILED + 1))
    fi
done

echo ""
echo "══════════════════════════════════════════"
PASSED=$((TOTAL - FAILED))
echo "  Résultat : $PASSED/$TOTAL pages OK"

if [ $FAILED -gt 0 ]; then
    echo -e "  ${RED}$FAILED page(s) en erreur${NC}"
    echo "══════════════════════════════════════════"
    exit 1
else
    echo -e "  ${GREEN}Tout est fonctionnel !${NC}"
    echo "══════════════════════════════════════════"
    exit 0
fi
