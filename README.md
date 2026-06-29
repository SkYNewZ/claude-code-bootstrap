# claude-code-bootstrap

Bootstrap d'un poste Claude Code calqué sur la config de référence : outils CLI,
`settings.json`, `CLAUDE.md` global, hook RTK, plugins et MCP context7.

**Idempotent** (relançable sans casser un poste déjà configuré), compatible
**macOS** et **Linux**. **Aucun secret** n'est inclus.

## Démarrage rapide

### Option A — Homebrew (recommandé, macOS + Linux)

```bash
cd claude-code-bootstrap
./setup.sh
```

### Option B — Mise (sans Homebrew)

[Mise](https://github.com/jdx/mise) fournit les outils CLI, puis le bootstrap
réutilise `setup.sh` pour la config :

```bash
cd claude-code-bootstrap
mise install          # ripgrep, fd, jq, yq, gh, glab, node, bun
mise run bootstrap    # config + plugins + MCP (= ./setup.sh --skip-deps)
```

## Options

| Flag | Effet | Défaut |
|------|-------|--------|
| `--language <lang>` | Langue de l'interface (`French`, `English`, …) | `French` |
| `--statusLine` / `--no-statusLine` | Active/désactive la status line `ccstatusline` | activée |
| `--no-plugins` | N'installe pas les plugins Claude Code | installe |
| `--skip-deps` | Saute les outils CLI (utilisé par le chemin Mise) | — |

```bash
./setup.sh --language English --no-statusLine        # anglais, sans status line
./setup.sh --no-plugins                              # sans plugins
mise run bootstrap-no-plugins                         # idem via Mise
```

## Ce qui est installé

- **Outils CLI** : `ripgrep` `fd` `jq` `yq` `gh` `glab` `bun` + **rtk** (Rust Token Killer, 60-90 % d'économie de tokens)
- **Config `~/.claude/`** : `settings.json` (hook RTK, permissions, status line, effort `xhigh`, langue), `CLAUDE.md`, `RTK.md`, `conventional-commits.md`, `rules/context7.md`
- **Plugins** (sauf `--no-plugins`) :
  - `superpowers`, `frontend-design`, `claude-md-management` (marketplace officielle)
  - `claude-mem`, `ui-ux-pro-max`, `understand-anything`, `ponytail`
- **MCP** : `context7` (global, keyless — voir [docs/MCP.md](docs/MCP.md))

> `warp` est volontairement ignoré. La feature bêta **Agent Teams** est
> désactivée par défaut → [docs/TEAMMATES.md](docs/TEAMMATES.md).

## Sécurité & idempotence

- Tout fichier de config existant est **sauvegardé** (`*.bak-<horodatage>`) avant écrasement, et laissé tel quel s'il est déjà identique.
- Aucune clé API / aucun token n'est versionné. La clé context7 reste optionnelle et locale (voir [docs/MCP.md](docs/MCP.md)).
- Le hook `rtk` n'est écrit dans `settings.json` que si `rtk` est réellement installé (sinon il est retiré pour ne pas casser les commandes Bash).

## Prérequis

- **Claude Code** : installé automatiquement s'il est absent (`https://claude.ai/install.sh`). Les plugins/MCP sont sautés tant que `claude` n'est pas dans le `PATH` — relance ton shell puis `./setup.sh`.
- **Homebrew** (option A) ou **Mise** (option B).

## Documentation

- [docs/MCP.md](docs/MCP.md) — context7 (clé optionnelle) + MCP Angular / Next.js par-projet
- [docs/TEAMMATES.md](docs/TEAMMATES.md) — activer la bêta Agent Teams
