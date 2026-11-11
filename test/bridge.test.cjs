const assert=require('node:assert/strict');
const compiled=require('../dist/game.bc.js');
const core=compiled.BreakoutCore ?? globalThis.BreakoutCore;
assert.ok(core,'OCaml export exists');
const read=value=>JSON.parse(value);
assert.equal(read(core.snapshot()).engine,'ocaml');
assert.equal(read(core.configure('expert','split')).mode,'split');
assert.equal(read(core.command('start')).phase,'ready');
assert.equal(read(core.command('launch')).phase,'playing');
let state;
for(let i=0;i<300;i++) {
  state=read(core.step(1/60,0,Number.NaN));
  assert.ok(Number.isFinite(state.ball.x)&&Number.isFinite(state.ball.y));
}
if(state.phase==='ready') core.command('launch');
const paused=read(core.command('pause'));
assert.equal(paused.phase,'paused');
assert.deepEqual(read(core.step(1,1,500)),paused);
assert.equal(read(core.command('resume')).phase,'playing');
const resumed=read(core.step(1/60,0,Number.NaN));
assert.ok(resumed.tick>paused.tick);
assert.deepEqual(read(core.step(Number.NaN,0,Number.NaN)),resumed);
assert.equal(read(core.command('restart')).lives,3);
assert.equal(read(core.command('menu')).phase,'menu');
assert.equal(read(core.configure('calm','solid')).difficulty,'calm');
console.log('PASS compiled OCaml bridge: configure, commands, 300 frames, finite state, pause and reset');
