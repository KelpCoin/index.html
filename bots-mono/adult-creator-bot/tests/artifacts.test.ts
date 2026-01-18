import { describe, expect, it } from 'vitest';
import fs from 'node:fs';
import path from 'node:path';
import { writeArtifact } from '../src/utils/artifacts.js';

describe('writeArtifact', () => {
  it('writes artifact file', async () => {
    const id = `test_${Date.now()}`;
    await writeArtifact('test', id, { ok: true });
    const filePath = path.join(process.cwd(), 'data', 'artifacts', `test_${id}.json`);
    expect(fs.existsSync(filePath)).toBe(true);
  });
});
