{{flutter_js}}
{{flutter_build_config}}

// Sin serviceWorkerSettings: no registrar flutter_service_worker.js.
// Ese SW cacheaba main.dart.js y en iOS PWA (icono de inicio) dejaba
// splash/pantalla en blanco tras updates. Push usa firebase-messaging-sw.js.
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: 'canvaskit/',
  },
});
