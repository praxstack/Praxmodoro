// Runs for "/" and "/api/*" only (see public/_routes.json). Static assets never invoke it.
import { decoratePage } from "../src/lib/page.js";

export async function onRequest(context) {
  const response = await context.next();
  try {
    return decoratePage(response, context);
  } catch (error) {
    console.error("middleware: leaving response untouched:", error instanceof Error ? error.message : String(error));
    return response;
  }
}
