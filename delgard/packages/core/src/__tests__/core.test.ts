import { describe, it, expect, beforeEach } from "vitest";
import { unlinkSync, existsSync, readFileSync, writeFileSync } from "node:fs";
import { createKeyPair, issueCapability, verifyCapability, isActionAllowed } from "../token.js";
import { evaluateDelegation, type PolicyDoc } from "../policy.js";
import { appendAuditEntry, verifyAuditLog } from "../audit.js";

describe("capability tokens", () => {
  it("émet et vérifie un token valide avec le bon scope", async () => {
    const keys = await createKeyPair();
    const token = await issueCapability(
      { issuer: "orchestrator", subject: "research-subagent", scope: ["web_search"] },
      keys.privateKey
    );
    const verified = await verifyCapability(token, keys.publicKey);

    expect(verified.issuer).toBe("orchestrator");
    expect(isActionAllowed(verified, "web_search")).toBe(true);
    expect(isActionAllowed(verified, "file_write")).toBe(false); // hors scope => refusé
  });
});

describe("policy engine", () => {
  const policy: PolicyDoc = {
    version: 1,
    rules: [{ from: "orchestrator", to: "research-subagent", allow: ["web_search"], maxBudget: 5 }],
  };

  it("bloque une action hors scope même si l'agent est connu", () => {
    const result = evaluateDelegation(policy, {
      from: "orchestrator",
      to: "research-subagent",
      requestedScope: ["file_write"],
    });
    expect(result.decision).toBe("block");
  });

  it("bloque par défaut une paire agent inconnue (deny by default)", () => {
    const result = evaluateDelegation(policy, {
      from: "orchestrator",
      to: "unknown-agent",
      requestedScope: ["web_search"],
    });
    expect(result.decision).toBe("block");
  });
});

describe("audit log tamper-evidence", () => {
  const logPath = "/tmp/delgard-test-audit.jsonl";

  beforeEach(() => {
    if (existsSync(logPath)) unlinkSync(logPath);
  });

  it("détecte une modification du log après coup", () => {
    appendAuditEntry(logPath, { from: "orchestrator", to: "research-subagent", action: "web_search", decision: "allow", jti: "abc" });
    appendAuditEntry(logPath, { from: "orchestrator", to: "research-subagent", action: "web_search", decision: "allow", jti: "def" });

    const before = verifyAuditLog(logPath);
    expect(before.valid).toBe(true);

    // on triche : on modifie une entrée directement dans le fichier
    const lines = readFileSync(logPath, "utf-8").trim().split("\n");
    const tampered = JSON.parse(lines[0]);
    tampered.action = "file_write"; // falsification
    lines[0] = JSON.stringify(tampered);
    writeFileSync(logPath, lines.join("\n") + "\n");

    const after = verifyAuditLog(logPath);
    expect(after.valid).toBe(false);
    expect(after.brokenAtSeq).toBe(0);
  });
});
