# delgard

**La couche d'autorisation manquante entre agents IA.**

Les gateways existants (Palo Alto Prisma AIRS, Check Point/Lakera) sécurisent la relation
**agent → outil** (bloquer une injection de prompt, une fuite de données via un serveur MCP).

`delgard` sécurise la relation **agent → agent** : quand un orchestrateur délègue une
tâche à un sous-agent, quel scope exact ce sous-agent a-t-il reçu, pour combien de temps,
et peux-tu **prouver après coup**, de façon inaltérable, ce qui s'est passé ?

## Ce que ça fait

1. Émet des **capability tokens** signés (Ed25519) et scopés pour chaque délégation.
2. Applique une policy déclarative (`agenttrust.yml`) : allow / block / approbation humaine requise.
3. Écrit un **journal d'audit chaîné par hash** — toute modification a posteriori est détectable.
4. Deny by default : une paire agent→agent non déclarée dans la policy est bloquée.

## Quickstart (moins de 10 minutes)

```bash
git clone <ce repo>
cd delgard
pnpm install
pnpm demo
```

Tu devrais voir :
- une action autorisée (`web_search`) passer,
- une action hors-scope (`file_write`) bloquée,
- le journal d'audit vérifié comme intact.

Pour vérifier l'intégrité d'un journal d'audit existant :

```bash
pnpm --filter @delgard/cli exec delgard verify /tmp/two-agent-demo-audit.jsonl
```

## Structure du repo

```
packages/core   → tokens, policy engine, journal d'audit (le cœur, sans dépendance à un framework)
packages/cli    → delgard init | verify | report
examples/       → démo runnable en 1 commande
```

## Statut

V0 — en construction publique. Pas encore d'intégration officielle avec Vercel AI SDK /
Mastra / LangGraph.js (prévue ensuite) : pour l'instant, `packages/core` s'utilise directement
dans n'importe quel orchestrateur TypeScript, quel que soit le framework.

## Pourquoi ça existe

Voir la note de positionnement complète (comparaison avec Prisma AIRS, LangSmith, Braintrust,
et pourquoi la couche agent→agent est encore ouverte) → à venir dans `/docs`.
