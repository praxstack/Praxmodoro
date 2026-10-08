// GET /api/waitlist/export: the whole list as CSV, for the founder only.
import { timingSafeEqual } from "./hash.js";
import { toCsv } from "./csv.js";
import { json, methodNotAllowed } from "./http.js";
import { API_HEADERS } from "./security-headers.js";

export const EXPORT_COLUMNS = Object.freeze(["email", "created_at", "fields", "source", "utm"]);
// A short admin token is too easy to guess; refuse to honour one.
export const MIN_ADMIN_TOKEN_LENGTH = 24;

function bearerToken(request) {
  const header = (request.headers.get("authorization") || "").trim();
  const match = /^Bearer\s+(\S+)$/i.exec(header);
  return match ? match[1] : "";
}

export async function handleExport({ request, env }, { now = () => new Date() } = {}) {
  if (request.method !== "GET") return methodNotAllowed(["GET"], "Use GET to download the waitlist.");

  const expected = typeof env.ADMIN_TOKEN === "string" ? env.ADMIN_TOKEN : "";
  if (expected && expected.length < MIN_ADMIN_TOKEN_LENGTH) {
    console.warn(`waitlist export: ADMIN_TOKEN is shorter than ${MIN_ADMIN_TOKEN_LENGTH} characters; export is disabled until it is replaced.`);
  }
  const authorized = expected.length >= MIN_ADMIN_TOKEN_LENGTH && (await timingSafeEqual(bearerToken(request), expected));
  if (!authorized) {
    return json({ ok: false, error: "Missing or wrong admin token." }, 401, { "WWW-Authenticate": 'Bearer realm="waitlist export"' });
  }

  try {
    const { results = [] } = await env.DB.prepare(`SELECT ${EXPORT_COLUMNS.join(", ")} FROM waitlist ORDER BY id`).all();
    const csv = toCsv(EXPORT_COLUMNS, results.map((row) => EXPORT_COLUMNS.map((column) => row[column])));
    const day = now().toISOString().slice(0, 10);
    return new Response(csv, {
      headers: {
        ...API_HEADERS,
        "Content-Type": "text/csv; charset=utf-8",
        "Content-Disposition": `attachment; filename="praxmodoro-waitlist-${day}.csv"`
      }
    });
  } catch (error) {
    console.error("waitlist export: unexpected error:", error instanceof Error ? error.message : String(error));
    return json({ ok: false, error: "Something went wrong on our side. Please try again in a minute." }, 500);
  }
}
