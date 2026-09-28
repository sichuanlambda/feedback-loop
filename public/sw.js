// Architecture Helper service worker.
//
// v1 pre-cached four HTML pages on install. That fetched all four on every
// visit (one of them 404'd, so the install never succeeded and retried each
// page load), counted them as page views, and risked serving stale pages.
// v2 caches only static assets and leaves navigation to the network.
const CACHE_NAME = 'architecture-helper-v2';
const STATIC_CACHE_URLS = [
  '/manifest.json',
  '/icon-512.png',
  '/apple-touch-icon.png'
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      // Cache each asset independently so one missing file cannot fail the install
      .then((cache) => Promise.allSettled(STATIC_CACHE_URLS.map((url) => cache.add(url))))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((names) => Promise.all(names.filter((n) => n !== CACHE_NAME).map((n) => caches.delete(n))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET' || event.request.mode === 'navigate') return;
  const url = new URL(event.request.url);
  if (url.origin !== self.location.origin || !STATIC_CACHE_URLS.includes(url.pathname)) return;
  event.respondWith(caches.match(event.request).then((cached) => cached || fetch(event.request)));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(clients.openWindow(event.notification.data?.url || '/'));
});
