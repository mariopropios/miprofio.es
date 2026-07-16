(function () {
  'use strict';

  var PUSH_SW_KEY = 'profio_push_sw_active';

  function isStandalonePwa() {
    try {
      return window.matchMedia('(display-mode: standalone)').matches ||
        window.matchMedia('(display-mode: fullscreen)').matches ||
        window.navigator.standalone === true;
    } catch (_) {
      return false;
    }
  }

  function isIos() {
    try {
      return /iphone|ipad|ipod/i.test(navigator.userAgent) ||
        (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
    } catch (_) {
      return false;
    }
  }

  // Misma detección para browser y acceso directo; no cambiar el arranque.
  window.__profioPwa = { isStandalone: isStandalonePwa(), isIos: isIos() };

  function swScriptUrl(reg) {
    try {
      return (reg.active && reg.active.scriptURL) ||
        (reg.installing && reg.installing.scriptURL) ||
        (reg.waiting && reg.waiting.scriptURL) || '';
    } catch (_) {
      return '';
    }
  }

  function isFlutterServiceWorker(reg) {
    return swScriptUrl(reg).indexOf('flutter_service_worker') !== -1;
  }

  function isFirebaseMessagingSw(reg) {
    return swScriptUrl(reg).indexOf('firebase-messaging-sw.js') !== -1;
  }

  function unregisterFlutterServiceWorkers() {
    if (!('serviceWorker' in navigator)) return Promise.resolve();
    return navigator.serviceWorker.getRegistrations().then(function (regs) {
      return Promise.all(regs.map(function (r) {
        return isFlutterServiceWorker(r) ? r.unregister() : Promise.resolve();
      }));
    });
  }

  function clearFlutterCaches() {
    if (!('caches' in window)) return Promise.resolve();
    return caches.keys().then(function (keys) {
      return Promise.all(keys.map(function (key) {
        // Solo caches del SW de Flutter (nombres típicos flutter-*).
        if (key.indexOf('flutter') !== -1) {
          return caches.delete(key);
        }
        return Promise.resolve();
      }));
    }).catch(function () {});
  }

  window.profioIsPushServiceWorkerActive = function () {
    try {
      return localStorage.getItem(PUSH_SW_KEY) === '1';
    } catch (_) {
      return false;
    }
  };

  window.profioSetPushServiceWorkerActive = function (active) {
    try {
      if (active) localStorage.setItem(PUSH_SW_KEY, '1');
      else localStorage.removeItem(PUSH_SW_KEY);
    } catch (_) {}
  };

  window.profioUnregisterFirebaseMessagingSw = function () {
    window.__profioFcmSwRegistered = false;
    window.profioSetPushServiceWorkerActive(false);
    if (!('serviceWorker' in navigator)) return Promise.resolve();
    return navigator.serviceWorker.getRegistrations().then(function (regs) {
      return Promise.all(regs.map(function (r) {
        return isFirebaseMessagingSw(r) ? r.unregister() : Promise.resolve();
      }));
    });
  };

  window.profioRegisterFirebaseMessagingSw = function () {
    if (!('serviceWorker' in navigator)) return Promise.resolve();
    if (window.__profioFcmSwRegistered) return Promise.resolve();

    // No hacer unregisterAll: en iOS PWA eso rompe el arranque.
    // Solo quitar SW de Flutter y registrar (o reutilizar) el de FCM.
    return unregisterFlutterServiceWorkers().then(function () {
      return navigator.serviceWorker.getRegistration('/');
    }).then(function (existing) {
      if (existing && isFirebaseMessagingSw(existing) && existing.active) {
        window.__profioFcmSwRegistered = true;
        window.profioSetPushServiceWorkerActive(true);
        return existing;
      }
      return navigator.serviceWorker.register('firebase-messaging-sw.js', {
        scope: '/',
      });
    }).then(function (reg) {
      window.__profioFcmSwRegistered = true;
      window.profioSetPushServiceWorkerActive(true);
      return reg;
    }).catch(function (err) {
      console.warn('[FCM] No se pudo registrar firebase-messaging-sw.js', err);
    });
  };

  function installIosPwaTouchWorkaround() {
    if (!isIos() || !isStandalonePwa()) return;

    document.documentElement.classList.add('profio-ios-pwa');

    var resetViewportScroll = function () {
      requestAnimationFrame(function () {
        try {
          window.scrollTo(0, 0);
          document.documentElement.scrollTop = 0;
          document.body.scrollTop = 0;
        } catch (_) {}
      });
    };

    window.profioResetIosViewport = resetViewportScroll;
    resetViewportScroll();
    window.addEventListener('pageshow', resetViewportScroll);
    window.addEventListener('orientationchange', resetViewportScroll);
    window.addEventListener('flutter-first-frame', resetViewportScroll);
  }

  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.addEventListener('message', function (event) {
      if (event.data && event.data.type === 'NOTIFICATION_CLICK' && event.data.url) {
        window.location.href = event.data.url;
      }
    });
  }

  // Arranque idéntico en browser y standalone: nunca bloquear Flutter.
  window.__profioBootReady = Promise.resolve();

  installIosPwaTouchWorkaround();

  // Limpieza de SW/caches de Flutter DESPUÉS del primer frame (no al boot).
  // Evita races que dejan el icono de inicio en splash/blanco.
  function cleanupFlutterSwAfterBoot() {
    Promise.all([
      unregisterFlutterServiceWorkers(),
      clearFlutterCaches(),
    ]).catch(function () {});
  }

  window.addEventListener('flutter-first-frame', cleanupFlutterSwAfterBoot, {
    once: true,
  });
  // Por si first-frame no llega (icono viejo / caché rota).
  setTimeout(cleanupFlutterSwAfterBoot, 8000);
})();
