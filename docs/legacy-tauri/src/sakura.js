const canvas = document.getElementById('sakura-canvas');
const ctx = canvas.getContext('2d', { alpha: true });

const petalColors = [
  { r: 255, g: 246, b: 248 },
  { r: 255, g: 230, b: 238 },
  { r: 255, g: 211, b: 226 },
  { r: 255, g: 190, b: 213 },
  { r: 248, g: 158, b: 190 },
  { r: 237, g: 128, b: 173 },
];

const hazakuraColors = [
  { r: 232, g: 88, b: 122 },
  { r: 247, g: 135, b: 154 },
  { r: 255, g: 224, b: 230 },
  { r: 90, g: 158, b: 95 },
  { r: 61, g: 122, b: 65 },
  { r: 144, g: 198, b: 149 },
];

const state = {
  paused: false,
  showNight: false,
  mode: 'sakura',
  focus: 'normal',
  startTime: 0,
  pausedAt: 0,
  animationFrame: 0,
  windX: 0.55,
  windY: 0.35,
};

const pointer = {
  x: window.innerWidth / 2,
  y: window.innerHeight / 2,
  prevX: window.innerWidth / 2,
  prevY: window.innerHeight / 2,
  vx: 0,
  vy: 0,
  active: false,
  pulse: 0,
};

const W = () => window.innerWidth;
const H = () => window.innerHeight;
const random = (min, max) => min + Math.random() * (max - min);
const MAX_RENDER_DPR = 1.5;
const focusProfiles = {
  quiet: { count: 0.48, alpha: 0.58, repel: 0.56, size: 0.82, speed: 0.78 },
  normal: { count: 1, alpha: 1, repel: 1, size: 1, speed: 1 },
  play: { count: 1.58, alpha: 1.18, repel: 1.36, size: 1.12, speed: 1.18 },
};
const profile = () => focusProfiles[state.focus] || focusProfiles.normal;

function resize() {
  const dpr = Math.min(MAX_RENDER_DPR, Math.max(1, window.devicePixelRatio || 1));
  canvas.width = Math.floor(W() * dpr);
  canvas.height = Math.floor(H() * dpr);
  canvas.style.width = `${W()}px`;
  canvas.style.height = `${H()}px`;
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
}

function updatePointer(x, y) {
  if (!Number.isFinite(x) || !Number.isFinite(y)) {
    return;
  }

  pointer.prevX = pointer.x;
  pointer.prevY = pointer.y;
  pointer.x = x;
  pointer.y = y;
  pointer.vx = pointer.x - pointer.prevX;
  pointer.vy = pointer.y - pointer.prevY;
  pointer.active = x >= -80 && y >= -80 && x <= W() + 80 && y <= H() + 80;
  pointer.pulse = Math.min(1, pointer.pulse + 0.08);

  const nx = (x / Math.max(1, W()) - 0.5) * 2;
  const ny = (y / Math.max(1, H()) - 0.5) * 2;
  state.windX = 0.55 + nx * 1.7;
  state.windY = 0.32 - ny * 0.95;
}

function drawNightBackground(time) {
  const gradient = ctx.createLinearGradient(0, 0, 0, H());
  gradient.addColorStop(0, 'rgba(18, 7, 24, 0.84)');
  gradient.addColorStop(0.46, 'rgba(35, 14, 36, 0.74)');
  gradient.addColorStop(1, 'rgba(5, 5, 12, 0.88)');
  ctx.fillStyle = gradient;
  ctx.fillRect(0, 0, W(), H());

  const moonX = W() * 0.8 + Math.sin(time * 0.00008) * 18;
  const moonY = H() * 0.18;
  drawSoftGlow(moonX, moonY, 170, [
    [0, 'rgba(255, 238, 225, 0.18)'],
    [0.28, 'rgba(255, 210, 222, 0.08)'],
    [1, 'rgba(255, 210, 222, 0)'],
  ]);

  const vignette = ctx.createRadialGradient(W() * 0.5, H() * 0.52, H() * 0.12, W() * 0.5, H() * 0.52, H() * 0.82);
  vignette.addColorStop(0, 'rgba(0, 0, 0, 0)');
  vignette.addColorStop(1, 'rgba(0, 0, 0, 0.32)');
  ctx.fillStyle = vignette;
  ctx.fillRect(0, 0, W(), H());
}

function drawBackground(time) {
  ctx.clearRect(0, 0, W(), H());

  if (state.showNight) {
    drawNightBackground(time);
  }
}

function drawSoftGlow(x, y, radius, stops) {
  const gradient = ctx.createRadialGradient(x, y, 0, x, y, radius);
  for (const [offset, color] of stops) {
    gradient.addColorStop(offset, color);
  }
  ctx.fillStyle = gradient;
  ctx.fillRect(x - radius, y - radius, radius * 2, radius * 2);
}

function shouldDraw(index) {
  return index < profile().count;
}

function drawSakuraPetal(x, y, size, rotation, alpha, color, flip = 1) {
  const w = size * 0.48;
  const h = size * 0.9;

  ctx.save();
  ctx.translate(x, y);
  ctx.rotate(rotation);
  ctx.scale(flip, 1);
  ctx.globalAlpha = alpha;
  ctx.shadowColor = `rgba(${color.r}, ${color.g}, ${color.b}, 0.36)`;
  ctx.shadowBlur = size * 0.22;

  ctx.beginPath();
  ctx.moveTo(-w * 0.14, -h * 0.52);
  ctx.bezierCurveTo(-w * 0.72, -h * 0.46, -w * 1.02, -h * 0.04, -w * 0.78, h * 0.24);
  ctx.bezierCurveTo(-w * 0.5, h * 0.58, -w * 0.08, h * 0.62, 0, h * 0.54);
  ctx.bezierCurveTo(w * 0.08, h * 0.62, w * 0.5, h * 0.58, w * 0.78, h * 0.24);
  ctx.bezierCurveTo(w * 1.02, -h * 0.04, w * 0.72, -h * 0.46, w * 0.14, -h * 0.52);
  ctx.quadraticCurveTo(0, -h * 0.36, -w * 0.14, -h * 0.52);
  ctx.closePath();

  const gradient = ctx.createRadialGradient(0, h * 0.2, 0, 0, 0, size * 0.72);
  gradient.addColorStop(0, 'rgba(255, 255, 255, 0.96)');
  gradient.addColorStop(0.34, `rgba(${color.r}, ${color.g}, ${color.b}, 0.9)`);
  gradient.addColorStop(1, `rgba(${Math.max(0, color.r - 38)}, ${Math.max(0, color.g - 56)}, ${Math.max(0, color.b - 42)}, 0.7)`);
  ctx.fillStyle = gradient;
  ctx.fill();

  ctx.shadowBlur = 0;
  ctx.globalAlpha = alpha * 0.42;
  ctx.strokeStyle = 'rgba(255, 255, 255, 0.76)';
  ctx.lineWidth = Math.max(0.45, size * 0.025);
  ctx.beginPath();
  ctx.moveTo(0, h * 0.46);
  ctx.quadraticCurveTo(-w * 0.1, 0, -w * 0.04, -h * 0.28);
  ctx.stroke();

  ctx.globalAlpha = alpha * 0.28;
  ctx.strokeStyle = 'rgba(197, 77, 130, 0.55)';
  ctx.beginPath();
  ctx.moveTo(-w * 0.28, h * 0.36);
  ctx.quadraticCurveTo(-w * 0.38, 0, -w * 0.36, -h * 0.2);
  ctx.moveTo(w * 0.28, h * 0.36);
  ctx.quadraticCurveTo(w * 0.38, 0, w * 0.36, -h * 0.2);
  ctx.stroke();
  ctx.restore();
}

function drawSakuraFlower(x, y, size, rotation, alpha, color) {
  ctx.save();
  ctx.translate(x, y);
  ctx.rotate(rotation);
  ctx.globalAlpha = alpha;
  ctx.shadowColor = `rgba(${color.r}, ${color.g}, ${color.b}, 0.22)`;
  ctx.shadowBlur = size * 0.55;

  for (let i = 0; i < 5; i += 1) {
    ctx.save();
    ctx.rotate((Math.PI * 2 * i) / 5);
    ctx.translate(0, -size * 0.36);
    ctx.beginPath();
    ctx.ellipse(0, 0, size * 0.22, size * 0.38, 0, 0, Math.PI * 2);
    const gradient = ctx.createRadialGradient(0, size * 0.1, 0, 0, 0, size * 0.42);
    gradient.addColorStop(0, 'rgba(255, 255, 255, 0.88)');
    gradient.addColorStop(0.42, `rgba(${color.r}, ${color.g}, ${color.b}, 0.74)`);
    gradient.addColorStop(1, `rgba(${Math.max(0, color.r - 28)}, ${Math.max(0, color.g - 42)}, ${Math.max(0, color.b - 32)}, 0.34)`);
    ctx.fillStyle = gradient;
    ctx.fill();
    ctx.restore();
  }

  ctx.shadowBlur = 0;
  ctx.globalAlpha = alpha * 0.66;
  drawSoftGlow(0, 0, size * 0.22, [
    [0, 'rgba(224, 91, 137, 0.58)'],
    [1, 'rgba(224, 91, 137, 0)'],
  ]);
  ctx.restore();
}

function createSpriteCanvas(size) {
  const sprite = document.createElement('canvas');
  sprite.width = size;
  sprite.height = size;
  return sprite;
}

function drawPetalShape(targetCtx, size, color) {
  const w = size * 0.48;
  const h = size * 0.9;

  targetCtx.save();
  targetCtx.shadowColor = `rgba(${color.r}, ${color.g}, ${color.b}, 0.28)`;
  targetCtx.shadowBlur = size * 0.18;
  targetCtx.beginPath();
  targetCtx.moveTo(-w * 0.14, -h * 0.52);
  targetCtx.bezierCurveTo(-w * 0.72, -h * 0.46, -w * 1.02, -h * 0.04, -w * 0.78, h * 0.24);
  targetCtx.bezierCurveTo(-w * 0.5, h * 0.58, -w * 0.08, h * 0.62, 0, h * 0.54);
  targetCtx.bezierCurveTo(w * 0.08, h * 0.62, w * 0.5, h * 0.58, w * 0.78, h * 0.24);
  targetCtx.bezierCurveTo(w * 1.02, -h * 0.04, w * 0.72, -h * 0.46, w * 0.14, -h * 0.52);
  targetCtx.quadraticCurveTo(0, -h * 0.36, -w * 0.14, -h * 0.52);
  targetCtx.closePath();

  const gradient = targetCtx.createRadialGradient(0, h * 0.2, 0, 0, 0, size * 0.72);
  gradient.addColorStop(0, 'rgba(255, 255, 255, 0.96)');
  gradient.addColorStop(0.34, `rgba(${color.r}, ${color.g}, ${color.b}, 0.9)`);
  gradient.addColorStop(1, `rgba(${Math.max(0, color.r - 38)}, ${Math.max(0, color.g - 56)}, ${Math.max(0, color.b - 42)}, 0.7)`);
  targetCtx.fillStyle = gradient;
  targetCtx.fill();

  targetCtx.shadowBlur = 0;
  targetCtx.globalAlpha = 0.42;
  targetCtx.strokeStyle = 'rgba(255, 255, 255, 0.76)';
  targetCtx.lineWidth = Math.max(0.45, size * 0.025);
  targetCtx.beginPath();
  targetCtx.moveTo(0, h * 0.46);
  targetCtx.quadraticCurveTo(-w * 0.1, 0, -w * 0.04, -h * 0.28);
  targetCtx.stroke();

  targetCtx.globalAlpha = 0.28;
  targetCtx.strokeStyle = 'rgba(197, 77, 130, 0.55)';
  targetCtx.beginPath();
  targetCtx.moveTo(-w * 0.28, h * 0.36);
  targetCtx.quadraticCurveTo(-w * 0.38, 0, -w * 0.36, -h * 0.2);
  targetCtx.moveTo(w * 0.28, h * 0.36);
  targetCtx.quadraticCurveTo(w * 0.38, 0, w * 0.36, -h * 0.2);
  targetCtx.stroke();
  targetCtx.restore();
}

function makePetalSprite(color) {
  const sprite = createSpriteCanvas(96);
  const spriteCtx = sprite.getContext('2d');
  spriteCtx.translate(48, 48);
  drawPetalShape(spriteCtx, 42, color);
  return sprite;
}

function makeFlowerSprite(color) {
  const sprite = createSpriteCanvas(104);
  const spriteCtx = sprite.getContext('2d');
  spriteCtx.translate(52, 52);
  for (let i = 0; i < 5; i += 1) {
    spriteCtx.save();
    spriteCtx.rotate((Math.PI * 2 * i) / 5);
    spriteCtx.translate(0, -14);
    drawPetalShape(spriteCtx, 28, color);
    spriteCtx.restore();
  }
  const core = spriteCtx.createRadialGradient(0, 0, 0, 0, 0, 8);
  core.addColorStop(0, 'rgba(224, 91, 137, 0.58)');
  core.addColorStop(1, 'rgba(224, 91, 137, 0)');
  spriteCtx.fillStyle = core;
  spriteCtx.fillRect(-8, -8, 16, 16);
  return sprite;
}

function makeLeafSprite(color) {
  const sprite = createSpriteCanvas(72);
  const spriteCtx = sprite.getContext('2d');
  spriteCtx.translate(36, 36);
  spriteCtx.beginPath();
  spriteCtx.ellipse(0, 0, 11, 25, 0, 0, Math.PI * 2);
  spriteCtx.fillStyle = `rgba(${color.r}, ${color.g}, ${color.b}, 0.58)`;
  spriteCtx.fill();
  spriteCtx.globalAlpha = 0.34;
  spriteCtx.strokeStyle = 'rgba(245, 255, 236, 0.42)';
  spriteCtx.lineWidth = 1.1;
  spriteCtx.beginPath();
  spriteCtx.moveTo(0, -18);
  spriteCtx.lineTo(0, 18);
  spriteCtx.stroke();
  return sprite;
}

const spriteAssets = {
  petal: new Map(),
  flower: new Map(),
  leaf: new Map(),
};

function colorKey(color) {
  return `${color.r}-${color.g}-${color.b}`;
}

function getSprite(kind, color) {
  const key = colorKey(color);
  if (!spriteAssets[kind].has(key)) {
    const maker = kind === 'flower' ? makeFlowerSprite : kind === 'leaf' ? makeLeafSprite : makePetalSprite;
    spriteAssets[kind].set(key, maker(color));
  }
  return spriteAssets[kind].get(key);
}

function drawSprite(sprite, x, y, size, rotation, alpha, flip = 1) {
  const scale = size / 42;
  ctx.save();
  ctx.translate(x, y);
  ctx.rotate(rotation);
  ctx.scale(scale * flip, scale);
  ctx.globalAlpha = alpha;
  ctx.drawImage(sprite, -sprite.width / 2, -sprite.height / 2);
  ctx.restore();
}

function applyPointerRepel(particle, radius, strength) {
  if (!pointer.active) {
    return 0;
  }

  const dx = particle.x - pointer.x;
  const dy = particle.y - pointer.y;
  const distSq = dx * dx + dy * dy;
  const radiusSq = radius * radius;

  if (distSq > radiusSq || distSq < 0.01) {
    return 0;
  }

  const dist = Math.sqrt(distSq);
  const force = (1 - dist / radius) ** 2 * strength * profile().repel;
  const nx = dx / dist;
  const ny = dy / dist;
  particle.vx += nx * force + pointer.vx * 0.035;
  particle.vy += ny * force + pointer.vy * 0.035;
  particle.spin += force * 0.012 * Math.sign(nx || 1);
  return force;
}

class Sparkle {
  constructor(initial = false) {
    this.reset(initial);
  }

  reset(initial = false) {
    this.x = random(0, W());
    this.y = initial ? random(0, H()) : random(H() * 0.2, H() + 80);
    this.size = random(0.7, 2.4);
    this.phase = random(0, Math.PI * 2);
    this.driftX = random(-0.12, 0.25);
    this.driftY = random(-0.32, -0.06);
    this.maxAlpha = random(0.1, 0.38);
  }

  update(time) {
    this.x += this.driftX + state.windX * 0.03;
    this.y += this.driftY;
    this.alpha = ((Math.sin(time * 0.002 + this.phase) + 1) / 2) * this.maxAlpha;

    if (this.y < -20 || this.x < -20 || this.x > W() + 20) {
      this.reset();
    }
  }

  draw() {
    if (!state.showNight || this.alpha <= 0.02) {
      return;
    }

    ctx.save();
    ctx.globalAlpha = this.alpha;
    drawSoftGlow(this.x, this.y, this.size * 3.4, [
      [0, 'rgba(255, 244, 248, 0.64)'],
      [1, 'rgba(255, 244, 248, 0)'],
    ]);
    ctx.restore();
  }
}

class MagicLight {
  constructor(initial = false) {
    this.reset(initial);
  }

  reset(initial = false) {
    this.x = random(-W() * 0.1, W() * 1.1);
    this.y = initial ? random(0, H()) : random(H() + 20, H() + 180);
    this.size = random(2.2, 8);
    this.phase = random(0, Math.PI * 2);
    this.orbit = random(8, 42);
    this.orbitSpeed = random(0.0012, 0.0038);
    this.vx = random(-0.2, 0.2);
    this.vy = random(-0.9, -0.28);
    this.spin = random(-0.02, 0.02);
    this.alpha = random(0.22, 0.58);
    this.hue = random(292, 334);
  }

  update(time) {
    applyPointerRepel(this, 122, 5.2);
    const drift = Math.sin(time * this.orbitSpeed + this.phase) * this.orbit;
    this.x += (this.vx + drift * 0.018 + state.windX * 0.08) * profile().speed;
    this.y += (this.vy + Math.cos(time * this.orbitSpeed * 0.8 + this.phase) * 0.18 + state.windY * 0.04) * profile().speed;
    this.spin += Math.sin(time * 0.0007 + this.phase) * 0.0009;

    if (this.y < -80 || this.x < -140 || this.x > W() + 140) {
      this.reset();
    }
  }

  draw(time) {
    const twinkle = 0.72 + Math.sin(time * 0.004 + this.phase) * 0.28;
    const alpha = this.alpha * twinkle * profile().alpha;
    const x = this.x + Math.sin(time * this.orbitSpeed + this.phase) * this.orbit * 0.24;
    const y = this.y + Math.cos(time * this.orbitSpeed + this.phase) * this.orbit * 0.12;

    ctx.save();
    ctx.translate(x, y);
    ctx.rotate(this.spin);
    ctx.globalAlpha = alpha;
    ctx.globalCompositeOperation = 'lighter';

    const size = this.size * profile().size;
    drawSoftGlow(0, 0, size * 5.2, [
      [0, `hsla(${this.hue}, 96%, 88%, 0.34)`],
      [0.42, `hsla(${this.hue + 24}, 92%, 72%, 0.11)`],
      [1, `hsla(${this.hue}, 96%, 60%, 0)`],
    ]);

    drawSoftGlow(0, 0, size * 1.7, [
      [0, `hsla(${this.hue + 8}, 100%, 94%, 0.68)`],
      [0.62, `hsla(${this.hue}, 100%, 82%, 0.22)`],
      [1, `hsla(${this.hue}, 100%, 70%, 0)`],
    ]);

    ctx.restore();
  }
}

class SparkLine {
  constructor(initial = false) {
    this.reset(initial);
  }

  reset(initial = false) {
    this.x = random(-W() * 0.08, W() * 1.08);
    this.y = initial ? random(0, H()) : random(H() + 40, H() + 180);
    this.length = random(14, 58);
    this.size = random(1.4, 3.8);
    this.phase = random(0, Math.PI * 2);
    this.vx = random(-0.32, 0.34);
    this.vy = random(-1.15, -0.32);
    this.rotation = random(0, Math.PI * 2);
    this.spin = random(-0.018, 0.018);
    this.alpha = random(0.34, 0.82);
    this.hue = random(292, 344);
  }

  update(time) {
    applyPointerRepel(this, 126, 6.5);
    this.x += (this.vx + state.windX * 0.12 + Math.sin(time * 0.001 + this.phase) * 0.18) * profile().speed;
    this.y += (this.vy + state.windY * 0.05) * profile().speed;
    this.rotation += this.spin;

    if (this.y < -90 || this.x < -140 || this.x > W() + 140) {
      this.reset();
    }
  }

  draw(time) {
    const twinkle = 0.74 + Math.sin(time * 0.005 + this.phase) * 0.26;
    const scale = profile().size;
    const length = this.length * scale;
    const core = this.size * scale * 1.8;
    const alpha = this.alpha * twinkle * profile().alpha;

    ctx.save();
    ctx.translate(this.x, this.y);
    ctx.rotate(this.rotation);

    for (let axis = 0; axis < 4; axis += 1) {
      const rayLength = length * (axis % 2 === 0 ? 1 : 0.68);
      const rayWidth = core * (axis % 2 === 0 ? 0.75 : 0.58);
      ctx.save();
      ctx.rotate(axis * Math.PI * 0.5);
      ctx.globalAlpha = alpha * (axis % 2 === 0 ? 0.52 : 0.34);
      ctx.fillStyle = `hsl(${this.hue + 18}, 100%, 94%)`;
      ctx.beginPath();
      ctx.moveTo(0, -rayWidth);
      ctx.quadraticCurveTo(rayLength * 0.52, -rayWidth * 0.4, rayLength, 0);
      ctx.quadraticCurveTo(rayLength * 0.52, rayWidth * 0.4, 0, rayWidth);
      ctx.quadraticCurveTo(rayLength * 0.1, rayWidth * 0.18, 0, 0);
      ctx.quadraticCurveTo(rayLength * 0.1, -rayWidth * 0.18, 0, -rayWidth);
      ctx.fill();
      ctx.restore();
    }

    ctx.globalAlpha = alpha * 0.72;
    ctx.fillStyle = `hsl(${this.hue + 20}, 100%, 96%)`;
    ctx.beginPath();
    ctx.arc(0, 0, core * 1.15, 0, Math.PI * 2);
    ctx.fill();

    ctx.globalAlpha = alpha * 0.18;
    ctx.fillStyle = `hsl(${this.hue}, 100%, 82%)`;
    ctx.beginPath();
    ctx.arc(0, 0, core * 3.6, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }
}

class SakuraDrift {
  constructor(initial = false) {
    this.reset(initial);
  }

  reset(initial = false) {
    this.x = random(-W() * 0.12, W() * 1.08);
    this.y = initial ? random(-H() * 0.2, H() * 1.05) : random(-120, -20);
    this.size = random(7, 18);
    this.phase = random(0, Math.PI * 2);
    this.orbit = random(6, 34);
    this.orbitSpeed = random(0.001, 0.003);
    this.vx = random(-0.12, 0.16);
    this.vy = random(0.14, 0.72);
    this.spin = random(-0.012, 0.012);
    this.rotation = random(0, Math.PI * 2);
    this.alpha = random(0.36, 0.78);
    this.color = petalColors[Math.floor(Math.random() * petalColors.length)];
    this.isFlower = Math.random() < 0.34;
    this.sprite = getSprite(this.isFlower ? 'flower' : 'petal', this.color);
    this.flip = Math.random() < 0.5 ? -1 : 1;
  }

  update(time) {
    applyPointerRepel(this, this.isFlower ? 104 : 118, this.isFlower ? 4.8 : 6.2);
    const drift = Math.sin(time * this.orbitSpeed + this.phase) * this.orbit;
    this.x += (this.vx + drift * 0.018 + state.windX * 0.28) * profile().speed;
    this.y += (this.vy + Math.cos(time * this.orbitSpeed * 0.82 + this.phase) * 0.18 + state.windY * 0.2) * profile().speed;
    this.rotation += this.spin + this.vx * 0.01;

    if (this.y > H() + 80 || this.x < -120 || this.x > W() + 140) {
      this.reset();
    }
  }

  draw() {
    if (this.isFlower) {
      drawSprite(this.sprite, this.x, this.y, this.size * profile().size * 1.22, this.rotation, this.alpha * 0.74 * profile().alpha);
    } else {
      drawSprite(this.sprite, this.x, this.y, this.size * profile().size, this.rotation, this.alpha * profile().alpha, this.flip);
    }
  }
}

class HazakuraDrift extends SakuraDrift {
  reset(initial = false) {
    super.reset(initial);
    this.color = hazakuraColors[Math.floor(Math.random() * hazakuraColors.length)];
    this.isFlower = Math.random() < 0.22;
    this.isGreen = this.color.g > this.color.r;
    this.alpha = this.isGreen ? random(0.26, 0.58) : random(0.28, 0.68);
    this.size = this.isGreen ? random(5, 13) : random(6, 16);
    this.sprite = getSprite(this.isGreen ? 'leaf' : this.isFlower ? 'flower' : 'petal', this.color);
  }

  draw() {
    if (!this.isGreen) {
      super.draw();
      return;
    }

    drawSprite(this.sprite, this.x, this.y, this.size * profile().size, this.rotation, this.alpha * profile().alpha, this.flip);
  }
}

class SakuraTree {
  constructor(side) {
    this.side = side;
    this.branches = Array.from({ length: side === 'left' ? 11 : 13 }, () => ({
      startY: random(-20, -110),
      length: random(80, 230),
      angle: -Math.PI / 2 + random(-0.56, 0.56),
      width: random(2, 5.2),
      curve: random(-0.65, 0.65),
    }));
    this.flowers = Array.from({ length: 76 }, () => ({
      x: random(-135, 135),
      y: random(-286, -44),
      size: random(7, 20),
      color: petalColors[Math.floor(Math.random() * petalColors.length)],
      alpha: random(0.16, 0.38),
    }));
  }

  draw() {
    if (!state.showNight) {
      return;
    }

    const baseX = this.side === 'left' ? -34 : W() + 34;
    const direction = this.side === 'left' ? 1 : -1;

    ctx.save();
    ctx.translate(baseX, H() + 12);
    ctx.scale(direction, 1);
    ctx.strokeStyle = 'rgba(30, 15, 24, 0.9)';
    ctx.lineCap = 'round';

    ctx.lineWidth = 10;
    ctx.beginPath();
    ctx.moveTo(0, 0);
    ctx.quadraticCurveTo(14, -118, 2, -246);
    ctx.stroke();

    for (const branch of this.branches) {
      ctx.lineWidth = branch.width;
      ctx.beginPath();
      ctx.moveTo(0, branch.startY);
      const endX = Math.cos(branch.angle) * branch.length + branch.curve * 62;
      const endY = branch.startY + Math.sin(branch.angle) * branch.length;
      ctx.quadraticCurveTo(branch.curve * 46, branch.startY - branch.length * 0.5, endX, endY);
      ctx.stroke();
    }

    for (const flower of this.flowers) {
      drawSoftGlow(flower.x, flower.y, flower.size, [
        [0, `rgba(${flower.color.r}, ${flower.color.g}, ${flower.color.b}, ${flower.alpha})`],
        [0.72, `rgba(${flower.color.r}, ${flower.color.g}, ${flower.color.b}, ${flower.alpha * 0.32})`],
        [1, `rgba(${flower.color.r}, ${flower.color.g}, ${flower.color.b}, 0)`],
      ]);
    }

    ctx.restore();
  }
}

function drawPointerAura() {
  pointer.pulse *= 0.88;
}

const sakuraDrifts = Array.from({ length: 122 }, () => new SakuraDrift(true));
const hazakuraDrifts = Array.from({ length: 124 }, () => new HazakuraDrift(true));
const sparkles = Array.from({ length: 58 }, () => new Sparkle(true));
const magicLights = Array.from({ length: 180 }, () => new MagicLight(true));
const sparkLines = Array.from({ length: 108 }, () => new SparkLine(true));
const trees = [new SakuraTree('left'), new SakuraTree('right')];

function setPaused(paused) {
  if (state.paused === paused) {
    return;
  }

  state.paused = paused;
  if (paused) {
    state.pausedAt = performance.now() - state.startTime;
    cancelAnimationFrame(state.animationFrame);
    ctx.clearRect(0, 0, W(), H());
  } else {
    state.startTime = performance.now() - state.pausedAt;
    state.animationFrame = requestAnimationFrame(animate);
  }
}

async function setupTauriEvents() {
  try {
    const eventApi = window.__TAURI__?.event || (await import('@tauri-apps/api/event'));

    await eventApi.listen('sakura-paused-changed', (event) => {
      setPaused(Boolean(event.payload));
    });

    await eventApi.listen('sakura-night-changed', (event) => {
      state.showNight = Boolean(event.payload);
    });

    await eventApi.listen('sakura-mode-changed', (event) => {
      state.mode = ['magic', 'spark', 'hazakura'].includes(event.payload) ? event.payload : 'sakura';
      pointer.pulse = Math.min(1, pointer.pulse + 0.36);
    });

    await eventApi.listen('sakura-focus-changed', (event) => {
      state.focus = ['quiet', 'normal', 'play'].includes(event.payload) ? event.payload : 'normal';
      pointer.pulse = Math.min(1, pointer.pulse + 0.24);
    });

    await eventApi.listen('sakura-cursor-moved', (event) => {
      const [x, y] = event.payload || [];
      updatePointer(Number(x), Number(y));
    });
  } catch (error) {
    console.warn('Tauri event API is unavailable in this context.', error);
  }
}

function animate(timestamp) {
  if (!state.startTime) {
    state.startTime = timestamp;
  }

  if (state.paused) {
    ctx.clearRect(0, 0, W(), H());
    return;
  }

  const time = timestamp - state.startTime;
  drawBackground(time);

  for (const tree of trees) {
    tree.draw();
  }

  drawPointerAura();

  for (const sparkle of sparkles) {
    sparkle.update(time);
    sparkle.draw();
  }

  if (state.mode === 'magic') {
    for (let i = 0; i < magicLights.length; i += 1) {
      if (!shouldDraw(i / magicLights.length)) continue;
      const light = magicLights[i];
      light.update(time);
      light.draw(time);
    }
  } else if (state.mode === 'spark') {
    for (let i = 0; i < sparkLines.length; i += 1) {
      if (!shouldDraw(i / sparkLines.length)) continue;
      const spark = sparkLines[i];
      spark.update(time);
      spark.draw(time);
    }
  } else if (state.mode === 'hazakura') {
    for (let i = 0; i < hazakuraDrifts.length; i += 1) {
      if (!shouldDraw(i / hazakuraDrifts.length)) continue;
      const hazakura = hazakuraDrifts[i];
      hazakura.update(time);
      hazakura.draw();
    }
  } else {
    for (let i = 0; i < sakuraDrifts.length; i += 1) {
      if (!shouldDraw(i / sakuraDrifts.length)) continue;
      const sakura = sakuraDrifts[i];
      sakura.update(time);
      sakura.draw();
    }
  }

  state.animationFrame = requestAnimationFrame(animate);
}

window.addEventListener('mousemove', (event) => {
  updatePointer(event.clientX, event.clientY);
});

window.addEventListener('resize', resize);

resize();
setupTauriEvents();
state.animationFrame = requestAnimationFrame(animate);
