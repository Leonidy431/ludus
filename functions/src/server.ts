/**
 * Own backend 3.0: the same /api/ludus/** routes as the Cloud Function
 * "api", served by a plain Express server in the VM8 container
 * (docs/version-3.0/HLD_BACKEND_3.0_VM8_HOT_MIRROR_2026-10-01.md, P1).
 *
 * The Dockerfile used to start lib/index.js, which only exports Cloud
 * Functions and never listens, so the container answered nothing.  This
 * module listens on PORT (3000 by default) and hands every request to
 * the router's dispatch(), the code the Cloud Function runs too.
 */

import * as admin from 'firebase-admin';
import express from 'express';
import type { Server } from 'http';

// Credentials come from the environment (GOOGLE_APPLICATION_CREDENTIALS
// on the VM volume), never from the image or the repo.
if (admin.apps.length === 0) {
  admin.initializeApp();
}

// Imported after initializeApp: the handlers reach Firestore through the
// default app.
// eslint-disable-next-line @typescript-eslint/no-var-requires
const { dispatch } = require('./api/ludus-router');

export function createApp(): express.Express {
  const app = express();
  app.disable('x-powered-by');
  // Cloud Functions parse JSON bodies before the handler runs; the
  // container must do the same or POST handlers see an empty body.
  app.use(express.json({ limit: '1mb' }));
  // The container health check (Dockerfile) asks /health; it is the
  // same public health route the Hosting rewrite serves.
  app.get('/health', (req, res, next) => {
    req.url = '/api/ludus/health';
    next();
  });
  app.all('*', (req, res) => {
    Promise.resolve(dispatch(req, res)).catch((err: unknown) => {
      if (!res.headersSent) {
        res.status(500).json({ error: 'internal error' });
      }
      console.error('dispatch failed', err);
    });
  });
  return app;
}

export function start(port = Number(process.env.PORT || 3000)): Server {
  return createApp().listen(port, () => {
    console.log(`ludus backend listening on ${port}`);
  });
}

if (require.main === module) {
  start();
}
