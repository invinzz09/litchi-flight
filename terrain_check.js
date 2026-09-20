// Оценка отклонения высоты над землёй между точками для разных шагов MaxSeg.
// Запускать в javascript_tool ПОСЛЕ импорта плотного CSV (-MaxSeg 40) в хаб.
// Вернёт по каждому кандидату максимальное отклонение (м) и рекомендацию.
const TOL = 5; // допуск, м
const CANDS = [500, 250, 160, 120, 80];
const a = GStool.markerToWaypoints;
const P = Object.keys(a).map(k => ({ lat: a[k].wp.latitude, lon: a[k].wp.longitude, alt: a[k].wp.altitude }));
const lat0 = P[0].lat * Math.PI / 180, kx = 6371000 * Math.PI / 180 * Math.cos(lat0), ky = 6371000 * Math.PI / 180;
P.forEach(p => { p.x = kx * (p.lon - P[0].lon); p.y = ky * (p.lat - P[0].lat); });
// разбить на ряды: новый ряд, когда направление меняется больше чем на 20°
const rows = []; let cur = [P[0]];
for (let i = 1; i < P.length; i++) {
  if (i >= 2) {
    const a1 = Math.atan2(P[i-1].y - P[i-2].y, P[i-1].x - P[i-2].x), a2 = Math.atan2(P[i].y - P[i-1].y, P[i].x - P[i-1].x);
    let d = Math.abs(a1 - a2) * 180 / Math.PI; if (d > 180) d = 360 - d;
    if (d > 20) { rows.push(cur); cur = [P[i-1]]; }
  }
  cur.push(P[i]);
}
rows.push(cur);
const rowsInfo = rows.map(r => { let s = [0]; for (let i = 1; i < r.length; i++) s.push(s[i-1] + Math.hypot(r[i].x - r[i-1].x, r[i].y - r[i-1].y)); return { r, s, L: s[s.length-1] }; });
const out = {};
for (const D of CANDS) {
  let worst = 0, npts = 0;
  for (const { r, s, L } of rowsInfo) {
    const segs = Math.max(1, Math.ceil(L / D)); npts += segs + 1;
    const nodes = []; for (let k = 0; k <= segs; k++) { const t = L * k / segs; let j = 0; while (j < s.length - 2 && s[j+1] < t) j++; const f = s[j+1] > s[j] ? (t - s[j]) / (s[j+1] - s[j]) : 0; nodes.push({ t, alt: r[j].alt + f * (r[j+1].alt - r[j].alt) }); }
    for (let i = 0; i < r.length; i++) { const t = s[i]; let j = 0; while (j < nodes.length - 2 && nodes[j+1].t < t) j++; const f = (t - nodes[j].t) / (nodes[j+1].t - nodes[j].t || 1); const lin = nodes[j].alt + f * (nodes[j+1].alt - nodes[j].alt); worst = Math.max(worst, Math.abs(r[i].alt - lin)); }
  }
  out[D] = { maxDev: +worst.toFixed(1), waypoints: npts };
}
const rec = CANDS.find(D => out[D].maxDev <= TOL) || CANDS[CANDS.length-1];
'rows=' + rows.length + ' | ' + CANDS.map(D => D + 'm: dev ' + out[D].maxDev + ' m, ' + out[D].waypoints + ' wp').join(' | ') + ' | RECOMMEND MaxSeg=' + rec;
