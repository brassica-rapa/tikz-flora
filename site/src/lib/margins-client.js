// A margins.worker.js worker as promises: post(message) resolves with its
// reply, or rejects with the error it reports or dies of.
export function client() {
  const worker = new Worker(new URL("./margins.worker.js", import.meta.url), { type: "module" });
  let next = 0;
  const waiting = new Map();
  worker.onmessage = (e) => {
    const p = waiting.get(e.data.id);
    waiting.delete(e.data.id);
    if (!p) return;
    if (e.data.error) p.reject(new Error(e.data.error));
    else p.resolve(e.data);
  };
  worker.onerror = (e) => {
    for (const p of waiting.values()) p.reject(new Error(e.message || "margins worker failed"));
    waiting.clear();
  };
  return {
    post: (msg) => new Promise((resolve, reject) => {
      const id = ++next;
      waiting.set(id, { resolve, reject });
      worker.postMessage({ ...msg, id });
    }),
    stop: () => worker.terminate(),
  };
}

// A CSS colour as sRGB 0-1, through a 1 px canvas (oklch and all).
export function rgbOf(css) {
  const c = new OffscreenCanvas(1, 1), x = c.getContext("2d");
  x.fillStyle = css;
  x.fillRect(0, 0, 1, 1);
  const d = x.getImageData(0, 0, 1, 1).data;
  return [d[0] / 255, d[1] / 255, d[2] / 255];
}
