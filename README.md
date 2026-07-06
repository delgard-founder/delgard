# delgard

**La couche d'autorisation manquante entre agents IA.**

Les gateways existants (Palo Alto Prisma AIRS, Check Point/Lakera) sécurisent la relation
**agent → outil** : ils bloquent une injection de prompt ou une fuite de données quand un
agent appelle un outil (recherche web, lecture de fichier, etc.) via un serveur MCP.

`delgard` sécurise une relation différente et encore non couverte : **agent → agent**.
Quand un orchestrateur délègue une tâche à un sous-agent, quel scope exact ce sous-agent
a-t-il reçu, pour combien de temps, et peux-tu **prouver après coup**, de façon
inaltérable, ce qui s'est réellement passé ?

## Ce que ça fait

1. **Capability tokens signés** (Ed25519, courte durée de vie) — chaque délégation entre
   deux agents porte un scope explicite : ce que le sous-agent a le droit de faire, et
   rien de plus.
2. **Policy déclarative** (`agenttrust.yml`) — allow / block / approbation humaine requise,
   *deny by default* : une paire agent→agent non déclarée est bloquée automatiquement.
3. **Journal d'audit chaîné par hash** — chaque entrée contient le hash de la précédente.
   Toute modification a posteriori du journal est détectable (`delgard verify`).
4. **CLI** — `delgard init | verify | report`, protège automatiquement les clés générées
   (ajout au `.gitignore` local, pas juste un avertissement).

## Quickstart

```bash
git clone https://github.com/delgard-founder/delgard.git
cd delgard
pnpm install
pnpm build
pnpm demo
```

Résultat attendu :
- une action autorisée (`web_search`) passe,
- une action hors-scope (`file_write`) est bloquée,
- le journal d'audit est vérifié comme intact.

### Utiliser le CLI

```bash
node packages/cli/dist/index.js init      # crée agenttrust.yml + une paire de clés
node packages/cli/dist/index.js verify audit-demo.jsonl
node packages/cli/dist/index.js report agenttrust.yml
```

## Structure du repo

```
packages/core   → tokens, moteur de policy, journal d'audit (sans dépendance à un framework)
packages/cli    → delgard init | verify | report
examples/       → démo runnable en une commande (pnpm demo)
```

## Pourquoi ça existe

Les gateways de sécurité pour agents IA (Prisma AIRS, Check Point, Lakera) protègent déjà
très bien la frontière **agent → outil**. Aucun ne couvre l'autorisation fine et la preuve
d'audit pour la frontière **agent → agent** — exactement ce qui devient critique à mesure
que les architectures multi-agents (orchestrateur + sous-agents) se généralisent dans
l'écosystème TypeScript (Vercel AI SDK, Mastra, LangGraph.js, Claude Agent SDK).

## Statut

V0 — cœur technique fonctionnel et testé (tokens, policy, audit, CLI). Intégrations
officielles avec les frameworks TS (adapter Vercel AI SDK, etc.) à venir. Contributions
et retours bienvenus via les issues GitHub.

## Licence

MIT.
