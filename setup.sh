#!/usr/bin/env bash
#
# Bootstrap Claude Code — calqué sur la config de référence.
# Idempotent, compatible macOS et Linux. Aucun secret inclus.
#
# Usage : ./setup.sh [--language <lang>] [--no-statusLine] [--no-plugins] [--skip-deps]
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES="$SCRIPT_DIR/templates"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

# --- Options ---------------------------------------------------------------
LANGUAGE="French"
STATUSLINE=true
INSTALL_PLUGINS=true
SKIP_DEPS=false   # utilisé par le chemin Mise : les outils CLI sont déjà fournis

usage() {
  cat <<'EOF'
Bootstrap Claude Code

Usage : ./setup.sh [options]

Options :
  --language <lang>     Langue de l'interface (défaut : French)
  --statusLine          Active la status line ccstatusline (défaut)
  --no-statusLine       Désactive la status line
  --no-plugins          N'installe pas les plugins Claude Code
  --skip-deps           Saute l'installation des outils CLI (rg/fd/jq/... ; pour le chemin Mise)
  -h, --help            Affiche cette aide

Exemple : ./setup.sh --language English --no-statusLine
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --language)              LANGUAGE="${2:?--language requiert une valeur}"; shift 2 ;;
    --statusLine)            STATUSLINE=true; shift ;;
    --no-statusLine)         STATUSLINE=false; shift ;;
    --no-plugins)            INSTALL_PLUGINS=false; shift ;;
    --skip-deps)             SKIP_DEPS=true; shift ;;
    -h|--help)               usage; exit 0 ;;
    *) echo "Option inconnue : $1" >&2; usage; exit 1 ;;
  esac
done

# --- Helpers ---------------------------------------------------------------
c_blue='\033[1;34m'; c_green='\033[1;32m'; c_yellow='\033[1;33m'; c_red='\033[1;31m'; c_off='\033[0m'
step() { printf "${c_blue}==>${c_off} %s\n" "$1"; }
ok()   { printf "${c_green}  ✓${c_off} %s\n" "$1"; }
warn() { printf "${c_yellow}  ⚠${c_off} %s\n" "$1"; }
err()  { printf "${c_red}  ✗${c_off} %s\n" "$1" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }

OS="$(uname -s)"   # Darwin | Linux

# Sauvegarde horodatée si le fichier existe et diffère de la source.
install_file() {
  local src="$1" dst="$2"
  if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
    ok "$(basename "$dst") déjà à jour"
    return
  fi
  if [ -f "$dst" ]; then
    local bak
    bak="$dst.bak-$(date +%Y%m%d-%H%M%S)"
    cp "$dst" "$bak"
    warn "$(basename "$dst") existait → sauvegardé dans $(basename "$bak")"
  fi
  cp "$src" "$dst"
  ok "$(basename "$dst") installé"
}

# Déploie un skill (dossier multi-fichiers) via install_file — idempotent.
install_skill() {
  local name="$1"
  local src="$TEMPLATES/skills/$name" f dst
  if [ ! -d "$src" ]; then warn "skill $name introuvable dans templates/skills/"; return; fi
  while IFS= read -r f; do
    dst="$CLAUDE_DIR/skills/$name/${f#"$src/"}"
    mkdir -p "$(dirname "$dst")"
    install_file "$f" "$dst"
  done < <(find "$src" -type f ! -name .DS_Store)
}

# Ajoute un répertoire au PATH dans le rc shell, une seule fois.
ensure_path() {
  local dir="$1" rc
  case "${SHELL##*/}" in
    zsh) rc="$HOME/.zshrc" ;;
    bash) rc="$HOME/.bashrc" ;;
    *) rc="$HOME/.profile" ;;
  esac
  case ":$PATH:" in *":$dir:"*) return ;; esac
  if [ -f "$rc" ] && grep -qF "$dir" "$rc"; then return; fi
  printf '\nexport PATH="%s:$PATH"\n' "$dir" >> "$rc"
  export PATH="$dir:$PATH"
  warn "Ajouté $dir au PATH dans $rc (relance ton shell pour le rendre permanent)"
}

# --- 1. Outils CLI ---------------------------------------------------------
install_deps() {
  if $SKIP_DEPS; then
    step "Outils CLI : sautés (--skip-deps)"
    return
  fi
  step "Installation des outils CLI"
  if have brew; then
    # ripgrep fd jq yq gh glab → Homebrew core (rtk : géré par ensure_rtk)
    local installed; installed="$(brew list --formula 2>/dev/null || true)"
    for pkg in ripgrep fd jq yq gh glab; do
      if printf '%s\n' "$installed" | grep -qx "$pkg"; then
        ok "$pkg déjà installé"
      else
        brew install "$pkg" && ok "$pkg installé" || warn "échec installation $pkg"
      fi
    done
  else
    err "Homebrew introuvable."
    if [ "$OS" = "Darwin" ]; then
      echo "    Installe Homebrew puis relance :"
      echo '    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    else
      echo "    Sur Linux : installe Homebrew (https://brew.sh) OU utilise le chemin Mise (voir README)."
    fi
    echo "    Alternative sans Homebrew : 'mise install' puis './setup.sh --skip-deps' (voir README)."
    exit 1
  fi
}

# bun : installeur officiel (cross-platform), requis pour ccstatusline.
install_bun() {
  if $SKIP_DEPS; then
    if have bun; then ok "bun présent"; else warn "bun absent (fourni par Mise ?)"; fi
    return
  fi
  if have bun; then ok "bun déjà installé"; return; fi
  step "Installation de bun (installeur officiel)"
  curl -fsSL https://bun.sh/install | bash
  ensure_path "$HOME/.bun/bin"
  have bun && ok "bun installé" || warn "bun installé mais hors PATH — relance ton shell"
}

# rtk : essentiel pour le hook. brew → cargo → documentation.
ensure_rtk() {
  if have rtk; then ok "rtk présent ($(rtk --version 2>/dev/null || echo '?'))"; return; fi
  step "Installation de rtk"
  if have brew; then
    brew install rtk && ok "rtk installé (brew)" || warn "échec brew install rtk — voir https://www.rtk-ai.app/"
  elif have cargo; then
    cargo install rtk && ok "rtk installé (cargo)" || warn "échec cargo install rtk — voir https://www.rtk-ai.app/"
  else
    warn "rtk non installable automatiquement. Voir https://www.rtk-ai.app/ (le hook RTK sera désactivé)."
  fi
}

# --- 2. Claude Code --------------------------------------------------------
ensure_claude() {
  if have claude; then ok "claude présent ($(claude --version 2>/dev/null || echo '?'))"; return; fi
  step "Installation de Claude Code (installeur officiel)"
  curl -fsSL https://claude.ai/install.sh | bash || warn "échec installeur — voir https://docs.claude.com/claude-code"
  ensure_path "$HOME/.local/bin"
  have claude || warn "claude installé mais hors PATH — relance ton shell puis relance ce script pour les plugins/MCP"
}

# --- 3. Fichiers de config -------------------------------------------------
# skills personnels (dossiers vendorés dans templates/skills/, déployés dans ~/.claude/skills/)
SKILLS=(llm-council graphify markitdown playwright-cli writing-adrs prd)

write_config() {
  step "Écriture de la config Claude ($CLAUDE_DIR)"
  mkdir -p "$CLAUDE_DIR/rules"

  install_file "$TEMPLATES/RTK.md"                  "$CLAUDE_DIR/RTK.md"
  install_file "$TEMPLATES/conventional-commits.md" "$CLAUDE_DIR/conventional-commits.md"
  install_file "$TEMPLATES/CLAUDE.md"               "$CLAUDE_DIR/CLAUDE.md"
  install_file "$TEMPLATES/rules/context7.md"       "$CLAUDE_DIR/rules/context7.md"

  local skill
  for skill in "${SKILLS[@]}"; do install_skill "$skill"; done

  # settings.json : template + language/statusLine/hook conditionnels en une passe jq.
  local rtk_present=true
  have rtk || { rtk_present=false; warn "rtk absent → hook RTK retiré de settings.json"; }
  local tmp; tmp="$(mktemp)"
  jq --arg lang "$LANGUAGE" --argjson sl "$STATUSLINE" --argjson rtk "$rtk_present" \
     '.language = $lang
      | (if $sl  then . else del(.statusLine) end)
      | (if $rtk then . else del(.hooks)      end)' \
     "$TEMPLATES/settings.json" > "$tmp"
  install_file "$tmp" "$CLAUDE_DIR/settings.json"
  rm -f "$tmp"
}

# --- 4. Plugins ------------------------------------------------------------
# marketplace short-name -> github repo
MARKETPLACES=(
  "claude-plugins-official=anthropics/claude-plugins-official"
  "thedotmack=thedotmack/claude-mem"
  "ui-ux-pro-max-skill=nextlevelbuilder/ui-ux-pro-max-skill"
  "understand-anything=Egonex-AI/Understand-Anything"
  "ponytail=DietrichGebert/ponytail"
)
# plugins à activer (warp volontairement ignoré)
PLUGINS=(
  "superpowers@claude-plugins-official"
  "frontend-design@claude-plugins-official"
  "claude-md-management@claude-plugins-official"
  "claude-mem@thedotmack"
  "ui-ux-pro-max@ui-ux-pro-max-skill"
  "understand-anything@understand-anything"
  "ponytail@ponytail"
)

install_plugins() {
  if ! $INSTALL_PLUGINS; then step "Plugins : sautés (--no-plugins)"; return; fi
  if ! have claude; then warn "claude absent → plugins sautés (relance après installation de Claude Code)"; return; fi
  step "Marketplaces & plugins Claude Code"

  local existing_mp; existing_mp="$(claude plugin marketplace list 2>/dev/null || true)"
  for entry in "${MARKETPLACES[@]}"; do
    local name="${entry%%=*}" repo="${entry#*=}"
    if printf '%s' "$existing_mp" | grep -q "$name"; then
      ok "marketplace $name déjà ajouté"
    else
      claude plugin marketplace add "$repo" >/dev/null 2>&1 && ok "marketplace $name ajouté" \
        || warn "échec ajout marketplace $name ($repo)"
    fi
  done

  local existing_pl; existing_pl="$(claude plugin list 2>/dev/null || true)"
  for plugin in "${PLUGINS[@]}"; do
    local short="${plugin%@*}"
    if printf '%s' "$existing_pl" | grep -q "$short"; then
      ok "plugin $short déjà installé"
    else
      claude plugin install "$plugin" >/dev/null 2>&1 && ok "plugin $short installé" \
        || warn "échec installation plugin $plugin"
    fi
  done
}

# --- 5. MCP context7 (keyless, sans secret) --------------------------------
install_mcp() {
  if ! have claude; then warn "claude absent → MCP context7 sauté"; return; fi
  step "MCP context7 (HTTP, keyless)"
  if claude mcp get context7 >/dev/null 2>&1; then
    ok "context7 déjà configuré"
  else
    claude mcp add --transport http context7 https://mcp.context7.com/mcp --scope user >/dev/null 2>&1 \
      && ok "context7 ajouté (scope user)" \
      || warn "échec ajout context7 — voir docs/MCP.md"
  fi
  warn "Clé API context7 optionnelle (limites plus hautes) : voir docs/MCP.md — aucun secret n'est inclus ici."
}

# --- Récap -----------------------------------------------------------------
recap() {
  cat <<EOF

$(printf "${c_green}Bootstrap terminé.${c_off}")

Config écrite dans : $CLAUDE_DIR
  langue=$LANGUAGE  statusLine=$STATUSLINE  plugins=$INSTALL_PLUGINS

Commandes à retenir :
  superpowers:using-superpowers   # démarrer une session dev
  /clear   /compact   /btw   /goal # gérer le contexte
  /simplify   /ponytail:ponytail-review   # fin de tâche
  claude --continue | --resume    # reprendre une session
  rtk gain | rtk gain --history   # économies de tokens

À lire : README.md · docs/MCP.md · docs/TEAMMATES.md (feature bêta optionnelle)
EOF
}

# --- Main ------------------------------------------------------------------
main() {
  step "Bootstrap Claude Code (OS=$OS)"
  install_deps
  install_bun
  ensure_rtk
  ensure_claude
  write_config
  install_plugins
  install_mcp
  recap
}
main
