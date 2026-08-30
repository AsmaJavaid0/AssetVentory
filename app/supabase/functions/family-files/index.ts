import { jwtVerify, createRemoteJWKSet } from "npm:jose@5.10.0";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.57.4";

const FIREBASE_PROJECT_ID = "assetventory-3c93d";
const BUCKET = "family-files";
const FIREBASE_ISSUER = `https://securetoken.google.com/${FIREBASE_PROJECT_ID}`;
const FIREBASE_JWKS = createRemoteJWKSet(
  new URL("https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com"),
);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const supabaseAdmin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { autoRefreshToken: false, persistSession: false } },
);

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function safePart(value: string, label: string): string {
  if (!value || !/^[A-Za-z0-9_-]{1,120}$/.test(value)) {
    throw new Error(`Invalid ${label}.`);
  }
  return value;
}

async function authenticate(request: Request): Promise<string> {
  const header = request.headers.get("Authorization") ?? "";
  if (!header.startsWith("Bearer ")) throw new Error("Missing Firebase ID token.");
  const token = header.substring("Bearer ".length).trim();
  if (!token) throw new Error("Missing Firebase ID token.");

  const { payload } = await jwtVerify(token, FIREBASE_JWKS, {
    issuer: FIREBASE_ISSUER,
    audience: FIREBASE_PROJECT_ID,
  });

  if (payload.sub == null || typeof payload.sub !== "string") {
    throw new Error("Invalid Firebase user token.");
  }
  return payload.sub;
}

async function assertFamilyMember(userId: string, familyId: string) {
  const path = `${familyId}_${userId}`;
  const url = `https://firestore.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/databases/(default)/documents/family_members/${encodeURIComponent(path)}`;

  const response = await fetch(url, {
    headers: { Authorization: `Bearer ${await getFirebaseTokenFromContext()}` },
  });

  if (!response.ok) {
    throw new Error("Family membership could not be verified.");
  }
}

// The request token is passed through this async-local request context.
// It is set immediately before membership verification.
let requestFirebaseToken = "";
async function getFirebaseTokenFromContext(): Promise<string> {
  return requestFirebaseToken;
}

async function createUploadUrl(familyId: string, assetId: string, fileName: string, contentType: string) {
  const safeFamily = safePart(familyId, "family id");
  const safeAsset = safePart(assetId, "asset id");
  const extension = fileName.includes(".") ? fileName.split(".").pop()!.toLowerCase() : "bin";
  if (!/^[a-z0-9]{1,12}$/.test(extension)) throw new Error("Invalid file extension.");

  const fileId = crypto.randomUUID();
  const path = `${safeFamily}/${safeAsset}/${fileId}.${extension}`;
  const { data, error } = await supabaseAdmin.storage
    .from(BUCKET)
    .createSignedUploadUrl(path, { upsert: false });

  if (error || !data) throw new Error(error?.message ?? "Could not create upload URL.");
  return { path, token: data.token, contentType: contentType || "application/octet-stream" };
}

async function createDownloadUrl(familyId: string, path: string) {
  safePart(familyId, "family id");
  if (!path.startsWith(`${familyId}/`)) throw new Error("File does not belong to this family.");
  if (path.includes("..") || path.includes("\\")) throw new Error("Invalid file path.");

  const { data, error } = await supabaseAdmin.storage
    .from(BUCKET)
    .createSignedUrl(path, 300);
  if (error || !data) throw new Error(error?.message ?? "Could not create download URL.");
  return { url: data.signedUrl, expiresIn: 300 };
}

async function deleteFile(familyId: string, path: string) {
  safePart(familyId, "family id");
  if (!path.startsWith(`${familyId}/`) || path.includes("..") || path.includes("\\")) {
    throw new Error("Invalid file path.");
  }
  const { error } = await supabaseAdmin.storage.from(BUCKET).remove([path]);
  if (error) throw new Error(error.message);
  return { deleted: true };
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ error: "Method not allowed." }, 405);

  try {
    const authHeader = request.headers.get("Authorization") ?? "";
    requestFirebaseToken = authHeader.startsWith("Bearer ")
      ? authHeader.substring("Bearer ".length).trim()
      : "";

    const userId = await authenticate(request);
    const body = await request.json();
    const action = body?.action as string?;
    const familyId = safePart(body?.familyId as string, "family id");

    await assertFamilyMember(userId, familyId);

    if (action === "create-upload-url") {
      const assetId = safePart(body?.assetId as string, "asset id");
      const fileName = String(body?.fileName ?? "file.bin");
      const contentType = String(body?.contentType ?? "application/octet-stream");
      return json(await createUploadUrl(familyId, assetId, fileName, contentType));
    }

    if (action === "create-download-url") {
      return json(await createDownloadUrl(familyId, String(body?.path ?? "")));
    }

    if (action === "delete") {
      return json(await deleteFile(familyId, String(body?.path ?? "")));
    }

    return json({ error: "Unknown action." }, 400);
  } catch (error) {
    console.error("family-files error", error);
    return json({ error: error instanceof Error ? error.message : "Request failed." }, 403);
  } finally {
    requestFirebaseToken = "";
  }
});
