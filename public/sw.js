// Architecture Helper Service Worker
// Provides basic caching and PWA functionality

const CACHE_NAME = 'architecture-helper-v1';
const STATIC_CACHE_URLS = [
  '/',
  '/architecture_explorer/address_search',
  '/architecture_designer/step1', 
  '/architecture_explorer/building_library',
  '/manifest.json',
  '/icon-192.png',
  '/icon-512.png',
  '/apple-touch-icon.png'
];

// Install event - cache static resources
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => cache.addAll(STATIC_CACHE_URLS))
      .then(() => self.skipWaiting())
  );
});

// Activate event - clean up old caches
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((cacheNames) => {
        return Promise.all(
          cacheNames.map((cacheName) => {
            if (cacheName !== CACHE_NAME) {
              return caches.delete(cacheName);
            }
          })
        );
      })
      .then(() => self.clients.claim())
  );
});

// Fetch event - serve from cache when possible
self.addEventListener('fetch', (event) => {
  // Only handle GET requests
  if (event.request.method !== 'GET') {
    return;
  }
  
  // For navigation requests, try network first, then cache
  if (event.request.mode === 'navigate') {
    event.respondWith(
      fetch(event.request)
        .catch(() => {
          return caches.open(CACHE_NAME)
            .then((cache) => cache.match('/'));
        })
    );
    return;
  }
  
  // For other requests, try cache first, then network
  event.respondWith(
    caches.match(event.request)
      .then((response) => {
        return response || fetch(event.request);
      })
  );
});

// Handle deep links and share targets
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  
  event.waitUntil(
    clients.openWindow(event.notification.data?.url || '/')
  );
});

// Background sync for offline analysis uploads
self.addEventListener('sync', (event) => {
  if (event.tag === 'upload-analysis') {
    event.waitUntil(
      // Handle offline analysis uploads when connection restored
      processOfflineUploads()
    );
  }
});

async function processOfflineUploads() {
  // Placeholder for handling queued uploads when back online
  console.log('Processing offline uploads...');
}