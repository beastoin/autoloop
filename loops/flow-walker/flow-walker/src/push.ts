// Upload report.html to flow-walker hosted service

import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { FlowWalkerError, ErrorCodes } from './errors.ts';

const DEFAULT_API_URL = 'https://flow-walker.beastoin.workers.dev';

export interface PushResult {
  url: string;
  id: string;
  expiresAt: string;
}

/** Upload a report to the hosted service */
export async function pushReport(
  runDir: string,
  options: { apiUrl?: string; runId?: string } = {},
): Promise<PushResult> {
  const apiUrl = options.apiUrl
    || process.env.FLOW_WALKER_API_URL
    || DEFAULT_API_URL;

  // Find report.html
  const reportPath = join(runDir, 'report.html');
  if (!existsSync(reportPath)) {
    throw new FlowWalkerError(
      ErrorCodes.FILE_NOT_FOUND,
      'report.html not found in run directory',
      'Generate it first: flow-walker report <run-dir>',
    );
  }

  // Read metadata from run.json if available
  let runId = options.runId;
  let flowName: string | undefined;
  let stepsTotal: number | undefined;
  let stepsPass: number | undefined;
  const runJsonPath = join(runDir, 'run.json');
  if (existsSync(runJsonPath)) {
    try {
      const runData = JSON.parse(readFileSync(runJsonPath, 'utf-8'));
      if (!runId) runId = runData.id;
      if (runData.flow) flowName = String(runData.flow);
      if (Array.isArray(runData.steps)) {
        stepsTotal = runData.steps.length;
        stepsPass = runData.steps.filter((s: { status?: string }) => s.status === 'pass').length;
      }
    } catch { /* ignore parse errors */ }
  }

  // Read report
  const reportContent = readFileSync(reportPath);

  // Upload
  const headers: Record<string, string> = {
    'Content-Type': 'text/html',
    'Content-Length': String(reportContent.byteLength),
  };
  if (runId) headers['X-Run-ID'] = runId;
  if (flowName) headers['X-Flow-Name'] = flowName;
  if (stepsTotal !== undefined) headers['X-Steps-Total'] = String(stepsTotal);
  if (stepsPass !== undefined) headers['X-Steps-Pass'] = String(stepsPass);

  let response: Response;
  try {
    response = await fetch(`${apiUrl}/runs`, {
      method: 'POST',
      headers,
      body: reportContent,
    });
  } catch (err) {
    throw new FlowWalkerError(
      ErrorCodes.COMMAND_FAILED,
      `Failed to connect to ${apiUrl}: ${err instanceof Error ? err.message : String(err)}`,
      `Check your network or set FLOW_WALKER_API_URL`,
    );
  }

  if (!response.ok) {
    let errorMsg = `Upload failed (HTTP ${response.status})`;
    try {
      const body = await response.json() as { error?: { message?: string } };
      if (body.error?.message) errorMsg = body.error.message;
    } catch { /* ignore */ }
    throw new FlowWalkerError(
      ErrorCodes.COMMAND_FAILED,
      errorMsg,
      'Try again or check FLOW_WALKER_API_URL',
    );
  }

  const result = await response.json() as PushResult;
  return result;
}
