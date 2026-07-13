(function () {
  'use strict';

  function isStandalonePwa() {
    return window.matchMedia('(display-mode: standalone)').matches ||
      window.matchMedia('(display-mode: fullscreen)').matches ||
      window.navigator.standalone === true;
  }

  window.__profioPwa = { isStandalone: isStandalonePwa() };

  window.profioRegisterFirebaseMessagingSw = function () {
    if (!('serviceWorker' in navigator)) return Promise.resolve();
    if (window.__profioFcmSwRegistered) return Promise.resolve();

    return navigator.serviceWorker.getRegistration('/').then(function (existing) {
      if (existing && existing.active) {
        window.__profioFcmSwRegistered = true;
        return existing;
      }
      return navigator.serviceWorker.register('firebase-messaging-sw.js', { scope: '/' });
    }).then(function (reg) {
      if (reg) window.__profioFcmSwRegistered = true;
      return reg;
    }).catch(function (err) {
      console.warn('[FCM] No se pudo registrar firebase-messaging-sw.js', err);
    });
  };

  // Evitar que Flutter registre su SW (compite con Firebase y puede dejar la PWA en blanco).
  (function patchFlutterLoader() {
    var timer = setInterval(function () {
      if (!window._flutter || !window._flutter.loader) return;
      clearInterval(timer);

      var proto = Object.getPrototypeOf(window._flutter.loader);
      if (!proto || proto.__profioPatched) return;
      proto.__profioPatched = true;

      var originalLoad = proto.load;
      proto.load = function (opts) {
        var options = opts || {};
        if (options.serviceWorkerSettings) {
          delete options.serviceWorkerSettings;
        }
        return originalLoad.call(this, options);
      };
    }, 0);
  })();

  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.addEventListener('message', function (event) {
      if (event.data && event.data.type === 'NOTIFICATION_CLICK' && event.data.url) {
        window.location.href = event.data.url;
      }
    });
  }

  window.addEventListener('load', function () {
    if (!window.__profioPwa.isStandalone && 'caches' in window) {
      caches.keys().then(function (keys) {
        keys.forEach(function (key) { caches.delete(key); });
      });
    }
  });
})();
