// flow-walker Worker: store and serve HTML reports via R2

interface Env {
  BUCKET: R2Bucket;
}

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

const TTL_DAYS = 30;
const MAX_UPLOAD_BYTES = 20 * 1024 * 1024; // 20MB
const RATE_LIMIT_PER_DAY = 100;

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

    // GET / — simple status
    if (request.method === 'GET' && url.pathname === '/') {
      return Response.json({ service: 'flow-walker', status: 'ok' }, { headers: CORS_HEADERS });
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
