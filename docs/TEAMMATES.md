# Agent Teams / Teammates (bêta — optionnel)

Feature **bêta** volontairement **désactivée** dans le `settings.json` par défaut
(pour ne pas dérouter les nouveaux). À activer seulement si tu veux tester les
équipes d'agents.

## Activer

Ajoute ces deux entrées à `~/.claude/settings.json` :

```jsonc
{
  // ... config existante ...
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  },
  "teammateMode": "auto"
}
```

`env` est un objet : si tu as déjà une clé `env`, ajoute simplement la variable
dedans plutôt que de dupliquer l'objet.

## Désactiver

Retire les deux entrées (ou passe `teammateMode` à `"off"`) et relance Claude Code.
