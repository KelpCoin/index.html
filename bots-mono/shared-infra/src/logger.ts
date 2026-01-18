import fs from 'node:fs';
import path from 'node:path';
import pino from 'pino';
import { createStream } from 'rotating-file-stream';

export type Logger = pino.Logger;

export function createLogger(service: string) {
  const logsDir = path.join(process.cwd(), 'data', 'logs');
  fs.mkdirSync(logsDir, { recursive: true });
  const stream = createStream('%Y-%m-%d.log', {
    path: logsDir,
    interval: '1d',
    compress: 'gzip'
  });
  const logger = pino({
    base: { service },
    level: process.env.LOG_LEVEL || 'info'
  }, pino.multistream([
    { stream: process.stdout },
    { stream }
  ]));
  return logger;
}
