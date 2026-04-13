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
