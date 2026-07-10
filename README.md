# delgard

**La couche d'autorisation manquante entre agents IA.**

Les gateways existants (Palo Alto Prisma AIRS, Check Point/Lakera) sécurisent la relation **agent → outil** : ils bloquent une injection de prompt ou une fuite de données quand un agent appelle un outil (recherche web, lecture de fichier, etc.) via un serveur MCP.

`delgard` sécurise une relation différente et encore non couverte : **agent → agent**. Quand un orchestrateur délègue une tâche à un sous-agent, quel scope exact ce sous-agent a-t-il reçu, pour combien de temps, et peux-tu **prouver après coup**, de façon inaltérable, ce qui s'est réellement passé ?

## 🚀 Installation

Deux façons d'utiliser delgard, selon ton besoin :

**En ligne de commande (CLI)** — pour initialiser un projet, vérifier un journal d'audit, générer un rapport :
```bash
npm install -g delgard
delgard init
```

**Dans ton code** — pour vérifier des capacités de façon programmatique dans ton propre agent :
```bash
npm install delgard-core
```

## ⚡ Exemple d'utilisation (30 secondes)

Voici comment vérifier qu'un sous-agent a le droit d'exécuter une action :

```typescript
import { verifyCapability, isActionAllowed } from 'delgard-core';

// publicKeyJwk : la clé publique Ed25519 de l'agent orchestrateur
const capability = await verifyCapability(subAgentToken, publicKeyJwk);

if (isActionAllowed(capability, 'web_search')) {
  console.log(`✅ ${capability.subject} autorisé : scope [${capability.scope.join(', ')}]`);
} else {
  console.log(`❌ ${capability.subject} hors scope — action refusée`);
}
```

`verifyCapability` lève une erreur automatiquement si la signature est invalide ou si le token a expiré — pas besoin de vérifier ça toi-même.

## 🎯 Ce que ça fait

1. **Capability tokens signés** (Ed25519, courte durée de vie) — chaque délégation entre deux agents porte un scope explicite : ce que le sous-agent a le droit de faire, et rien de plus.

2. **Policy déclarative** (`agenttrust.yml`) — allow / block / approbation humaine requise, *deny by default* : une paire agent→agent non déclarée est bloquée automatiquement.

3. **Journal d'audit chaîné par hash** — chaque entrée contient le hash de la précédente. Toute modification a posteriori du journal est détectable (`delgard verify`).

4. **CLI** — `delgard init | verify | report`, protège automatiquement les clés générées (ajout au `.gitignore` local, pas juste un avertissement).

## 🧭 Référence CLI

Une fois installé avec `npm install -g delgard` :

```bash
delgard init      # crée agenttrust.yml + une paire de clés, protège les clés dans .gitignore
delgard verify     # vérifie l'intégrité d'un journal d'audit
delgard report      # génère un rapport lisible à partir de la policy et de l'audit
```

## 🧪 Explorer le projet (démo complète)

Si tu veux voir delgard en action avec une démo à 2 agents, sans rien installer globalement :

```bash
git clone https://github.com/delgard-founder/delgard.git
cd delgard
pnpm install
pnpm demo
```

**Résultat attendu :**
- une action autorisée (`web_search`) passe,
- une action hors-scope (`file_write`) est bloquée,
- le journal d'audit est vérifié comme intact.

## 📦 Structure du repo

```
delgard/
├── packages/
│   ├── core/          # tokens, policy, audit — sans dépendance framework
│   └── cli/            # delgard init | verify | report
├── examples/
│   └── two-agent-demo/ # démo runnable via `pnpm demo`
└── agenttrust.yml       # exemple de policy déclarative
```

## 📄 Statut du projet

C'est une **V0**. Le cœur (tokens, policy, audit) est testé et fonctionnel. Les intégrations avec des frameworks agents (Vercel AI SDK, Mastra, LangChain...) n'existent pas encore. Les retours, surtout de la part de personnes qui construisent des systèmes multi-agents, sont les bienvenus — via les issues GitHub.

## Licence

Voir le fichier [LICENSE](./LICENSE).
