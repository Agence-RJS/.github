#!/usr/bin/env bash
# ============================================================================
# Régression Visuelle — Compare des captures d'écran avant/après mise à jour
# ============================================================================
# Usage:
#   ./visual-regression.sh <action> <base_url> [pages]
#
# Actions:
#   capture-before  — Prendre les screenshots de référence (avant mise à jour)
#   capture-after   — Prendre les screenshots post-mise à jour
#   compare          — Comparer les screenshots before/after
#
# Exemples:
#   ./visual-regression.sh capture-before https://monsite.com /,/about
#   ./visual-regression.sh capture-after https://monsite.com /,/about
#   ./visual-regression.sh compare
#
# Prérequis:
#   npm install -g playwright pixelmatch pngjs
#   npx playwright install chromium --with-deps
#
# Variables d'environnement:
#   DIFF_THRESHOLD  — Seuil de différence en % (défaut: 5)
#   SCREENSHOT_DIR  — Répertoire des captures (défaut: ./screenshots)
# ============================================================================

set -euo pipefail

ACTION="${1:?Usage: $0 <capture-before|capture-after|compare> [base_url] [pages]}"
BASE_URL="${2:-}"
PAGES="${3:-/}"
THRESHOLD="${DIFF_THRESHOLD:-5}"
SCREENSHOT_DIR="${SCREENSHOT_DIR:-./screenshots}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

safe_name() {
    echo "$1" | sed 's/[^a-zA-Z0-9]/_/g'
}

capture_screenshots() {
    local phase="$1"
    local url="$2"
    local pages="$3"
    local dir="${SCREENSHOT_DIR}/${phase}"

    mkdir -p "$dir"

    IFS=',' read -ra PAGE_ARRAY <<< "$pages"
    for page in "${PAGE_ARRAY[@]}"; do
        page=$(echo "$page" | xargs)
        local name
        name=$(safe_name "$page")
        local full_url="${url}${page}"

        echo -e "  📸 Capture : $full_url"
        if npx playwright screenshot --full-page "$full_url" "${dir}/${name}.png" 2>/dev/null; then
            echo -e "  ${GREEN}✅${NC} Sauvegardé : ${dir}/${name}.png"
        else
            echo -e "  ${YELLOW}⚠️${NC}  Échec de capture pour $full_url"
        fi
    done
}

compare_screenshots() {
    local before_dir="${SCREENSHOT_DIR}/before"
    local after_dir="${SCREENSHOT_DIR}/after"
    local diff_dir="${SCREENSHOT_DIR}/diff"
    local report_file="${SCREENSHOT_DIR}/report.txt"

    mkdir -p "$diff_dir"

    if [ ! -d "$before_dir" ]; then
        echo -e "${RED}❌ Répertoire 'before' introuvable. Lancez capture-before d'abord.${NC}"
        exit 1
    fi
    if [ ! -d "$after_dir" ]; then
        echo -e "${RED}❌ Répertoire 'after' introuvable. Lancez capture-after d'abord.${NC}"
        exit 1
    fi

    FAILED=0
    TOTAL=0
    REPORT=""

    for before_file in "$before_dir"/*.png; do
        [ -f "$before_file" ] || continue
        local filename
        filename=$(basename "$before_file")
        local after_file="${after_dir}/${filename}"
        local diff_file="${diff_dir}/${filename}"

        TOTAL=$((TOTAL + 1))

        if [ ! -f "$after_file" ]; then
            echo -e "  ${YELLOW}⚠️${NC}  Pas de capture 'after' pour $filename"
            FAILED=$((FAILED + 1))
            continue
        fi

        DIFF_RESULT=$(node -e "
            const fs = require('fs');
            const { PNG } = require('pngjs');
            const pixelmatch = require('pixelmatch');

            const before = PNG.sync.read(fs.readFileSync('${before_file}'));
            const after = PNG.sync.read(fs.readFileSync('${after_file}'));

            const width = Math.min(before.width, after.width);
            const height = Math.min(before.height, after.height);
            const diff = new PNG({ width, height });

            const mismatch = pixelmatch(
                before.data, after.data, diff.data,
                width, height,
                { threshold: 0.1 }
            );

            const totalPixels = width * height;
            const diffPercent = ((mismatch / totalPixels) * 100).toFixed(2);

            fs.writeFileSync('${diff_file}', PNG.sync.write(diff));
            console.log(diffPercent);
        " 2>/dev/null || echo "-1")

        if [ "$DIFF_RESULT" = "-1" ]; then
            echo -e "  ${YELLOW}⚠️${NC}  Erreur de comparaison pour $filename"
            FAILED=$((FAILED + 1))
        elif (( $(echo "$DIFF_RESULT > $THRESHOLD" | bc -l) )); then
            echo -e "  ${RED}❌${NC} $filename : ${DIFF_RESULT}% de différence (seuil: ${THRESHOLD}%)"
            FAILED=$((FAILED + 1))
            REPORT="${REPORT}\n❌ ${filename}: ${DIFF_RESULT}%"
        else
            echo -e "  ${GREEN}✅${NC} $filename : ${DIFF_RESULT}% de différence"
            REPORT="${REPORT}\n✅ ${filename}: ${DIFF_RESULT}%"
        fi
    done

    echo ""
    echo "══════════════════════════════════════════"
    echo "  Régression visuelle : $((TOTAL - FAILED))/$TOTAL OK"
    echo -e "$REPORT"
    echo "══════════════════════════════════════════"

    echo -e "$REPORT" > "$report_file"

    if [ $FAILED -gt 0 ]; then
        exit 1
    fi
}

echo "══════════════════════════════════════════"
echo "  Régression Visuelle — $ACTION"
echo "══════════════════════════════════════════"
echo ""

case "$ACTION" in
    capture-before)
        [ -z "$BASE_URL" ] && { echo "URL requise pour capture-before"; exit 1; }
        capture_screenshots "before" "$BASE_URL" "$PAGES"
        ;;
    capture-after)
        [ -z "$BASE_URL" ] && { echo "URL requise pour capture-after"; exit 1; }
        capture_screenshots "after" "$BASE_URL" "$PAGES"
        ;;
    compare)
        compare_screenshots
        ;;
    *)
        echo "Action inconnue : $ACTION"
        echo "Actions valides : capture-before, capture-after, compare"
        exit 1
        ;;
esac
