// flow-walker Worker: store and serve HTML reports via R2, landing page with live metrics

interface Env {
  BUCKET: R2Bucket;
}

interface Stats {
  totalReports: number;
  totalBytes: number;
  lastPushAt: string;
  recentRuns: { id: string; uploadedAt: string; sizeBytes: number }[];
}

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

const TTL_DAYS = 30;
const MAX_UPLOAD_BYTES = 20 * 1024 * 1024; // 20MB
const RATE_LIMIT_PER_DAY = 100;
const STATS_KEY = 'stats.json';
const MAX_RECENT_RUNS = 10;

// Simple in-memory rate limiting (resets on Worker restart, which is fine for v1)
const uploadCounts = new Map<string, { count: number; resetAt: number }>();

function isRateLimited(ip: string): boolean {
  const now = Date.now();
  const entry = uploadCounts.get(ip);
  if (!entry || now > entry.resetAt) {
    uploadCounts.set(ip, { count: 1, resetAt: now + 86400000 });
    return false;
  }
  entry.count++;
  return entry.count > RATE_LIMIT_PER_DAY;
}

async function loadStats(env: Env): Promise<Stats> {
  const obj = await env.BUCKET.get(STATS_KEY);
  if (!obj) {
    return { totalReports: 0, totalBytes: 0, lastPushAt: '', recentRuns: [] };
  }
  try {
    return await obj.json<Stats>();
  } catch {
    return { totalReports: 0, totalBytes: 0, lastPushAt: '', recentRuns: [] };
  }
}

async function updateStats(env: Env, runId: string, sizeBytes: number): Promise<void> {
  const stats = await loadStats(env);
  stats.totalReports++;
  stats.totalBytes += sizeBytes;
  stats.lastPushAt = new Date().toISOString();
  stats.recentRuns.unshift({ id: runId, uploadedAt: stats.lastPushAt, sizeBytes });
  if (stats.recentRuns.length > MAX_RECENT_RUNS) {
    stats.recentRuns = stats.recentRuns.slice(0, MAX_RECENT_RUNS);
  }
  await env.BUCKET.put(STATS_KEY, JSON.stringify(stats), {
    httpMetadata: { contentType: 'application/json' },
  });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    // CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }

    // POST /runs — upload report
    if (request.method === 'POST' && url.pathname === '/runs') {
      return handleUpload(request, env);
    }

    // GET /runs/:id — serve report
    const runMatch = url.pathname.match(/^\/runs\/([A-Za-z0-9_-]{6,20})$/);
    if (request.method === 'GET' && runMatch) {
      return handleGetReport(runMatch[1], env);
    }

    // GET /api/stats — raw stats JSON
    if (request.method === 'GET' && url.pathname === '/api/stats') {
      const stats = await loadStats(env);
      return Response.json(stats, { headers: CORS_HEADERS });
    }

    // GET / — landing page
    if (request.method === 'GET' && url.pathname === '/') {
      return handleLandingPage(request, env);
    }

    return Response.json(
      { error: { code: 'NOT_FOUND', message: 'Not found' } },
      { status: 404, headers: CORS_HEADERS },
    );
  },
};

async function handleUpload(request: Request, env: Env): Promise<Response> {
  // Rate limit by IP
  const ip = request.headers.get('CF-Connecting-IP') || 'unknown';
  if (isRateLimited(ip)) {
    return Response.json(
      { error: { code: 'RATE_LIMITED', message: 'Upload limit exceeded (100/day)' } },
      { status: 429, headers: CORS_HEADERS },
    );
  }

  // Validate content type
  const contentType = request.headers.get('Content-Type') || '';
  if (!contentType.includes('text/html') && !contentType.includes('application/octet-stream') && !contentType.includes('multipart/form-data')) {
    return Response.json(
      { error: { code: 'INVALID_INPUT', message: 'Content-Type must be text/html or application/octet-stream' } },
      { status: 400, headers: CORS_HEADERS },
    );
  }

  // Validate size
  const contentLength = parseInt(request.headers.get('Content-Length') || '0', 10);
  if (contentLength > MAX_UPLOAD_BYTES) {
    return Response.json(
      { error: { code: 'TOO_LARGE', message: `Report exceeds ${MAX_UPLOAD_BYTES / 1024 / 1024}MB limit` } },
      { status: 413, headers: CORS_HEADERS },
    );
  }

  // Get run ID from header or generate one
  const runId = request.headers.get('X-Run-ID') || generateId();
  if (!/^[A-Za-z0-9_-]{6,20}$/.test(runId)) {
    return Response.json(
      { error: { code: 'INVALID_INPUT', message: 'Invalid run ID format' } },
      { status: 400, headers: CORS_HEADERS },
    );
  }

  // Read body
  const body = await request.arrayBuffer();
  if (body.byteLength === 0) {
    return Response.json(
      { error: { code: 'INVALID_INPUT', message: 'Empty body' } },
      { status: 400, headers: CORS_HEADERS },
    );
  }

  // Store in R2
  const key = `runs/${runId}/report.html`;
  const expiresAt = new Date(Date.now() + TTL_DAYS * 86400000).toISOString();

  await env.BUCKET.put(key, body, {
    httpMetadata: { contentType: 'text/html; charset=utf-8' },
    customMetadata: { expiresAt, uploadedAt: new Date().toISOString() },
  });

  // Update stats (best-effort — don't block the response on failure)
  try {
    await updateStats(env, runId, body.byteLength);
  } catch { /* stats update failure should not break push */ }

  const baseUrl = new URL(request.url).origin;
  const reportUrl = `${baseUrl}/runs/${runId}`;

  return Response.json(
    { url: reportUrl, id: runId, expiresAt },
    { status: 201, headers: CORS_HEADERS },
  );
}

async function handleGetReport(runId: string, env: Env): Promise<Response> {
  const key = `runs/${runId}/report.html`;
  const object = await env.BUCKET.get(key);

  if (!object) {
    return Response.json(
      { error: { code: 'NOT_FOUND', message: `Run ${runId} not found or expired` } },
      { status: 404, headers: CORS_HEADERS },
    );
  }

  // Check expiry from metadata
  const expiresAt = object.customMetadata?.expiresAt;
  if (expiresAt && new Date(expiresAt) < new Date()) {
    // Expired — delete and return 404
    await env.BUCKET.delete(key);
    return Response.json(
      { error: { code: 'EXPIRED', message: `Run ${runId} has expired` } },
      { status: 410, headers: CORS_HEADERS },
    );
  }

  return new Response(object.body, {
    headers: {
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'public, max-age=3600',
      ...CORS_HEADERS,
    },
  });
}

async function handleLandingPage(request: Request, env: Env): Promise<Response> {
  const stats = await loadStats(env);
  const baseUrl = new URL(request.url).origin;
  const html = buildLandingPage(stats, baseUrl);
  return new Response(html, {
    headers: {
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'public, max-age=60',
      ...CORS_HEADERS,
    },
  });
}

function formatBytes(bytes: number): string {
  if (bytes === 0) return '0 B';
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  if (bytes < 1024 * 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  return `${(bytes / (1024 * 1024 * 1024)).toFixed(1)} GB`;
}

function timeAgo(iso: string): string {
  if (!iso) return 'never';
  const diff = Date.now() - new Date(iso).getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 1) return 'just now';
  if (mins < 60) return `${mins}m ago`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  return `${days}d ago`;
}

function buildLandingPage(stats: Stats, baseUrl: string): string {
  const recentRows = stats.recentRuns
    .map(
      (r) => `
        <a href="${baseUrl}/runs/${r.id}" class="run-row">
          <span class="run-id">${r.id}</span>
          <span class="run-size">${formatBytes(r.sizeBytes)}</span>
          <span class="run-time">${timeAgo(r.uploadedAt)}</span>
        </a>`,
    )
    .join('');

  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>flow-walker — Map your app. Run your flows. Share results.</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    background: #0a0a0a; color: #e0e0e0; line-height: 1.6;
    min-height: 100vh;
  }
  a { color: #6ee7b7; text-decoration: none; }
  a:hover { text-decoration: underline; }

  .container { max-width: 720px; margin: 0 auto; padding: 0 24px; }

  /* Hero */
  .hero { padding: 80px 0 48px; text-align: center; }
  .hero h1 { font-size: 2rem; font-weight: 700; color: #fff; margin-bottom: 12px; }
  .hero p { font-size: 1.1rem; color: #a0a0a0; max-width: 480px; margin: 0 auto 32px; }
  .hero code {
    display: inline-block; background: #1a1a2e; border: 1px solid #333;
    border-radius: 6px; padding: 8px 20px; font-size: 0.95rem; color: #6ee7b7;
  }

  /* Metrics strip */
  .metrics { display: flex; gap: 16px; justify-content: center; flex-wrap: wrap; padding: 32px 0; }
  .metric {
    background: #111; border: 1px solid #222; border-radius: 8px;
    padding: 20px 28px; text-align: center; min-width: 140px; flex: 1; max-width: 200px;
  }
  .metric .value { font-size: 1.8rem; font-weight: 700; color: #fff; }
  .metric .label { font-size: 0.8rem; color: #888; margin-top: 4px; text-transform: uppercase; letter-spacing: 0.5px; }

  /* Pipeline */
  .pipeline { padding: 40px 0; }
  .pipeline h2 { font-size: 1.2rem; color: #fff; margin-bottom: 20px; text-align: center; }
  .steps { display: flex; gap: 8px; align-items: center; justify-content: center; flex-wrap: wrap; }
  .step {
    background: #111; border: 1px solid #222; border-radius: 6px;
    padding: 12px 16px; text-align: center; flex: 1; min-width: 120px; max-width: 160px;
  }
  .step .cmd { font-family: monospace; font-size: 0.85rem; color: #6ee7b7; }
  .step .desc { font-size: 0.75rem; color: #888; margin-top: 4px; }
  .arrow { color: #444; font-size: 1.2rem; }

  /* Recent runs */
  .recent { padding: 40px 0; }
  .recent h2 { font-size: 1.2rem; color: #fff; margin-bottom: 16px; text-align: center; }
  .run-row {
    display: flex; justify-content: space-between; align-items: center;
    padding: 10px 16px; border-bottom: 1px solid #1a1a1a; color: #e0e0e0;
    transition: background 0.15s;
  }
  .run-row:hover { background: #111; text-decoration: none; }
  .run-id { font-family: monospace; color: #6ee7b7; font-size: 0.9rem; }
  .run-size { color: #888; font-size: 0.85rem; }
  .run-time { color: #666; font-size: 0.85rem; min-width: 60px; text-align: right; }
  .empty { text-align: center; color: #555; padding: 32px 0; font-size: 0.9rem; }

  /* Footer */
  .footer {
    padding: 48px 0 32px; text-align: center; border-top: 1px solid #1a1a1a; margin-top: 40px;
  }
  .footer p { color: #666; font-size: 0.85rem; margin-bottom: 8px; }
  .footer a { color: #6ee7b7; }

  @media (max-width: 480px) {
    .hero h1 { font-size: 1.5rem; }
    .metric { min-width: 100px; padding: 14px 16px; }
    .metric .value { font-size: 1.4rem; }
    .steps { flex-direction: column; }
    .arrow { transform: rotate(90deg); }
  }
</style>
</head>
<body>

<div class="container">
  <section class="hero">
    <h1>Map your app. Run your flows. Share results.</h1>
    <p>Auto-discover every screen, execute YAML test flows, generate self-contained HTML reports, share with one command.</p>
    <code>npm install -g flow-walker-cli</code>
  </section>

  <section class="metrics">
    <div class="metric">
      <div class="value">${stats.totalReports}</div>
      <div class="label">Reports pushed</div>
    </div>
    <div class="metric">
      <div class="value">${formatBytes(stats.totalBytes)}</div>
      <div class="label">Data served</div>
    </div>
    <div class="metric">
      <div class="value">${stats.lastPushAt ? timeAgo(stats.lastPushAt) : '—'}</div>
      <div class="label">Last push</div>
    </div>
  </section>

  <section class="pipeline">
    <h2>3 commands. Zero config.</h2>
    <div class="steps">
      <div class="step">
        <div class="cmd">walk</div>
        <div class="desc">Discover screens</div>
      </div>
      <span class="arrow">→</span>
      <div class="step">
        <div class="cmd">run</div>
        <div class="desc">Execute + record</div>
      </div>
      <span class="arrow">→</span>
      <div class="step">
        <div class="cmd">report</div>
        <div class="desc">Generate HTML</div>
      </div>
      <span class="arrow">→</span>
      <div class="step">
        <div class="cmd">push</div>
        <div class="desc">Share via URL</div>
      </div>
    </div>
  </section>

  <section class="recent">
    <h2>Recent reports</h2>
    ${recentRows || '<div class="empty">No reports yet. Be the first: flow-walker push</div>'}
  </section>

  <footer class="footer">
    <p>Open source &middot; MIT license &middot; <a href="https://github.com/beastoin/flow-walker">GitHub</a></p>
    <p>Built with <a href="https://github.com/beastoin/agent-flutter">agent-flutter</a></p>
  </footer>
</div>

</body>
</html>`;
}

function generateId(): string {
  const bytes = new Uint8Array(8);
  crypto.getRandomValues(bytes);
  // Base64url encode
  const base64 = btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=/g, '');
  return base64.slice(0, 10);
}
