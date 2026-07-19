// Stub: cualquier SW Flutter viejo se actualiza a esto y se autodestruye.
// Limpia cachés del icono de inicio (iOS) sin navegar clientes (rompe el boot).
self.addEventListener('install', function (event) {
  self.skipWaiting();
});

self.addEventListener('activate', function (event) {
  event.waitUntil(
    caches.keys()
      .then(function (keys) {
        return Promise.all(keys.map(function (k) { return caches.delete(k); }));
      })
      .catch(function () {})
      .then(function () {
        return self.registration.unregister();
      })
      .catch(function () {})
  );
});

self.addEventListener('fetch', function (event) {
  // No interceptar: red siempre.
  return;
});
