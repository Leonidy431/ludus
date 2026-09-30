/**
 * sw.js — Service Worker for Ludus offline support (Meta Quest 3 build).
 *
 * Responsibilities:
 * - Precache the boot shell and the Ludus modules under a versioned name.
 * - Serve modules stale-while-revalidate and pages network-first.
 * - Keep API traffic network-only; offline writes live in IndexedDB.
 * - Relay background-sync requests to an open client, which owns the
 *   actual Firestore sync.
 */

// Bump CACHE_VERSION whenever PRECACHE_PATHS changes or a release must
// evict every stale copy at once; activate() drops all other versions.
const CACHE_VERSION = "2026-09-30.2";
const CACHE_PREFIX = "ludus-";
const STATIC_CACHE = `${CACHE_PREFIX}static-${CACHE_VERSION}`;
const RUNTIME_CACHE = `${CACHE_PREFIX}runtime-${CACHE_VERSION}`;

// Paths are resolved against this file, not hard-coded from the site
// root, so the build keeps working if /ludus/ is mounted elsewhere.
// Only files that really exist belong here: one 404 fails addAll() and
// the old list (with a non-existent idb-schema.js) left the cache empty.
const PRECACHE_PATHS = [
  "../",
  "../index.html",
  "ludus-design-system.css",
  "ludus-game.css",
  "ludus-dialogue.css",
  "rov-lake.css",
  "ludus-npc-dialogue-manager.js",
  "ludus-audio-manager.js",
  "ludus-npc-dialogue-ui.js",
  "rov-lake-manager.js",
  // The gates cannot be evaluated offline without the ACTION layer.
  "ludus-actions.js",
  "ludus-confession.js",
  "ludus-passion.js",
  "ludus-liturgical-clock.js",
  "ludus-glas.js",
  "ludus-rest.js",
  "ludus-outbox.js",
  "ludus-journal.js",
  "ludus-water.js",
  "data/passions.json",
  "data/rights.json",
  "ludus-game.js",
  // Without the synth offline, every missing recording would fall back
  // to silence on the first launch without network.
  "ludus-sacred-synth.js",
  // The offline dialogue pack lets a first-time guest talk with the
  // core mentors with no network at all.
  "data/dialogue-trees.json",
  "art/player-deacon-orarion.svg",
  "art/npc-elder-sergius.svg",
  "art/npc-theodora.svg",
  "art/npc-abba-john.svg",
  "art/npc-sister-catherine.svg",
];
const PRECACHE_URLS = PRECACHE_PATHS.map(
  (path) => new URL(path, self.location).href
);
const SHELL_URL = new URL("../index.html", self.location).href;

const API_PREFIXES = ["/api/"];
const SYNC_TAG = "ludus-background-sync";

// How long a client gets to confirm that its IndexedDB queue is flushed.
const SYNC_ACK_TIMEOUT_MS = 30000;

// ============================================================================
// INSTALL EVENT
// ============================================================================

self.addEventListener("install", (event) => {
  // Errors are deliberately not swallowed: a failed precache must fail
  // the install so the previous, complete worker keeps serving.
  event.waitUntil(
    (async () => {
      const cache = await caches.open(STATIC_CACHE);
      // 'reload' bypasses the HTTP cache so a new version never
      // precaches the bytes of the previous release.
      await cache.addAll(
        PRECACHE_URLS.map((url) => new Request(url, { cache: "reload" }))
      );
      console.log("[Ludus SW] Precached", PRECACHE_URLS.length, "assets");
    })()
  );
});

// ============================================================================
// ACTIVATE EVENT
// ============================================================================

self.addEventListener("activate", (event) => {
  event.waitUntil(
    (async () => {
      const keep = new Set([STATIC_CACHE, RUNTIME_CACHE]);
      const names = await caches.keys();
      // Only Ludus caches are pruned; other apps on the same origin
      // (for example webtypicon pages) own theirs.
      await Promise.all(
        names
          .filter((name) => name.startsWith(CACHE_PREFIX) && !keep.has(name))
          .map((name) => {
            console.log("[Ludus SW] Deleting old cache:", name);
            return caches.delete(name);
          })
      );
      await self.clients.claim();
    })()
  );
});

// ============================================================================
// FETCH EVENT
// ============================================================================

self.addEventListener("fetch", (event) => {
  const { request } = event;
  const url = new URL(request.url);

  // Cross-origin traffic (Firebase CDN, Google auth) and writes are
  // left to the browser untouched.
  if (url.origin !== self.location.origin || request.method !== "GET") {
    return;
  }

  if (isApiRoute(url)) {
    event.respondWith(networkOnly(request));
  } else if (request.mode === "navigate") {
    event.respondWith(networkFirstPage(request));
  } else {
    event.respondWith(staleWhileRevalidate(request, event));
  }
});

// ============================================================================
// BACKGROUND SYNC EVENT
// ============================================================================

self.addEventListener("sync", (event) => {
  if (event.tag === SYNC_TAG) {
    event.waitUntil(syncPendingMutations());
  }
});

// ============================================================================
// MESSAGE EVENT (communication with clients)
// ============================================================================

self.addEventListener("message", (event) => {
  // Any script on the origin can post here, so malformed data is ignored
  // rather than allowed to throw inside the worker.
  const data = event.data;
  if (!data || typeof data.type !== "string") {
    return;
  }

  if (data.type === "SKIP_WAITING") {
    self.skipWaiting();
  } else if (data.type === "REQUEST_SYNC") {
    event.waitUntil(requestSync());
  } else if (data.type === "CLEAR_CACHE") {
    event.waitUntil(clearLudusCaches());
  }
});

// ============================================================================
// CACHE STRATEGIES
// ============================================================================

/**
 * Serve from cache at once and refresh the copy in the background.
 *
 * Modules change between releases without a version bump, so a pure
 * cache-first strategy (the old behaviour) served stale code forever.
 */
async function staleWhileRevalidate(request, event) {
  const cached = await caches.match(request);

  const refresh = fetch(request)
    .then(async (response) => {
      if (isCacheable(response)) {
        const cache = await caches.open(RUNTIME_CACHE);
        await cache.put(request, response.clone());
      }
      return response;
    })
    .catch(() => null);

  if (cached) {
    event.waitUntil(refresh);
    return cached;
  }

  const fresh = await refresh;
  if (fresh) {
    return fresh;
  }
  // A missing script must fail as a network error; an HTML page served
  // in its place would be parsed as JavaScript and hide the real cause.
  return Response.error();
}

/**
 * Pages try the network first so a deploy is visible on next load.
 */
async function networkFirstPage(request) {
  try {
    const response = await fetch(request);
    if (response.ok) {
      const cache = await caches.open(RUNTIME_CACHE);
      await cache.put(request, response.clone());
    }
    return response;
  } catch (error) {
    // Hosting rewrites every path to index.html, so the shell is the
    // right offline answer for any navigation.
    const cached =
      (await caches.match(request)) || (await caches.match(SHELL_URL));
    return cached || createOfflineFallback();
  }
}

/**
 * API responses are never cached.
 *
 * They carry per-player data behind an auth header that the cache key
 * ignores, and offline writes are queued in IndexedDB by the client.
 */
async function networkOnly(request) {
  try {
    return await fetch(request);
  } catch (error) {
    return new Response(
      JSON.stringify({
        error: "offline",
        message: "No internet connection. Queuing for sync.",
      }),
      {
        status: 503,
        headers: {
          "Content-Type": "application/json",
          "Cache-Control": "no-store",
        },
      }
    );
  }
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

function isApiRoute(url) {
  return API_PREFIXES.some((prefix) => url.pathname.startsWith(prefix));
}

/**
 * Decide whether a sub-resource response is safe to store.
 *
 * Firebase Hosting rewrites unknown paths to index.html with status 200,
 * so an HTML body for a non-navigation request means the asset is gone
 * and must not be cached under the script's URL.
 */
function isCacheable(response) {
  if (!response || !response.ok || response.type !== "basic") {
    return false;
  }
  const type = response.headers.get("Content-Type") || "";
  return !type.includes("text/html");
}

async function clearLudusCaches() {
  const names = await caches.keys();
  await Promise.all(
    names
      .filter((name) => name.startsWith(CACHE_PREFIX))
      .map((name) => caches.delete(name))
  );
  console.log("[Ludus SW] Ludus caches cleared");
}

async function requestSync() {
  // Quest Browser and Safari lack Background Sync; the client then
  // retries on its own 'online' event, so this is not an error.
  if (!self.registration.sync) {
    return;
  }
  try {
    await self.registration.sync.register(SYNC_TAG);
  } catch (error) {
    console.warn("[Ludus SW] Sync registration failed:", error);
  }
}

function createOfflineFallback() {
  return new Response(
    `<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Ludus — Offline</title>
    <style>
      body {
        font-family: system-ui, sans-serif;
        display: flex;
        justify-content: center;
        align-items: center;
        min-height: 100vh;
        background: #0f0f0f;
        color: #f0f0f0;
        margin: 0;
      }
      .container {
        text-align: center;
        padding: 2rem;
        max-width: 400px;
      }
      h1 { color: #D4AF37; }
      p { line-height: 1.6; }
    </style>
  </head>
  <body>
    <div class="container">
      <h1>Ludus Offline</h1>
      <p>No internet connection and no cached copy of the game yet.</p>
      <p>Open Ludus once while online to enable offline play.</p>
    </div>
  </body>
</html>`,
    {
      status: 503,
      headers: {
        "Content-Type": "text/html; charset=utf-8",
        "Cache-Control": "no-store",
      },
    }
  );
}

/**
 * Ask an open client to flush its IndexedDB queue and wait for its ack.
 *
 * The worker cannot reach Firestore itself. The old version slept five
 * seconds and then announced SYNC_COMPLETE whether or not anything had
 * synced; now SYNC_COMPLETE reports whether a client actually confirmed.
 */
async function syncPendingMutations() {
  const clients = await self.clients.matchAll({ type: "window" });
  if (clients.length === 0) {
    // Rejecting makes the browser retry the sync later, when a page
    // that can perform it may be open again.
    throw new Error("No client available to perform sync");
  }

  const confirmed = await new Promise((resolve) => {
    const channel = new MessageChannel();
    const timer = setTimeout(() => resolve(false), SYNC_ACK_TIMEOUT_MS);
    channel.port1.onmessage = (msg) => {
      clearTimeout(timer);
      resolve(Boolean(msg.data && msg.data.ok));
    };
    // Only one client performs the sync so mutations are not sent twice.
    clients[0].postMessage(
      { type: "SYNC_START", timestamp: Date.now() },
      [channel.port2]
    );
  });

  for (const client of clients) {
    client.postMessage({
      type: "SYNC_COMPLETE",
      confirmed,
      timestamp: Date.now(),
    });
  }
}
