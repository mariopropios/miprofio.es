(function () {
  'use strict';

  var PUSH_SW_KEY = 'profio_push_sw_active';

  function isStandalonePwa() {
    return window.matchMedia('(display-mode: standalone)').matches ||
      window.matchMedia('(display-mode: fullscreen)').matches ||
      window.navigator.standalone === true;
  }

  function isIos() {
    return /iphone|ipad|ipod/i.test(navigator.userAgent) ||
      (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  }

  window.__profioPwa = { isStandalone: isStandalonePwa(), isIos: isIos() };

  function unregisterAllServiceWorkers() {
    if (!('serviceWorker' in navigator)) return Promise.resolve();
    return navigator.serviceWorker.getRegistrations().then(function (regs) {
      return Promise.all(regs.map(function (r) { return r.unregister(); }));
    });
  }

  function clearAllCaches() {
    if (!('caches' in window)) return Promise.resolve();
    return caches.keys().then(function (keys) {
      return Promise.all(keys.map(function (k) { return caches.delete(k); }));
    });
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
    return unregisterAllServiceWorkers();
  };

  window.profioRegisterFirebaseMessagingSw = function () {
    if (!('serviceWorker' in navigator)) return Promise.resolve();
    if (window.__profioFcmSwRegistered) return Promise.resolve();

    return unregisterAllServiceWorkers().then(function () {
      return navigator.serviceWorker.register('firebase-messaging-sw.js', { scope: '/' });
    }).then(function (reg) {
      window.__profioFcmSwRegistered = true;
      window.profioSetPushServiceWorkerActive(true);
      return reg;
    }).catch(function (err) {
      console.warn('[FCM] No se pudo registrar firebase-messaging-sw.js', err);
    });
  };

  function prepareIosPwaRuntime() {
    if (!isIos() || !isStandalonePwa()) return Promise.resolve();
    window.__profioFcmSwRegistered = false;
    return unregisterAllServiceWorkers().then(clearAllCaches);
  }

  function installIosPwaTouchWorkaround() {
    if (!isIos() || !isStandalonePwa()) return;

    document.documentElement.classList.add('profio-ios-pwa');

    var resetViewportScroll = function () {
      requestAnimationFrame(function () {
        window.scrollTo(0, 0);
        document.documentElement.scrollTop = 0;
        document.body.scrollTop = 0;
      });
    };

    window.profioResetIosViewport = resetViewportScroll;

    var noop = function () {};
    window.addEventListener('touchstart', noop, { capture: true, passive: true });
    document.addEventListener('touchstart', noop, { capture: true, passive: true });

    resetViewportScroll();
    window.addEventListener('pageshow', resetViewportScroll);
    window.addEventListener('resize', resetViewportScroll);
    window.addEventListener('orientationchange', resetViewportScroll);
    window.addEventListener('focusout', resetViewportScroll, true);
    document.addEventListener('visibilitychange', function () {
      if (!document.hidden) resetViewportScroll();
    });
    if (window.visualViewport) {
      window.visualViewport.addEventListener('resize', resetViewportScroll);
    }
    window.addEventListener('flutter-first-frame', resetViewportScroll);
  }

  // iOS PWA: sin service worker de Flutter (evita estados rotos con caché).
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
        var iosStandalone = isIos() && isStandalonePwa();
        if (iosStandalone && options.serviceWorkerSettings) {
          delete options.serviceWorkerSettings;
        } else if (window.profioIsPushServiceWorkerActive() && options.serviceWorkerSettings) {
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

  if (isStandalonePwa() && isIos()) {
    window.__profioBootReady = prepareIosPwaRuntime().then(installIosPwaTouchWorkaround);
  } else {
    window.__profioBootReady = Promise.resolve();
    if (!isStandalonePwa() && 'caches' in window) {
      clearAllCaches();
    }
  }
})();
