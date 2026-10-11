// GET /api/waitlist/export — CSV download, requires `Authorization: Bearer <ADMIN_TOKEN>`.
import { handleExport } from "../../../src/lib/export.js";

export function onRequestGet(context) {
  return handleExport(context);
}

export function onRequest(context) {
  return handleExport(context);
}
