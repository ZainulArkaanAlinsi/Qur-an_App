import { serve } from '@hono/node-server';
import { createApp } from './app.js';
import { loadConfig } from './config.js';
import { QfClient } from './qf-client.js';

const config = loadConfig();
const app = createApp({ config, client: new QfClient(config) });

serve({ fetch: app.fetch, port: config.port }, (info) => {
  // Jangan pernah mencetak kredensial atau token.
  console.info(
    JSON.stringify({
      msg: 'BFF siap',
      port: info.port,
      environment: config.environment,
    }),
  );
});
