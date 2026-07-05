import { readFileSync } from "node:fs";
import { parse } from "yaml";

export interface DelegationRule {
  from: string;
  to: string; // "*" = n'importe quel sous-agent
  allow: string[];
  maxBudget?: number;
  requireApproval?: boolean;
}

export interface PolicyDoc {
  version: number;
  rules: DelegationRule[];
}

export type Decision = "allow" | "block" | "approval-required";

export interface DelegationRequest {
  from: string;
  to: string;
  requestedScope: string[];
  requestedBudget?: number;
}

export interface PolicyEvaluation {
  decision: Decision;
  matchedRule?: DelegationRule;
  grantedScope: string[];
  reason: string;
}

/** Charge et valide (basiquement) un fichier agenttrust.yml */
export function loadPolicy(path: string): PolicyDoc {
  const raw = readFileSync(path, "utf-8");
  const doc = parse(raw) as PolicyDoc;

  if (!doc || !Array.isArray(doc.rules)) {
    throw new Error(`agenttrust.yml invalide : la clé "rules" est absente ou n'est pas une liste (${path})`);
  }
  return doc;
}

/**
 * Évalue une demande de délégation contre la policy.
 * Règle par défaut si aucune ne matche : BLOCK (deny by default — pas d'exception implicite).
 */
export function evaluateDelegation(policy: PolicyDoc, request: DelegationRequest): PolicyEvaluation {
  const rule = policy.rules.find(
    (r) => r.from === request.from && (r.to === request.to || r.to === "*")
  );

  if (!rule) {
    return {
      decision: "block",
      grantedScope: [],
      reason: `Aucune règle ne couvre la délégation ${request.from} → ${request.to}. Deny by default.`,
    };
  }

  const grantedScope = request.requestedScope.filter(
    (action) => rule.allow.includes(action) || rule.allow.includes("*")
  );

  const outOfScope = request.requestedScope.filter((a) => !grantedScope.includes(a));
  if (outOfScope.length > 0) {
    return {
      decision: "block",
      matchedRule: rule,
      grantedScope,
      reason: `Actions hors scope autorisé : ${outOfScope.join(", ")}`,
    };
  }

  if (rule.maxBudget !== undefined && request.requestedBudget !== undefined && request.requestedBudget > rule.maxBudget) {
    return {
      decision: "block",
      matchedRule: rule,
      grantedScope,
      reason: `Budget demandé (${request.requestedBudget}) dépasse le maximum autorisé (${rule.maxBudget})`,
    };
  }

  if (rule.requireApproval) {
    return {
      decision: "approval-required",
      matchedRule: rule,
      grantedScope,
      reason: `Règle ${request.from} → ${request.to} exige une approbation humaine`,
    };
  }

  return {
    decision: "allow",
    matchedRule: rule,
    grantedScope,
    reason: `Autorisé par la règle ${request.from} → ${rule.to}`,
  };
}
