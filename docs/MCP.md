# MCP (Model Context Protocol)

Le script configure **context7** globalement (scope user). Les MCP par-projet
(Angular, Next.js, Stripe, Playwright…) se configurent au cas par cas.

## context7 (global) — déjà fait par le script

Ajouté en keyless (sans secret) :

```bash
claude mcp add --transport http context7 https://mcp.context7.com/mcp --scope user
```

### Clé API optionnelle (limites de rate plus hautes)

Le mode keyless est limité. Pour une clé gratuite : https://context7.com/dashboard
puis **remplace** l'entrée par une version avec header (ta propre clé, jamais
versionnée) :

```bash
claude mcp remove context7 --scope user
claude mcp add --transport http context7 https://mcp.context7.com/mcp \
  --scope user --header "CONTEXT7_API_KEY: <TA_CLE>"
```

## MCP par-projet

À lancer **depuis la racine du projet** concerné (scope `project` → écrit dans
`.mcp.json`, partageable avec l'équipe ; scope `local` → privé à ta machine).

### Angular

MCP officiel, démarré par la CLI Angular du projet :

```bash
claude mcp add angular-cli --scope project -- npx -y @angular/cli mcp
```

Réf : https://angular.dev/ai/mcp

### Next.js

```bash
claude mcp add nextjs --scope project -- npx -y next mcp
```

Réf : https://nextjs.org/mcp (vérifier la commande exacte selon la version de Next).

## Vérifier / déboguer

```bash
claude mcp list           # liste + health-check
claude mcp get context7   # détail d'un serveur
```
