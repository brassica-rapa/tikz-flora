import { defineConfig } from "vite";
import { resolve } from "node:path";

// The garden for other web pages (src/lib/garden.js): one ES module, its
// worker (which holds the generator's Lua) and the Lua WebAssembly, as
// static files in build/garden/. A page loads garden.js from wherever the
// files are served; the worker and the wasm are found beside it.
export default defineConfig({
  publicDir: false,
  // Relative, so the worker is found beside garden.js wherever it is served.
  base: "./",
  worker: { format: "es" },
  build: {
    outDir: resolve(import.meta.dirname, "../build/garden"),
    emptyOutDir: true,
    assetsInlineLimit: 0,
    chunkSizeWarningLimit: 2000,
    lib: { entry: resolve(import.meta.dirname, "src/lib/garden.js"), formats: ["es"], fileName: () => "garden.js" },
  },
});
