// Shared portal behaviour. A soft violet spotlight (glow) that trails the cursor
// across every page, PlugTalk-style. The OS cursor stays visible. Skipped on touch.
(function () {
  if (window.matchMedia && window.matchMedia("(pointer: coarse)").matches) return;

  const fx = document.createElement("div");
  fx.className = "cursorfx";
  fx.innerHTML = '<div class="cfx-glow"></div>';
  const attach = () => document.body && document.body.appendChild(fx);
  if (document.body) attach(); else document.addEventListener("DOMContentLoaded", attach);

  const glow = fx.querySelector(".cfx-glow");
  let tx = innerWidth / 2, ty = innerHeight / 2, gx = tx, gy = ty;

  window.addEventListener("mousemove", (e) => {
    tx = e.clientX; ty = e.clientY; fx.style.opacity = "1";
  }, { passive: true });
  window.addEventListener("mouseout", (e) => { if (!e.relatedTarget) fx.style.opacity = "0"; });

  (function loop() {
    gx += (tx - gx) * 0.12; gy += (ty - gy) * 0.12;
    glow.style.transform = `translate(${gx}px, ${gy}px) translate(-50%, -50%)`;
    requestAnimationFrame(loop);
  })();
})();
