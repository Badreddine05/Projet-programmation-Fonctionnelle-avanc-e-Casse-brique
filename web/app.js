const core=globalThis.BreakoutCore;
const canvas=document.querySelector('#game'),ctx=canvas.getContext('2d');
const status=document.querySelector('#status');
if(!core){status.textContent='Le moteur n’a pas pu être chargé. Rechargez la page.';}else{
let state=JSON.parse(core.snapshot()),pointer=NaN,last=0;
document.querySelector('#start').onclick=()=>{core.command('start');state=JSON.parse(core.command('launch'));};
canvas.addEventListener('pointermove',event=>{pointer=(event.clientX-canvas.getBoundingClientRect().left)/canvas.clientWidth*1000;});
function frame(time){state=JSON.parse(core.step(last?(time-last)/1000:0,0,pointer));last=time;ctx.clearRect(0,0,1000,640);ctx.fillStyle='#cffc72';for(const b of state.bricks){if(b.hp>0)ctx.fillRect(b.x,b.y,b.w,b.h);}ctx.fillRect(state.paddleX,state.paddleY,state.paddleWidth,14);ctx.beginPath();ctx.arc(state.ball.x,state.ball.y,8,0,Math.PI*2);ctx.fill();status.textContent=`${state.phase} · score ${state.score} · vies ${state.lives}`;requestAnimationFrame(frame);}requestAnimationFrame(frame);
}
