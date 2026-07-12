#!/usr/bin/env node
/**
 * delgard push — envoie les nouvelles entrées du journal d'audit local
 * vers le dashboard hébergé.
 *
 * Usage :
 *   npx tsx packages/cli/src/push.ts <chemin-vers-audit.jsonl>
 *
 * Variables d'environnement requises :
 *   DELGARD_SUPABASE_URL  ex: https://osbqqbdvilcorhuoycyt.supabase.co
 *   DELGARD_API_KEY       la clé générée dans l'onglet "Clés API" du dashboard
 *
 * Ne jamais écrire la clé API en dur dans ce fichier ou dans un commit —
 * toujours via variable d'environnement.
 */
import { readFileSync, existsSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";

interface StoredAuditEntry {
  seq: number;
  timestamp: string;
  from: string;
  to: string;
  action: string;
  decision: "allow" | "block" | "approval-required";
  jti: string;
  prevHash: string;
  hash: string;
}

function readEntries(logPath: string): StoredAuditEntry[] {
  if (!existsSync(logPath)) return [];
  const lines = readFileSync(logPath, "utf-8").trim().split("\n").filter(Boolean);
  return lines.map((l) => JSON.parse(l) as StoredAuditEntry);
}

// Petit fichier local qui retient jusqu'où on a déjà synchronisé,
// pour ne jamais renvoyer deux fois la même entrée.
function stateFilePath(logPath: string): string {
  return join(dirname(logPath), ".delgard-push-state.json");
}

function readLastSyncedSeq(logPath: string): number {
  const p = stateFilePath(logPath);
  if (!existsSync(p)) return 0;
  try {
    return JSON.parse(readFileSync(p, "utf-8")).lastSyncedSeq ?? 0;
  } catch {
    return 0;
  }
}

function writeLastSyncedSeq(logPath: string, seq: number) {
  writeFileSync(stateFilePath(logPath), JSON.stringify({ lastSyncedSeq: seq }, null, 2));
}

async function main() {
  const logPath = process.argv[2];
  const supabaseUrl = process.env.DELGARD_SUPABASE_URL;
  const apiKey = process.env.DELGARD_API_KEY;

  if (!logPath) {
    console.error("Usage: push.ts <chemin-vers-audit.jsonl>");
    process.exit(1);
  }
  if (!supabaseUrl || !apiKey) {
    console.error(
      "Variables d'environnement manquantes.\n" +
        "  export DELGARD_SUPABASE_URL=https://xxxx.supabase.co\n" +
        "  export DELGARD_API_KEY=dlg_live_xxxx"
    );
    process.exit(1);
  }

  const entries = readEntries(logPath);
  const lastSynced = readLastSyncedSeq(logPath);
  const toSend = entries.filter((e) => e.seq > lastSynced);

  if (toSend.length === 0) {
    console.log("Rien à synchroniser — le dashboard est déjà à jour.");
    return;
  }

  // Traduit le format du log local vers le format attendu par le dashboard.
  const payload = toSend.map((e) => ({
    entry_hash: e.hash,
    prev_hash: e.prevHash,
    issuer: e.from,
    subject: e.to,
    action: e.action,
    decision: e.decision,
    occurred_at: e.timestamp,
  }));

  const res = await fetch(`${supabaseUrl}/functions/v1/sync-audit`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({ entries: payload }),
  });

  if (!res.ok) {
    const text = await res.text();
    console.error(`Échec de la synchronisation (${res.status}) : ${text}`);
    process.exit(1);
  }

  const maxSeq = Math.max(...toSend.map((e) => e.seq));
  writeLastSyncedSeq(logPath, maxSeq);
  console.log(`✅ ${toSend.length} entrée(s) synchronisée(s) vers le dashboard.`);
}

main();
