# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Ce que fait ce dépôt

`setup.sh` est l'unique exécutable : un bootstrap **idempotent** qui installe les
outils CLI, écrit la config Claude Code dans `~/.claude/`, puis ajoute plugins et
MCP. Il n'y a ni build, ni lint, ni suite de tests — le « produit » est le script
lui-même et les templates qu'il déploie.

## Lancer / tester

```bash
./setup.sh                      # chemin Homebrew (installe rg/fd/jq/yq/gh/glab + rtk)
./setup.sh --skip-deps          # chemin Mise : outils déjà fournis, config seule
./setup.sh --no-plugins         # sans plugins
mise install && mise run bootstrap   # équivaut à ./setup.sh --skip-deps
```

Le script est **relançable sans danger** : c'est le seul moyen de le « tester ».
Pour itérer sans toucher à ton vrai `~/.claude`, redirige la cible via la variable
`CLAUDE_CONFIG_DIR` (lue ligne 12) :

```bash
CLAUDE_CONFIG_DIR=/tmp/cc-test ./setup.sh --skip-deps --no-plugins
```

Avant un commit, faire passer `shellcheck setup.sh` (non configuré mais attendu).

## Architecture

**Pipeline `main()`** (l'ordre compte) : `install_deps` → `install_bun` →
`ensure_rtk` → `ensure_claude` → `write_config` → `install_plugins` →
`install_mcp` → `recap`. Chaque étape est un *no-op* si déjà satisfaite.

**`templates/` est la source de vérité.** `write_config()` copie ces fichiers
verbatim dans `$CLAUDE_DIR` via `install_file()`. Modifier un fichier dans
`~/.claude` ne remonte pas ici — toujours éditer `templates/`.

**`settings.json` est le seul template transformé** : une passe `jq` y injecte
`--language`, retire `statusLine` si `--no-statusLine`, et retire le bloc `hooks`
(RTK) si `rtk` est absent du PATH. Les autres templates sont copiés tels quels.

**Idempotence = `install_file()`.** Tout déploiement de fichier doit passer par
cette fonction : elle saute si identique (`cmp -s`), sinon sauvegarde l'existant
en `*.bak-<horodatage>` avant d'écraser. Ne jamais écrire un fichier de config
en dehors d'elle.

**Deux chemins d'install, un seul code de config.** `--skip-deps` (utilisé par la
tâche Mise de `mise.toml`) saute uniquement l'installation des outils CLI ; tout
le reste est partagé. `rtk` est hors registre Mise : `ensure_rtk` tente
`brew` → `cargo` → message documenté, et le hook RTK n'est écrit que si `rtk`
finit dans le PATH.

## Modifications courantes

- **Ajouter/retirer un plugin** : éditer **les deux** tableaux `MARKETPLACES` et
  `PLUGINS` dans `setup.sh` (un plugin référence sa marketplace par son
  short-name). `warp` est délibérément exclu.
- **Ajouter un fichier de config global** : le déposer dans `templates/` + ajouter
  un appel `install_file` dans `write_config()`.
- **Ajouter un skill** : déposer son dossier dans `templates/skills/<nom>/` + ajouter
  `<nom>` au tableau `SKILLS`. `install_skill()` déploie chaque fichier via
  `install_file` (idempotent, sous-dossiers `references/` inclus).
- `set -euo pipefail` est actif : tout pipeline qui peut échouer « normalement »
  doit être gardé (`... || true`), comme c'est déjà fait pour les `claude plugin list`.

## Contraintes

- Compatible **macOS et Linux** (`OS="$(uname -s)"`), pas de dépendance à un OS.
- **Aucun secret versionné** : la clé context7 reste optionnelle et locale (voir
  `docs/MCP.md`). Ne jamais committer de token.
