import { appendFileSync, existsSync, readFileSync } from "node:fs";
import { createHash } from "node:crypto";

/**
 * Chaque entrée d'audit contient le hash de l'entrée précédente.
 * Si quelqu'un modifie une ligne du log après coup, tous les hashs suivants
 * ne correspondent plus : c'est détectable par verifyAuditLog().
 * C'est une hash chain simple (pas une blockchain), suffisante pour prouver
 * l'intégrité d'un log local en V0.
 */
export interface AuditEntry {
  seq: number;
  timestamp: string;
  from: string;
  to: string;
  action: string;
  decision: "allow" | "block" | "approval-required";
  jti: string;
  prevHash: string;
}

export interface StoredAuditEntry extends AuditEntry {
  hash: string;
}

const GENESIS_HASH = "0".repeat(64);

function computeHash(entry: AuditEntry): string {
  const canonical = JSON.stringify({ ...entry }, Object.keys(entry).sort());
  return createHash("sha256").update(canonical).digest("hex");
}

function readEntries(logPath: string): StoredAuditEntry[] {
  if (!existsSync(logPath)) return [];
  const lines = readFileSync(logPath, "utf-8").trim().split("\n").filter(Boolean);
  return lines.map((l) => JSON.parse(l) as StoredAuditEntry);
}

/** Ajoute une entrée au journal d'audit, chaînée à la précédente. */
export function appendAuditEntry(
  logPath: string,
  entry: Omit<AuditEntry, "seq" | "timestamp" | "prevHash">
): StoredAuditEntry {
  const existing = readEntries(logPath);
  const prevHash = existing.length > 0 ? existing[existing.length - 1].hash : GENESIS_HASH;

  const fullEntry: AuditEntry = {
    ...entry,
    seq: existing.length,
    timestamp: new Date().toISOString(),
    prevHash,
  };

  const hash = computeHash(fullEntry);
  const stored: StoredAuditEntry = { ...fullEntry, hash };

  appendFileSync(logPath, JSON.stringify(stored) + "\n", "utf-8");
  return stored;
}

export interface AuditVerification {
  valid: boolean;
  entriesChecked: number;
  brokenAtSeq?: number;
  reason?: string;
}

/** Rejoue toute la chaîne de hash et vérifie qu'aucune entrée n'a été altérée. */
export function verifyAuditLog(logPath: string): AuditVerification {
  const entries = readEntries(logPath);
  let expectedPrevHash = GENESIS_HASH;

  for (const stored of entries) {
    const { hash, ...entry } = stored;

    if (entry.prevHash !== expectedPrevHash) {
      return {
        valid: false,
        entriesChecked: entry.seq,
        brokenAtSeq: entry.seq,
        reason: `prevHash incohérent à l'entrée #${entry.seq} — le log a été modifié ou une entrée manque.`,
      };
    }

    const recomputed = computeHash(entry);
    if (recomputed !== hash) {
      return {
        valid: false,
        entriesChecked: entry.seq,
        brokenAtSeq: entry.seq,
        reason: `Hash invalide à l'entrée #${entry.seq} — le contenu de cette ligne a été modifié après coup.`,
      };
    }

    expectedPrevHash = hash;
  }

  return { valid: true, entriesChecked: entries.length };
}
