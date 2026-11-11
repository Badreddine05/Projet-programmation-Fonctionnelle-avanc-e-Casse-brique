import { mkdir, copyFile, writeFile, cp } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';
import path from 'node:path';
const root = fileURLToPath(new URL('../', import.meta.url));
await mkdir(path.join(root, 'dist'), {recursive:true});
for (const name of ['index.html','app.js','style.css','favicon.svg']) {
  await copyFile(path.join(root,'web',name), path.join(root,'dist',name));
}
await copyFile(path.join(root,'_build/default/web/main.bc.js'),path.join(root,'dist/game.bc.js'));
await cp(path.join(root,'licenses'),path.join(root,'dist/licenses'),{recursive:true});
await copyFile(path.join(root,'NOTICE.md'),path.join(root,'dist/NOTICE.md'));
await copyFile(path.join(root,'LICENSE-new-code.txt'),path.join(root,'dist/LICENSE-new-code.txt'));
let commit = 'local-working-tree';
try { commit=execFileSync('git',['rev-parse','HEAD'],{cwd:root,encoding:'utf8'}).trim(); } catch {}
await writeFile(path.join(root,'dist/build-info.json'),JSON.stringify({engine:'OCaml / js_of_ocaml',commit,buildTime:new Date().toISOString()},null,2)+'\n');
console.log('Packaged the compiled OCaml engine and local web assets in dist/');
