// POST /api/waitlist — join the beta waitlist. Logic lives in src/lib/waitlist.js.
import { handleWaitlist } from "../../src/lib/waitlist.js";

export function onRequestPost(context) {
  return handleWaitlist(context);
}

// Any other method reaches this and gets a 405 from the shared handler.
export function onRequest(context) {
  return handleWaitlist(context);
}
