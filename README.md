# .github — Agence RJS

Infrastructure CI/CD partagée pour l'organisation Agence RJS.

## Mise à jour automatique avec rollback

Ce dépôt fournit un **workflow GitHub Actions réutilisable** qui permet à n'importe quel site de l'organisation de :

1. **Sauvegarder** l'état actuel avant toute mise à jour
2. **Mettre à jour** les dépendances et rebuilder
3. **Vérifier** que le site fonctionne (health check + régression visuelle)
4. **Rollback automatiquement** si quelque chose casse
5. **Notifier** l'équipe via une issue GitHub

### Fonctionnement

```
┌─────────────┐     ┌──────────┐     ┌───────────┐     ┌──────────┐
│  Snapshot    │────▶│  Update  │────▶│  Verify   │────▶│  Deploy  │
│  (backup)   │     │  (npm/   │     │  (health  │     │          │
│             │     │  composer)│     │  + visual)│     │          │
└─────────────┘     └────┬─────┘     └─────┬─────┘     └──────────┘
                         │                 │
                         │   Si échec      │   Si échec
                         ▼                 ▼
                    ┌──────────┐     ┌──────────┐
                    │ Rollback │◀────│ Rollback │
                    │          │     │          │
                    └────┬─────┘     └──────────┘
                         │
                         ▼
                    ┌──────────┐
                    │  Notify  │
                    │  (issue) │
                    └──────────┘
```

## Intégration rapide

### 1. Ajouter le workflow à votre dépôt de site

Créez `.github/workflows/update-site.yml` dans votre dépôt :

```yaml
name: "Mise à jour du site"

on:
  schedule:
    - cron: "0 8 * * 1"  # Chaque lundi à 8h
  workflow_dispatch:       # Ou déclenchement manuel

jobs:
  update:
    uses: Agence-RJS/.github/.github/workflows/update-and-rollback.yml@main
    with:
      site_url: "https://votre-site.com"
      update_command: "npm update"
      build_command: "npm run build"
      test_command: "npm test"
      health_check_paths: "/,/about,/contact"
    secrets:
      DEPLOY_TOKEN: ${{ secrets.DEPLOY_TOKEN }}
```

### 2. Paramètres disponibles

| Paramètre | Requis | Défaut | Description |
|---|---|---|---|
| `site_url` | oui | — | URL du site en production |
| `update_command` | oui | — | Commande de mise à jour (`npm update`, `composer update`, etc.) |
| `build_command` | non | `""` | Commande de build |
| `test_command` | non | `""` | Commande de tests |
| `deploy_command` | non | `""` | Commande de déploiement |
| `node_version` | non | `"20"` | Version Node.js |
| `health_check_paths` | non | `"/"` | Chemins à vérifier (séparés par `,`) |
| `visual_regression` | non | `false` | Activer la comparaison visuelle |
| `visual_regression_pages` | non | `"/"` | Pages pour les captures d'écran |
| `max_rollback_attempts` | non | `2` | Tentatives de rollback max |
| `notify_on_failure` | non | `true` | Créer une issue en cas d'échec |

### 3. Régression visuelle (optionnel)

Activez la comparaison de captures d'écran avant/après pour détecter les changements visuels :

```yaml
jobs:
  update:
    uses: Agence-RJS/.github/.github/workflows/update-and-rollback.yml@main
    with:
      site_url: "https://votre-site.com"
      update_command: "npm update"
      visual_regression: true
      visual_regression_pages: "/,/about,/portfolio"
```

Les captures sont sauvegardées en artifacts (7 jours) pour inspection manuelle.

## Scripts utilitaires

Des scripts standalone sont disponibles dans `scripts/` pour une utilisation locale :

### Health Check

```bash
# Vérifier que le site répond
./scripts/health-check.sh https://monsite.com /,/about,/contact

# Avec options avancées
HEALTH_CHECK_TIMEOUT=60 HEALTH_CHECK_RETRIES=5 \
  ./scripts/health-check.sh https://monsite.com
```

### Régression visuelle

```bash
# 1. Capturer les screenshots de référence
./scripts/visual-regression.sh capture-before https://monsite.com /,/about

# 2. (faire la mise à jour)

# 3. Capturer les screenshots post-mise à jour
./scripts/visual-regression.sh capture-after https://monsite.com /,/about

# 4. Comparer
./scripts/visual-regression.sh compare
```

### Rollback manuel

```bash
# Simuler un rollback (dry run)
DRY_RUN=true ./scripts/rollback.sh abc1234

# Rollback via revert (safe, conserve l'historique)
./scripts/rollback.sh abc1234

# Rollback via reset (destructif, réécrit l'historique)
ROLLBACK_METHOD=reset ./scripts/rollback.sh abc1234

# Rollback + push automatique
PUSH_AFTER_ROLLBACK=true ./scripts/rollback.sh HEAD~1
```

## Exemples pour les projets Agence RJS

### Front-end JavaScript/TypeScript (talents-view, bonappli-front, app-ra-front, etc.)

```yaml
with:
  site_url: "https://dashboard.talents-view.com"
  update_command: "npm update"
  build_command: "npm run build"
  test_command: "npm test"
  health_check_paths: "/,/login"
  visual_regression: true
  visual_regression_pages: "/,/login"
```

### Back-end Node.js / NestJS (microservices, bonappli-backend, crm-strapi-bdd, etc.)

```yaml
with:
  site_url: "https://api.monservice.com"
  update_command: "npm update"
  build_command: "npm run build"
  test_command: "npm test"
  health_check_paths: "/health,/api/status"
  visual_regression: false
```

### Back-end PHP (quizz-securite-axione-backend, fntv, rjs-tools, etc.)

```yaml
with:
  site_url: "https://monsite.com"
  update_command: "composer update --no-dev"
  build_command: ""
  test_command: "php vendor/bin/phpunit"
  health_check_paths: "/,/api/health"
```

### Site vitrine / portfolio (agence-rjs, wagner-avocat, agence-waiting-page, etc.)

```yaml
with:
  site_url: "https://agence-rjs.com"
  update_command: "npm update"
  build_command: "npm run build"
  test_command: ""
  health_check_paths: "/,/about,/contact"
  visual_regression: true
  visual_regression_pages: "/,/about,/contact"
```

### Strapi CMS (crm-strapi-bdd)

```yaml
with:
  site_url: "https://admin.moncrm.com"
  update_command: "npm update"
  build_command: "npm run build"
  test_command: ""
  health_check_paths: "/admin,/_health"
```

## Vérification pré-déploiement (preview-verify)

Le workflow `preview-verify.yml` compare un **environnement de preview** à la
**production** pour garantir zéro régression visible par les clients :

1. **Smoke test** — chaque route critique répond avec le bon code HTTP et le bon contenu
2. **Régression visuelle** — comparaison pixel par pixel entre production et preview (seuil configurable, défaut 2%)
3. **Taille du bundle** — détection des pages anormalement volumineuses
4. **Verdict** — feu vert ou blocage du merge

```yaml
jobs:
  verify:
    uses: Agence-RJS/.github/.github/workflows/preview-verify.yml@main
    with:
      preview_url: "https://preview-abc123.vercel.app"
      production_url: "https://monsite.com"
      routes: "/,200,Bienvenue|/about,200,À propos|/contact,200,Formulaire"
      visual_pages: "/,/about,/contact"
      visual_threshold: 2
      max_response_time: 3000
```

### Script smoke-test (usage local)

```bash
# Créez un fichier routes.csv :
cat > routes.csv << 'EOF'
/,200,Bienvenue
/about,200,À propos
/contact,200,Formulaire
/api/health,200,ok
EOF

# Lancez le smoke test :
./scripts/smoke-test.sh https://monsite.com routes.csv
```

## Routine Claude Code (autonome)

Pour configurer une Routine autonome sur [claude.ai/code/routines](https://claude.ai/code/routines),
utilisez le prompt ci-dessous. La Routine ouvre des PR mais **ne merge jamais** —
un humain valide toujours avant déploiement.

### Prompt recommandé

```
Tu es responsable de la maintenance hebdomadaire des sites actifs
d'Agence RJS.

REPOS ACTIFS :
- easy-crm, portfolio, florifile, ideo-habitat
- Bonappli2026, bonappli-backend, bonappli-front
- agence-rjs, wagner-avocat, CRM

RÈGLE ABSOLUE : ZÉRO IMPACT CLIENT
Les utilisateurs finaux ne doivent jamais voir de régression,
page cassée, erreur 500, ou changement visuel non voulu.

ÉTAPES (par repo, séquentiellement) :

1. VÉRIFICATION PRÉ-UPDATE
   - Lire le package.json (ou composer.json)
   - Lister les mises à jour disponibles avec `npm outdated`
   - BLOQUER toute montée de version majeure (ex: 18.x → 19.x)
     → Ouvrir une issue séparée au lieu d'upgrader

2. MISE À JOUR SAFE
   - Créer une branche "auto-update-YYYYMMDD"
   - Exécuter `npm update` (mineures + patches uniquement)
   - Si le projet a un lockfile, s'assurer qu'il est mis à jour

3. BUILD & TESTS
   - `npm run build` — si échec → abandonner, ouvrir une issue
   - `npm test` (si disponible) — si échec → abandonner, ouvrir une issue
   - `npm run lint` (si disponible) — si échec → abandonner

4. VÉRIFICATION PRE-DEPLOY (si un preview URL est disponible)
   - Comparer visuellement le preview vs la production
   - Tester chaque route connue (/, /about, /login, etc.)
   - Vérifier que le temps de réponse est < 3 secondes
   - Si la différence visuelle dépasse 2% → BLOQUER

5. PR SEULEMENT SI TOUT EST VERT
   - Titre : "🤖 Maj dépendances — YYYYMMDD"
   - Corps : diff package.json, résumé des changements, résultat
     des vérifications (routes, visuel, build, tests)
   - Label : "automated"
   - ⚠️ NE JAMAIS MERGER — laisser un humain valider

6. RÉSUMÉ FINAL
   Poster un récapitulatif :
   ✅ Repos mis à jour (PR ouverte)
   ⚠️ Repos avec version majeure disponible (issue créée)
   ❌ Repos en erreur (issue créée avec les logs)
   ⏭️ Repos skippés (inactifs >30j)

SI DOUTE → NE PAS MODIFIER. Ouvrir une issue pour demander une
décision humaine. Mieux vaut ne rien faire que casser un site en prod.
```

### Configuration

- **Trigger** : Schedule hebdomadaire (lundi 8h)
- **Repos** : sélectionner uniquement les repos actifs listés ci-dessus
- **Connecteurs** : Slack (pour les notifications de résumé)
