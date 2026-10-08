// Placeholder Flutter Service Worker
console.log('BillSprout ERP Service Worker - Static Deployment Mode');

self.addEventListener('fetch', function(event) {
  // Simple passthrough for now
  event.respondWith(fetch(event.request));
});