/// <reference types="vitest" />
import react from '@vitejs/plugin-react';
import { defineConfig, type Plugin } from 'vite';

/**
 * Content-Security-Policy solo en producción (el servidor de desarrollo de Vite necesita
 * scripts inline para HMR). GitHub Pages no permite cabeceras propias: se usa <meta>.
 */
const CSP = [
  "default-src 'self'",
  "script-src 'self'",
  "worker-src 'self' blob:",
  "style-src 'self' 'unsafe-inline'",
  "img-src 'self' data: blob: https://tiles.openfreemap.org",
  "font-src 'self'",
  "connect-src 'self' https://tiles.openfreemap.org",
  "object-src 'none'",
  "base-uri 'self'",
  "form-action 'self'",
].join('; ');

const cspPlugin = (): Plugin => ({
  name: 'auralink-csp',
  apply: 'build',
  transformIndexHtml: (html) => html.replace('<head>', `<head>
    <meta http-equiv="Content-Security-Policy" content="${CSP}" />`),
});

// En GitHub Pages el sitio vive en /<repo>/; el workflow define VITE_BASE.
export default defineConfig({
  base: process.env.VITE_BASE ?? '/',
  plugins: [react(), cspPlugin()],
  worker: { format: 'es' },
  build: {
    target: 'es2022',
    sourcemap: true,
    chunkSizeWarningLimit: 900,
    rollupOptions: { output: { manualChunks: { maplibre: ['maplibre-gl'], react: ['react', 'react-dom'] } } },
  },
  test: { environment: 'node', include: ['src/**/*.test.ts'], testTimeout: 60_000 },
});
