import fs from 'node:fs';
import path from 'node:path';

export async function writeArtifact(category: string, id: string | number, payload: unknown) {
  const folder = path.join(process.cwd(), 'data', 'artifacts');
  await fs.promises.mkdir(folder, { recursive: true });
  const filePath = path.join(folder, `${category}_${id}.json`);
  await fs.promises.writeFile(filePath, JSON.stringify(payload, null, 2));
}
