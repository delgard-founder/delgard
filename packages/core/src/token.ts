import { SignJWT, jwtVerify, generateKeyPair, exportJWK, importJWK, type JWK } from "jose";
import { randomUUID } from "node:crypto";

/**
 * Un "capability token" décrit EXACTEMENT ce qu'un agent (subject) a le droit
 * de faire quand un autre agent (issuer) lui délègue une tâche.
 *
 * C'est l'équivalent d'un token OAuth scopé, mais entre deux agents IA
 * au lieu d'entre un utilisateur et une API.
 */
export interface CapabilityClaims {
  /** Identifiant de l'agent qui délègue (ex: "orchestrator") */
  issuer: string;
  /** Identifiant de l'agent qui reçoit la délégation (ex: "research-subagent") */
  subject: string;
  /** Actions/outils autorisés pour cette délégation, ex: ["web_search", "file_read"] */
  scope: string[];
  /** Budget optionnel (ex: nombre max d'appels d'outils, ou coût max en tokens) */
  budget?: number;
  /** Durée de vie en secondes (par défaut 5 minutes — les délégations doivent être courtes) */
  ttlSeconds?: number;
}

export interface VerifiedCapability {
  issuer: string;
  subject: string;
  scope: string[];
  budget?: number;
  jti: string; // identifiant unique du token, utilisé aussi comme clé d'audit
  expiresAt: number;
}

export interface KeyPair {
  publicKey: JWK;
  privateKey: JWK;
}

/** Génère une paire de clés Ed25519 pour signer les tokens. À faire une fois, à stocker localement. */
export async function createKeyPair(): Promise<KeyPair> {
  const { publicKey, privateKey } = await generateKeyPair("EdDSA", { crv: "Ed25519", extractable: true });
  return {
    publicKey: await exportJWK(publicKey),
    privateKey: await exportJWK(privateKey),
  };
}

/** Émet un capability token signé pour une délégation agent → agent. */
export async function issueCapability(claims: CapabilityClaims, privateKeyJwk: JWK): Promise<string> {
  const privateKey = await importJWK(privateKeyJwk, "EdDSA");
  const jti = randomUUID();
  const ttl = claims.ttlSeconds ?? 300; // 5 minutes par défaut : une délégation ne doit pas traîner

  return new SignJWT({
    scope: claims.scope,
    budget: claims.budget,
  })
    .setProtectedHeader({ alg: "EdDSA" })
    .setIssuer(claims.issuer)
    .setSubject(claims.subject)
    .setJti(jti)
    .setIssuedAt()
    .setExpirationTime(`${ttl}s`)
    .sign(privateKey);
}

/** Vérifie un capability token. Lève une erreur si signature invalide ou expiré. */
export async function verifyCapability(token: string, publicKeyJwk: JWK): Promise<VerifiedCapability> {
  const publicKey = await importJWK(publicKeyJwk, "EdDSA");
  const { payload } = await jwtVerify(token, publicKey);

  return {
    issuer: payload.iss ?? "",
    subject: payload.sub ?? "",
    scope: (payload.scope as string[]) ?? [],
    budget: payload.budget as number | undefined,
    jti: payload.jti ?? "",
    expiresAt: payload.exp ?? 0,
  };
}

/** Vérifie qu'une action demandée est bien couverte par le scope du token. */
export function isActionAllowed(capability: VerifiedCapability, action: string): boolean {
  return capability.scope.includes(action) || capability.scope.includes("*");
}
