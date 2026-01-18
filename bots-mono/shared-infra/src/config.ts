import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import dotenv from 'dotenv';

type EnvMap = Record<string, string>;

function loadDotEnv() {
  const cwd = process.cwd();
  const envPath = path.join(cwd, '.env');
  if (fs.existsSync(envPath)) {
    dotenv.config({ path: envPath });
  }
}

async function loadDpapiSecrets(envPath?: string): Promise<EnvMap> {
  if (!envPath) {
    return {};
  }
  if (process.platform !== 'win32') {
    return {};
  }
  if (!fs.existsSync(envPath)) {
    return {};
  }
  const raw = await fs.promises.readFile(envPath, 'utf8');
  const payload = raw.trim();
  if (!payload) {
    return {};
  }
  try {
    const { unprotectData } = await import('win-dpapi');
    const decrypted = unprotectData(Buffer.from(payload, 'base64'));
    const parsed = JSON.parse(decrypted.toString('utf8')) as EnvMap;
    return parsed;
  } catch (error) {
    console.warn('DPAPI secrets file could not be loaded.', error);
    return {};
  }
}

export async function loadEnv() {
  loadDotEnv();
  const secretsPath = process.env.WINDOWS_SECRETS_PATH;
  const secrets = await loadDpapiSecrets(secretsPath);
  for (const [key, value] of Object.entries(secrets)) {
    if (!process.env[key]) {
      process.env[key] = value;
    }
  }
}

export function getEnv(key: string, fallback?: string): string {
  const value = process.env[key] ?? fallback;
  if (value === undefined) {
    throw new Error(`Missing required env var: ${key}`);
  }
  return value;
}

export function getOptionalEnv(key: string, fallback?: string): string | undefined {
  return process.env[key] ?? fallback;
}

export function resolvePathFromModule(metaUrl: string, relativePath: string) {
  const base = path.dirname(fileURLToPath(metaUrl));
  return path.join(base, relativePath);
}
