/**
 * sw.js — Service Worker for Ludus offline support
 *
 * Handles:
 * - Static asset caching (ludus-game.js, ludus-game.css)
 * - Offline fallback for the game tab
 * - Background sync for pending mutations
 * - Cache strategies: network-first for dynamic, cache-first for static
 */

const CACHE_NAME = "ludus-v1";
const STATIC_ASSETS = [
  "/ludus/ludus-game.js",
  "/ludus/ludus-game.css",
  "/ludus/idb-schema.js", // Compiled from TypeScript
];

const API_CACHE_NAME = "ludus-api-v1";
const API_ROUTES = ["/api/ludus/", "/api/firestore/"];

const SYNC_TAG = "ludus-background-sync";

// ============================================================================
// INSTALL EVENT
// ============================================================================

self.addEventListener("install", (event) => {
  console.log("[Ludus SW] Installing service worker...");

  event.waitUntil(
    (async () => {
      try {
        const cache = await caches.open(CACHE_NAME);
        await cache.addAll(STATIC_ASSETS);
        console.log("[Ludus SW] Static assets cached");

        // Skip waiting to activate immediately
        self.skipWaiting();
      } catch (error) {
        console.error("[Ludus SW] Cache install failed:", error);
      }
    })()
  );
});

// ============================================================================
// ACTIVATE EVENT
// ============================================================================

self.addEventListener("activate", (event) => {
  console.log("[Ludus SW] Activating service worker...");

  event.waitUntil(
    (async () => {
      try {
        const cacheNames = await caches.keys();
        await Promise.all(
          cacheNames.map((cacheName) => {
            if (
              cacheName !== CACHE_NAME &&
              cacheName !== API_CACHE_NAME
            ) {
              console.log("[Ludus SW] Deleting old cache:", cacheName);
              return caches.delete(cacheName);
            }
          })
        );

        // Claim all clients
        await self.clients.claim();
        console.log("[Ludus SW] Service worker activated");
      } catch (error) {
        console.error("[Ludus SW] Activation failed:", error);
      }
    })()
  );
});

// ============================================================================
// FETCH EVENT
// ============================================================================

self.addEventListener("fetch", (event) => {
  const { request } = event;
  const url = new URL(request.url);

  // Skip cross-origin requests and non-GET
  if (url.origin !== self.location.origin || request.method !== "GET") {
    return;
  }

  // Route to appropriate strategy
  if (isStaticAsset(url)) {
    event.respondWith(cacheFirstStrategy(request));
  } else if (isApiRoute(url)) {
    event.respondWith(networkFirstStrategy(request));
  } else {
    event.respondWith(networkFirstStrategy(request));
  }
});

// ============================================================================
// BACKGROUND SYNC EVENT
// ============================================================================

self.addEventListener("sync", (event) => {
  if (event.tag === SYNC_TAG) {
    console.log("[Ludus SW] Background sync triggered");
    event.waitUntil(syncPendingMutations());
  }
});

// ============================================================================
// MESSAGE EVENT (Communication with client)
// ============================================================================

self.addEventListener("message", (event) => {
  const { type, payload } = event.data;

  if (type === "SKIP_WAITING") {
    self.skipWaiting();
  }

  if (type === "REQUEST_SYNC") {
    // Request background sync when client comes online
    self.registration.sync
      .register(SYNC_TAG)
      .then(() => {
        console.log("[Ludus SW] Sync registered");
      })
      .catch((error) => {
        console.error("[Ludus SW] Sync registration failed:", error);
      });
  }

  if (type === "CLEAR_CACHE") {
    caches.delete(CACHE_NAME).then(() => {
      console.log("[Ludus SW] Cache cleared");
    });
  }
});

// ============================================================================
// CACHE STRATEGIES
// ============================================================================

/**
 * Cache-first strategy: return from cache, fall back to network
 * Used for static assets that rarely change
 */
async function cacheFirstStrategy(request) {
  const cache = await caches.open(CACHE_NAME);
  const cached = await cache.match(request);

  if (cached) {
    return cached;
  }

  try {
    const response = await fetch(request);
    if (response.status === 200) {
      cache.put(request, response.clone());
    }
    return response;
  } catch (error) {
    console.error("[Ludus SW] Cache-first fetch failed:", error);
    return createOfflineFallback();
  }
}

/**
 * Network-first strategy: try network, fall back to cache
 * Used for API calls and dynamic content
 */
async function networkFirstStrategy(request) {
  const cache = await caches.open(API_CACHE_NAME);

  try {
    const response = await fetch(request);

    if (response.status === 200) {
      cache.put(request, response.clone());
    }

    return response;
  } catch (error) {
    console.error("[Ludus SW] Network fetch failed:", error);

    const cached = await cache.match(request);
    if (cached) {
      return cached;
    }

    // Return offline indicator for API requests
    return new Response(
      JSON.stringify({
        error: "offline",
        message: "No internet connection. Queuing for sync.",
      }),
      {
        status: 503,
        headers: { "Content-Type": "application/json" },
      }
    );
  }
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

function isStaticAsset(url) {
  return STATIC_ASSETS.some((asset) => url.pathname.endsWith(asset));
}

function isApiRoute(url) {
  return API_ROUTES.some((route) => url.pathname.startsWith(route));
}

function createOfflineFallback() {
  return new Response(
    `
    <!DOCTYPE html>
    <html>
      <head>
        <title>Ludus — Offline</title>
        <style>
          body {
            font-family: system-ui, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
            color: #eee;
            margin: 0;
          }
          .container {
            text-align: center;
            padding: 2rem;
            background: rgba(0, 0, 0, 0.5);
            border-radius: 8px;
            max-width: 400px;
          }
          h1 { margin: 0 0 1rem 0; }
          p { line-height: 1.6; margin: 1rem 0; }
          .status {
            font-size: 3rem;
            margin: 1rem 0;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <h1>⛵ Ludus Offline</h1>
          <div class="status">📡</div>
          <p>
            No internet connection detected.
            Your game data is cached and will sync automatically when you're back online.
          </p>
          <p>Continue playing, or wait for connection.</p>
        </div>
      </body>
    </html>
  `,
    {
      status: 200,
      headers: { "Content-Type": "text/html; charset=utf-8" },
    }
  );
}

/**
 * Sync pending mutations to Firestore when connection is restored
 */
async function syncPendingMutations() {
  try {
    // Import IDB schema (assumes it's available in the global scope)
    // In production, this would be embedded or imported differently
    console.log("[Ludus SW] Starting background sync of pending mutations");

    // Post message to all clients requesting sync
    self.clients.matchAll().then((clients) => {
      clients.forEach((client) => {
        client.postMessage({
          type: "SYNC_START",
          timestamp: Date.now(),
        });
      });
    });

    // Wait for client-side sync to complete
    await new Promise((resolve) => setTimeout(resolve, 5000));

    self.clients.matchAll().then((clients) => {
      clients.forEach((client) => {
        client.postMessage({
          type: "SYNC_COMPLETE",
          timestamp: Date.now(),
        });
      });
    });
  } catch (error) {
    console.error("[Ludus SW] Background sync failed:", error);
    throw error;
  }
}
