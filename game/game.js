const canvas = document.getElementById('game');
const ctx = canvas.getContext('2d');
const hud = document.getElementById('hud');

const state = {
  mode: 'collect',
  score: 0,
  carrying: false,
  player: { x: 50, y: 90, speed: 1.5 },
  kelp: { x: 240, y: 60 },
  dock: { x: 280, y: 140 }
};

const keys = new Set();
addEventListener('keydown', (e) => keys.add(e.key.toLowerCase()));
addEventListener('keyup', (e) => keys.delete(e.key.toLowerCase()));

function update() {
  const p = state.player;
  if (keys.has('arrowup') || keys.has('w')) p.y -= p.speed;
  if (keys.has('arrowdown') || keys.has('s')) p.y += p.speed;
  if (keys.has('arrowleft') || keys.has('a')) p.x -= p.speed;
  if (keys.has('arrowright') || keys.has('d')) p.x += p.speed;
  p.x = Math.max(5, Math.min(canvas.width - 5, p.x));
  p.y = Math.max(5, Math.min(canvas.height - 5, p.y));

  if (!state.carrying && near(p, state.kelp)) {
    state.carrying = true;
    state.mode = 'deliver';
  }
  if (state.carrying && near(p, state.dock)) {
    state.carrying = false;
    state.score += 1;
    state.mode = state.score >= 5 ? 'win' : 'collect';
  }
}

function near(a, b) {
  return Math.hypot(a.x - b.x, a.y - b.y) < 16;
}

function drawIsoTile(x, y, color) {
  ctx.fillStyle = color;
  ctx.beginPath();
  ctx.moveTo(x, y - 8);
  ctx.lineTo(x + 16, y);
  ctx.lineTo(x, y + 8);
  ctx.lineTo(x - 16, y);
  ctx.closePath();
  ctx.fill();
}

function draw() {
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  for (let y = 20; y < canvas.height; y += 18) {
    for (let x = 20; x < canvas.width; x += 36) drawIsoTile(x, y, '#163149');
  }
  drawIsoTile(state.kelp.x, state.kelp.y, '#2d9b5d');
  drawIsoTile(state.dock.x, state.dock.y, '#9b7c43');
  drawIsoTile(state.player.x, state.player.y, state.carrying ? '#ffe082' : '#7fc7ff');

  hud.textContent = state.mode === 'win'
    ? `Win condition reached. Score ${state.score}/5.`
    : `Mode: ${state.mode} | Carrying: ${state.carrying ? 'yes' : 'no'} | Score: ${state.score}/5`;
}

function loop() {
  update();
  draw();
  requestAnimationFrame(loop);
}

loop();
