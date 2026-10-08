// GET /api/health — liveness check for the Functions runtime.
import { json, methodNotAllowed } from "../../src/lib/http.js";

export function onRequest({ request }) {
  if (request.method !== "GET" && request.method !== "HEAD") return methodNotAllowed(["GET"], "Use GET.");
  return json({ ok: true });
}
