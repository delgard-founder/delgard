#!/usr/bin/env node
import { writeFileSync, existsSync } from "node:fs";
import { createKeyPair, verifyAuditLog, loadPolicy } from "@delgard/core";

const DEFAULT_POLICY = `version: 1
rules:
  # Une règle = "de quel agent, vers quel agent, quelles actions autorisées"
  - from: orchestrator
    to: research-subagent
    allow: [web_search, file_read]
    maxBudget: 10
    requireApproval: false

  # to: "*" = s'applique à n'importe quel sous-agent recevant une délégation
  - from: orchestrator
    to: "*"
    allow: [file_write]
    requireApproval: true
`;

async function cmdInit() {
  if (existsSync("agenttrust.yml")) {
    console.log("agenttrust.yml existe déjà — rien à faire.");
  } else {
    writeFileSync("agenttrust.yml", DEFAULT_POLICY, "utf-8");
    console.log("✔ agenttrust.yml créé avec une policy d'exemple.");
  }

  const keys = await createKeyPair();
  writeFileSync(".delgard-keys.json", JSON.stringify(keys, null, 2), "utf-8");
  console.log("✔ Paire de clés Ed25519 générée dans .delgard-keys.json");
  console.log("⚠️  Ne commite JAMAIS ce fichier de clés dans git (ajoute-le à .gitignore).");
}

function cmdVerify(logPath: string) {
  const result = verifyAuditLog(logPath);
  if (result.valid) {
    console.log(`✔ Journal d'audit intègre — ${result.entriesChecked} entrées vérifiées.`);
  } else {
    console.error(`✘ INTÉGRITÉ COMPROMISE : ${result.reason}`);
    process.exitCode = 1;
  }
}

function cmdReport(policyPath: string) {
  const policy = loadPolicy(policyPath);
  console.log(`Policy chargée (v${policy.version}) — ${policy.rules.length} règle(s) :\n`);
  for (const rule of policy.rules) {
    const approval = rule.requireApproval ? " [approbation humaine requise]" : "";
    console.log(`  ${rule.from} → ${rule.to} : ${rule.allow.join(", ")}${approval}`);
  }
}

const [, , command, ...args] = process.argv;

switch (command) {
  case "init":
    await cmdInit();
    break;
  case "verify":
    cmdVerify(args[0] ?? "audit.jsonl");
    break;
  case "report":
    cmdReport(args[0] ?? "agenttrust.yml");
    break;
  default:
    console.log(`Usage: delgard <init|verify|report> [args]`);
}
