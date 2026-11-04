import { defineConfig } from "vite";
import { svelte } from "@sveltejs/vite-plugin-svelte";
import { resolve } from "node:path";

// The mixer imports the generator's Lua straight from ../lua, so the site
// always runs the same code as the package. Each page is its own HTML
// entry, so only the mixer and the ornaments load the generator.
const PAGES = ["index", "mixer/index", "ornaments/index", "guide/index"];

export default defineConfig({
  plugins: [svelte()],
  server: { fs: { allow: [".."] } },
  worker: { format: "es" },
  // Bundle every dependency at startup. Vite scans only index.html by
  // default and never the workers, so a dependency found later (opening
  // another page, or a worker importing flora or wasmoon) re-bundles them
  // and fails requests in flight (504 Outdated Optimize Dep).
  optimizeDeps: {
    entries: PAGES.map((p) => `${p}.html`),
    include: ["@alpaca-software/web-flora", "@alpaca-software/web-flora/engine", "wasmoon", "pdfjs-dist"],
  },
  build: {
    outDir: "dist", assetsInlineLimit: 0, chunkSizeWarningLimit: 2000,
    rollupOptions: {
      input: Object.fromEntries(PAGES
        .map((p) => [p.replace("/index", ""), resolve(import.meta.dirname, `${p}.html`)])),
    },
  },
});
