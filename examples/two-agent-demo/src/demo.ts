/**
 * Démo : un agent "orchestrator" délègue une tâche à un agent "research-subagent".
 * Le sous-agent tente 2 actions : une autorisée (web_search), une hors-scope (file_write).
 * Tout est loggé dans un journal d'audit inaltérable, qu'on vérifie à la fin.
 *
 * Lancer avec : pnpm demo
 */
import {
  createKeyPair,
  issueCapability,
  verifyCapability,
  isActionAllowed,
  evaluateDelegation,
  appendAuditEntry,
  verifyAuditLog,
  type PolicyDoc,
} from "delgard-core";

const AUDIT_LOG = "./audit-demo.jsonl";

const policy: PolicyDoc = {
  version: 1,
  rules: [{ from: "orchestrator", to: "research-subagent", allow: ["web_search"], maxBudget: 10 }],
};

async function main() {
  console.log("=== delgard — démo orchestrateur → sous-agent ===\n");

  // 1. L'orchestrateur consulte la policy avant de déléguer
  const evaluation = evaluateDelegation(policy, {
    from: "orchestrator",
    to: "research-subagent",
    requestedScope: ["web_search"],
  });
  console.log(`Policy check : ${evaluation.decision} — ${evaluation.reason}`);

  // 2. Si autorisé, l'orchestrateur émet un capability token scopé et signé
  const keys = await createKeyPair();
  const token = await issueCapability(
    { issuer: "orchestrator", subject: "research-subagent", scope: evaluation.grantedScope, ttlSeconds: 60 },
    keys.privateKey
  );
  console.log(`\nToken émis pour research-subagent, scope = [${evaluation.grantedScope.join(", ")}]`);

  // 3. Le sous-agent reçoit le token et tente d'agir
  const capability = await verifyCapability(token, keys.publicKey);

  // Cas 1 : action autorisée
  const canSearch = isActionAllowed(capability, "web_search");
  console.log(`\nTentative "web_search" → ${canSearch ? "✔ AUTORISÉ" : "✘ BLOQUÉ"}`);
  appendAuditEntry(AUDIT_LOG, {
    from: "orchestrator",
    to: "research-subagent",
    action: "web_search",
    decision: canSearch ? "allow" : "block",
    jti: capability.jti,
  });

  // Cas 2 : action HORS scope, jamais autorisée par le token même si le sous-agent la tente
  const canWriteFile = isActionAllowed(capability, "file_write");
  console.log(`Tentative "file_write" → ${canWriteFile ? "✔ AUTORISÉ" : "✘ BLOQUÉ"}`);
  appendAuditEntry(AUDIT_LOG, {
    from: "orchestrator",
    to: "research-subagent",
    action: "file_write",
    decision: canWriteFile ? "allow" : "block",
    jti: capability.jti,
  });

  // 4. Preuve d'audit : le journal est-il intact ?
  const integrity = verifyAuditLog(AUDIT_LOG);
  console.log(`\nIntégrité du journal d'audit : ${integrity.valid ? "✔ INTACT" : "✘ COMPROMIS"} (${integrity.entriesChecked} entrées)`);
  console.log(`\nLog complet : ${AUDIT_LOG}`);
}

main().catch(console.error);
