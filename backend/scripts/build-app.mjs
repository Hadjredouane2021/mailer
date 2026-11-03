// Compile l'app Flutter pour le web et la copie dans public/app :
// l'interface est alors servie par cette API sur http://localhost:4100/app/
import { spawnSync } from 'child_process';
import { cpSync, rmSync } from 'fs';
import { fileURLToPath } from 'url';
import path from 'path';

const backend = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const app = path.resolve(backend, '..', 'app');
const target = path.join(backend, 'public', 'app');

const result = spawnSync('flutter', ['build', 'web', '--release', '--base-href', '/app/'], {
  cwd: app,
  stdio: 'inherit',
  shell: process.platform === 'win32',
});
if (result.status !== 0) process.exit(result.status ?? 1);

rmSync(target, { recursive: true, force: true });
cpSync(path.join(app, 'build', 'web'), target, { recursive: true });
console.log(`App Flutter copiée dans ${target}`);
