// flow-walker Worker: store and serve HTML reports via R2, landing page with live metrics

interface Env {
  BUCKET: R2Bucket;
}

interface RecentRun {
  id: string;
  uploadedAt: string;
  sizeBytes: number;
  flowName?: string;
  stepsTotal?: number;
  stepsPass?: number;
}

interface Stats {
  totalReports: number;
  totalBytes: number;
  totalSteps: number;
  totalStepsPass: number;
  lastPushAt: string;
  recentRuns: RecentRun[];
}

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, X-Run-ID, X-Flow-Name, X-Steps-Total, X-Steps-Pass',
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

function emptyStats(): Stats {
  return { totalReports: 0, totalBytes: 0, totalSteps: 0, totalStepsPass: 0, lastPushAt: '', recentRuns: [] };
}

async function loadStats(env: Env): Promise<Stats> {
  const obj = await env.BUCKET.get(STATS_KEY);
  if (!obj) return emptyStats();
  try {
    const raw = await obj.json<Stats>();
    // Backfill fields added after initial deploy
    return { ...emptyStats(), ...raw };
  } catch {
    return emptyStats();
  }
}

async function updateStats(env: Env, run: RecentRun): Promise<void> {
  const stats = await loadStats(env);
  stats.totalReports++;
  stats.totalBytes += run.sizeBytes;
  if (run.stepsTotal) stats.totalSteps += run.stepsTotal;
  if (run.stepsPass) stats.totalStepsPass += run.stepsPass;
  stats.lastPushAt = run.uploadedAt;
  stats.recentRuns.unshift(run);
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

  // Read optional flow metadata headers
  const flowName = request.headers.get('X-Flow-Name') || undefined;
  const stepsTotal = parseInt(request.headers.get('X-Steps-Total') || '', 10) || undefined;
  const stepsPass = parseInt(request.headers.get('X-Steps-Pass') || '', 10) || undefined;

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
  const uploadedAt = new Date().toISOString();

  await env.BUCKET.put(key, body, {
    httpMetadata: { contentType: 'text/html; charset=utf-8' },
    customMetadata: { expiresAt, uploadedAt, ...(flowName ? { flowName } : {}) },
  });

  // Update stats (best-effort — don't block the response on failure)
  try {
    await updateStats(env, {
      id: runId, uploadedAt, sizeBytes: body.byteLength,
      flowName, stepsTotal, stepsPass,
    });
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

function passRate(total: number, pass: number): string {
  if (total === 0) return '—';
  return `${((pass / total) * 100).toFixed(1)}%`;
}

function escapeHtml(s: string): string {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

function buildLandingPage(stats: Stats, baseUrl: string): string {
  const recentRows = stats.recentRuns
    .map((r) => {
      const label = r.flowName ? escapeHtml(r.flowName) : r.id;
      const stepInfo = r.stepsTotal
        ? `<span class="run-steps">${r.stepsPass ?? 0}/${r.stepsTotal} pass</span>`
        : '';
      return `
        <a href="${baseUrl}/runs/${r.id}" class="run-row">
          <span class="run-label">${label}</span>
          ${stepInfo}
          <span class="run-size">${formatBytes(r.sizeBytes)}</span>
          <span class="run-time">${timeAgo(r.uploadedAt)}</span>
        </a>`;
    })
    .join('');

  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>flow-walker — Map your app in minutes. Zero test code.</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    background: #0a0a0a; color: #e0e0e0; line-height: 1.6;
    min-height: 100vh;
  }
  a { color: #6ee7b7; text-decoration: none; }
  a:hover { text-decoration: underline; }
  code { font-family: "SF Mono", "Fira Code", "Fira Mono", Menlo, monospace; }

  .container { max-width: 720px; margin: 0 auto; padding: 0 24px; }

  /* Hero */
  .hero { padding: 80px 0 24px; text-align: center; }
  .hero h1 { font-size: 2rem; font-weight: 700; color: #fff; margin-bottom: 12px; }
  .hero p { font-size: 1.05rem; color: #a0a0a0; max-width: 520px; margin: 0 auto 28px; }
  .install {
    display: inline-block; background: #1a1a2e; border: 1px solid #333;
    border-radius: 6px; padding: 10px 24px; font-size: 0.95rem; color: #6ee7b7;
    cursor: pointer; position: relative;
  }
  .install:hover { border-color: #6ee7b7; }

  /* Metrics strip */
  .metrics { display: flex; gap: 16px; justify-content: center; flex-wrap: wrap; padding: 36px 0; }
  .metric {
    background: #111; border: 1px solid #222; border-radius: 8px;
    padding: 20px 24px; text-align: center; min-width: 130px; flex: 1; max-width: 180px;
  }
  .metric .value { font-size: 1.8rem; font-weight: 700; color: #fff; }
  .metric .label { font-size: 0.75rem; color: #888; margin-top: 4px; text-transform: uppercase; letter-spacing: 0.5px; }

  /* Try it */
  .tryit { padding: 36px 0; }
  .tryit h2 { font-size: 1.2rem; color: #fff; margin-bottom: 16px; text-align: center; }
  .terminal {
    background: #111; border: 1px solid #222; border-radius: 8px;
    padding: 20px 24px; font-size: 0.85rem; line-height: 1.8;
  }
  .terminal .prompt { color: #888; }
  .terminal .cmd { color: #6ee7b7; }
  .terminal .out { color: #a0a0a0; }

  /* Pipeline */
  .pipeline { padding: 36px 0; }
  .pipeline h2 { font-size: 1.2rem; color: #fff; margin-bottom: 20px; text-align: center; }
  .steps { display: flex; gap: 8px; align-items: center; justify-content: center; flex-wrap: wrap; }
  .step {
    background: #111; border: 1px solid #222; border-radius: 6px;
    padding: 12px 16px; text-align: center; flex: 1; min-width: 120px; max-width: 160px;
  }
  .step .cmd { font-size: 0.85rem; color: #6ee7b7; }
  .step .desc { font-size: 0.75rem; color: #888; margin-top: 4px; }
  .arrow { color: #444; font-size: 1.2rem; }

  /* Recent runs */
  .recent { padding: 36px 0; }
  .recent h2 { font-size: 1.2rem; color: #fff; margin-bottom: 16px; text-align: center; }
  .run-row {
    display: flex; justify-content: space-between; align-items: center;
    padding: 10px 16px; border-bottom: 1px solid #1a1a1a; color: #e0e0e0;
    transition: background 0.15s; gap: 12px;
  }
  .run-row:hover { background: #111; text-decoration: none; }
  .run-label { color: #6ee7b7; font-size: 0.9rem; flex: 1; min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .run-steps { color: #a0a0a0; font-size: 0.8rem; white-space: nowrap; }
  .run-size { color: #666; font-size: 0.8rem; white-space: nowrap; }
  .run-time { color: #555; font-size: 0.8rem; min-width: 50px; text-align: right; white-space: nowrap; }
  .empty { text-align: center; color: #555; padding: 32px 0; font-size: 0.9rem; }

  /* Footer */
  .footer {
    padding: 48px 0 32px; text-align: center; border-top: 1px solid #1a1a1a; margin-top: 32px;
  }
  .footer p { color: #666; font-size: 0.85rem; margin-bottom: 8px; }

  @media (max-width: 480px) {
    .hero { padding: 48px 0 16px; }
    .hero h1 { font-size: 1.5rem; }
    .metric { min-width: 90px; padding: 14px 12px; }
    .metric .value { font-size: 1.4rem; }
    .steps { flex-direction: column; }
    .arrow { transform: rotate(90deg); }
    .run-row { font-size: 0.85rem; gap: 8px; }
  }
</style>
</head>
<body>

<div class="container">
  <section class="hero">
    <h1>Map your app in minutes. Zero test code.</h1>
    <p>Auto-discover screens, execute YAML test flows, generate self-contained reports, share with one command. Open source.</p>
    <code class="install">npm install -g flow-walker-cli</code>
  </section>

  <section class="metrics">
    <div class="metric">
      <div class="value">${stats.totalSteps || '—'}</div>
      <div class="label">Steps executed</div>
    </div>
    <div class="metric">
      <div class="value">${passRate(stats.totalSteps, stats.totalStepsPass)}</div>
      <div class="label">Pass rate</div>
    </div>
    <div class="metric">
      <div class="value">${stats.totalReports}</div>
      <div class="label">Reports shared</div>
    </div>
    <div class="metric">
      <div class="value">${formatBytes(stats.totalBytes)}</div>
      <div class="label">Data served</div>
    </div>
  </section>

  <section class="tryit">
    <h2>See it work</h2>
    <div class="terminal">
      <div><span class="prompt">$ </span><span class="cmd">flow-walker walk --max-depth 2</span></div>
      <div><span class="out">&rarr; discovered 26 screens, 44 edges in 4 minutes</span></div>
      <br>
      <div><span class="prompt">$ </span><span class="cmd">flow-walker run flows/tab-navigation.yaml</span></div>
      <div><span class="out">&rarr; 4/4 steps pass (8.9s)</span></div>
      <br>
      <div><span class="prompt">$ </span><span class="cmd">flow-walker push ./results/</span></div>
      <div><span class="out">&rarr; ${baseUrl}/runs/25h7afGwBK</span></div>
    </div>
  </section>

  <section class="pipeline">
    <h2>4 commands. Zero config.</h2>
    <div class="steps">
      <div class="step">
        <div class="cmd"><code>walk</code></div>
        <div class="desc">Discover screens</div>
      </div>
      <span class="arrow">&rarr;</span>
      <div class="step">
        <div class="cmd"><code>run</code></div>
        <div class="desc">Execute + record</div>
      </div>
      <span class="arrow">&rarr;</span>
      <div class="step">
        <div class="cmd"><code>report</code></div>
        <div class="desc">Generate HTML</div>
      </div>
      <span class="arrow">&rarr;</span>
      <div class="step">
        <div class="cmd"><code>push</code></div>
        <div class="desc">Share via URL</div>
      </div>
    </div>
  </section>

  <section class="recent">
    <h2>Recent reports</h2>
    ${recentRows || '<div class="empty">No reports yet. Be the first: <code>flow-walker push</code></div>'}
  </section>

  <footer class="footer">
    <p>Open source &middot; MIT &middot; <a href="https://github.com/beastoin/flow-walker">GitHub</a> &middot; <a href="${baseUrl}/api/stats">API</a></p>
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
