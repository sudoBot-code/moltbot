import type { IncomingMessage, ServerResponse } from "node:http";
import type { SubsystemLogger } from "../logging/subsystem.js";
import type { HealthSummary } from "../commands/health.js";
import { HEALTH_REFRESH_INTERVAL_MS } from "./server-constants.js"; // Import constant for correct caching logic

// Options match the ones added to createGatewayHttpServer in server-http.ts
type HealthHandlerOptions = {
  getHealthCache: () => HealthSummary | null;
  refreshHealthSnapshot: (opts: { probe: boolean }) => Promise<HealthSummary>;
  logHealth: SubsystemLogger;
};

// The health endpoint should be GET /health
export async function handleHealthHttpRequest(
  req: IncomingMessage,
  res: ServerResponse,
  opts: HealthHandlerOptions,
): Promise<boolean> {
  // Only respond to GET /health
  if (req.method !== "GET" || req.url !== "/health") {
    return false;
  }

  const { getHealthCache, refreshHealthSnapshot, logHealth } = opts;
  const now = Date.now();
  const cached = getHealthCache();

  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Content-Type", "application/json; charset=utf-8");

  try {
    // Implement caching logic similar to the Gateway's internal health method
    if (cached && now - (cached.ts ?? 0) < HEALTH_REFRESH_INTERVAL_MS) {
      res.statusCode = 200;
      res.end(JSON.stringify(cached)); // Return cached HealthSummary
      return true;
    }

    // Force a fresh snapshot if the cache is stale or missing
    const healthSnapshot = await refreshHealthSnapshot({ probe: false });
    res.statusCode = 200;
    res.end(JSON.stringify(healthSnapshot));
  } catch (err) {
    logHealth.error(`Failed to generate health snapshot for HTTP: ${String(err)}`);
    res.statusCode = 500;
    res.end(JSON.stringify({ ok: false, error: "Internal Server Error" }));
  }

  return true;
}
