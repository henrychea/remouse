(() => {
  const reduce = matchMedia("(prefers-reduced-motion: reduce)");
  const canvas = document.getElementById("mouse");
  const toggle = document.getElementById("toggle");
  const status = document.getElementById("status");
  const ctx = canvas.getContext("2d");

  const C = {
    primary: [77, 168, 255],
    error: [255, 84, 73],
    lit: [228, 255, 244],
    dim: [82, 82, 91],
    seamDim: [62, 62, 68],
    idle: [34, 34, 40],
  };

  const key = (r, cols) => cols.map((c) => r * 17 + c);
  const range = (a, b) => Array.from({ length: b - a + 1 }, (_, i) => a + i);
  const body = new Set([
    ...key(1, [6, 7, 8, 9, 10]), ...key(2, [4, 5, 11, 12]), ...key(3, [3, 13]),
    ...range(4, 15).flatMap((r) => key(r, [2, 14])),
    ...key(16, [3, 13]), ...key(17, [3, 13]), ...key(18, [4, 5, 11, 12]), ...key(19, [6, 7, 8, 9, 10]),
  ]);
  const up = new Set([...key(4, [8]), ...key(5, [7, 8, 9]), ...key(6, [6, 8, 10]), ...range(7, 10).flatMap((r) => key(r, [8]))]);
  const down = new Set([...range(4, 7).flatMap((r) => key(r, [8])), ...key(8, [6, 8, 10]), ...key(9, [7, 8, 9]), ...key(10, [8])]);
  const seam = new Set(key(11, range(3, 13)));

  const idleLook = { c: C.idle, r: 0.8, o: 0.45 };
  const looks = (inv) => ({
    arrow: { c: inv ? C.primary : C.error, r: 1.65, o: 1 },
    body: { c: inv ? C.lit : C.dim, r: 1.35, o: inv ? 0.9 : 0.65 },
    seam: { c: inv ? C.primary : C.seamDim, r: 0.95, o: inv ? 0.28 : 0.35 },
    idle: idleLook,
  });
  const role = (col, row, inv) => {
    const k = row * 17 + col;
    if ((inv ? up : down).has(k)) return "arrow";
    if (body.has(k)) return "body";
    if (seam.has(k)) return "seam";
    return "idle";
  };

  const clamp = (v) => Math.min(Math.max(v, 0), 1);
  const easeOut = (v) => 1 - Math.pow(1 - v, 3);
  const mix = (a, b, t) => a + (b - a) * t;

  let inverted = true;
  let ripple = null;

  function draw(now) {
    const dpr = window.devicePixelRatio || 1;
    const w = canvas.clientWidth, h = canvas.clientHeight;
    if (!w || !h) return;
    if (canvas.width !== Math.round(w * dpr)) { canvas.width = Math.round(w * dpr); canvas.height = Math.round(h * dpr); }
    const scale = canvas.height / 104;
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    ctx.translate((canvas.width - 84 * scale) / 2, 0);
    ctx.scale(scale, scale);

    const elapsed = ripple ? (now - ripple.at) / 1000 : null;
    const from = ripple ? ripple.from : inverted;
    const cur = looks(inverted), prev = looks(from);

    for (let row = 0; row < 21; row++) {
      for (let col = 0; col < 17; col++) {
        const target = role(col, row, inverted);
        const source = elapsed === null ? target : role(col, row, from);
        const delay = target === "arrow"
          ? (inverted ? (10 - row) : (row - 4)) * 0.024
          : Math.hypot(col - 8, row - 7) * 0.018;
        let appear = 1, pop = 1;
        if (elapsed !== null) {
          appear = clamp((elapsed - delay) / 0.22);
          pop = 1 + 0.35 * (1 - easeOut(clamp((elapsed - delay) / 0.32)));
        }
        const a = prev[source], b = cur[target];
        const rgb = [0, 1, 2].map((i) => Math.round(mix(a.c[i], b.c[i], appear)));
        const radius = mix(a.r, b.r, appear) * pop;
        const x = 5.2 + col * 4.6, y = 6 + row * 4.6;
        ctx.globalAlpha = mix(a.o, b.o, appear);
        ctx.fillStyle = `rgb(${rgb})`;
        if (target === "arrow" && appear > 0.01) {
          ctx.shadowColor = `rgba(${b.c},${0.8 * appear})`;
          ctx.shadowBlur = 6 * scale;
        } else {
          ctx.shadowBlur = 0;
        }
        ctx.beginPath();
        ctx.arc(x, y, radius, 0, Math.PI * 2);
        ctx.fill();
      }
    }
    ctx.globalAlpha = 1;
    ctx.shadowBlur = 0;

    if (ripple && elapsed < 1) requestAnimationFrame(draw);
    else ripple = null;
  }

  function flip() {
    const was = inverted;
    inverted = !inverted;
    toggle.setAttribute("aria-checked", String(inverted));
    status.textContent = inverted ? "Mouse: inverted · Trackpad: untouched" : "Mouse: standard · Trackpad: untouched";
    status.classList.toggle("off", !inverted);
    canvas.setAttribute("aria-label", `Dot-matrix mouse with a ${inverted ? "blue arrow pointing up: wheel scrolling is inverted" : "red arrow pointing down: wheel scrolling is standard"}.`);
    if (reduce.matches) { draw(performance.now()); return; }
    const start = !ripple;
    ripple = { from: was, at: performance.now() };
    if (start) requestAnimationFrame(draw);
  }

  canvas.addEventListener("click", () => toggle.click());
  toggle.addEventListener("click", flip);
  addEventListener("resize", () => { if (!ripple) draw(performance.now()); });
  draw(performance.now());

  const glyphs = {
    wheel: ["01110", "10101", "10101", "10001", "01110"],
    switch: ["00000", "11111", "10011", "11111", "00000"],
    bolt: ["00110", "01100", "11111", "00110", "01100"],
    warn: ["00100", "01010", "01010", "10001", "11111"],
    lock: ["01110", "01010", "11111", "11011", "11111"],
    code: ["00000", "01010", "10001", "01010", "00000"],
  };
  const ns = "http://www.w3.org/2000/svg";
  document.querySelectorAll(".dot-icon").forEach((el) => {
    const svg = document.createElementNS(ns, "svg");
    svg.setAttribute("viewBox", "0 0 10 10");
    svg.setAttribute("aria-hidden", "true");
    const color = el.dataset.glyph === "warn" ? "#FFB800" : "#4DA8FF";
    glyphs[el.dataset.glyph].forEach((line, r) => [...line].forEach((bit, c) => {
      const dot = document.createElementNS(ns, "circle");
      dot.setAttribute("cx", 1 + c * 2);
      dot.setAttribute("cy", 1 + r * 2);
      dot.setAttribute("r", bit === "1" ? 0.75 : 0.35);
      dot.setAttribute("fill", bit === "1" ? color : "#2C2C32");
      svg.appendChild(dot);
    }));
    el.appendChild(svg);
  });
})();
