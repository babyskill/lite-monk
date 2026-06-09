// @ts-check
import { defineConfig } from 'astro/config';

import tailwindcss from '@tailwindcss/vite';
import cloudflare from '@astrojs/cloudflare';

// https://astro.build/config
export default defineConfig({
  // Temporary (maintenance): server output so the maintenance middleware can
  // intercept EVERY route. Static pages would otherwise bypass middleware.
  // Revert (remove this line) when maintenance mode is turned off.
  output: 'server',

  vite: {
    plugins: [tailwindcss()]
  },

  adapter: cloudflare({ platformProxy: { enabled: true } })
});