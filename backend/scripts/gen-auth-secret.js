import { randomBytes } from 'node:crypto';
import { chmodSync, copyFileSync, existsSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const backendDir = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const envPath = resolve(backendDir, '.env');
const examplePath = resolve(backendDir, '.env.example');

if (!existsSync(envPath)) {
  copyFileSync(examplePath, envPath);
  console.log('Created backend/.env from backend/.env.example.');
}

const lines = readFileSync(envPath, 'utf8').split(/\r?\n/);
const secretLineIndex = lines.findIndex((line) => /^\s*AUTH_TOKEN_SECRET\s*=/.test(line));
let secret = '';

if (secretLineIndex >= 0) {
  const match = lines[secretLineIndex].match(/^\s*AUTH_TOKEN_SECRET\s*=\s*(.*)$/);
  secret = match?.[1]?.trim() ?? '';
  if ((secret.startsWith('"') && secret.endsWith('"')) ||
    (secret.startsWith("'") && secret.endsWith("'"))) {
    secret = secret.slice(1, -1);
  }
}

if (secret.length > 0 && secret.length < 32) {
  throw new Error('AUTH_TOKEN_SECRET must be at least 32 characters. Existing values are never overwritten.');
}

if (secret.length === 0) {
  secret = randomBytes(32).toString('hex');
  if (secretLineIndex >= 0) {
    lines[secretLineIndex] = `AUTH_TOKEN_SECRET=${secret}`;
  } else {
    lines.push(`AUTH_TOKEN_SECRET=${secret}`);
  }
  writeFileSync(envPath, `${lines.join('\n').replace(/\n+$/, '')}\n`);
  console.log('Generated and saved AUTH_TOKEN_SECRET in backend/.env.');
} else {
  console.log('Kept the existing AUTH_TOKEN_SECRET in backend/.env.');
}

if (process.platform !== 'win32') {
  chmodSync(envPath, 0o600);
}

console.log('Review SMTP_* and LLM_* settings before starting Docker.');
