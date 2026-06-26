// ── Firebase Messaging Service Worker ────────────────────────────────────────
// Este archivo DEBE estar en /web y llamarse exactamente firebase-messaging-sw.js
//
// ⚠️  Reemplaza los valores de firebaseConfig con los de tu proyecto Firebase:
//     Firebase Console → Project settings → Your apps → Web app → SDK setup
//
// ⚠️  Reemplaza VAPID_KEY_HERE con tu Web Push Certificate (VAPID key):
//     Firebase Console → Project settings → Cloud Messaging → Web Push certificates

importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey:            "AIzaSyCzizij9NpyiGx-RMz2ePzMXMfdOWMNItI",
  authDomain:        "housechekk.firebaseapp.com",
  projectId:         "housechekk",
  storageBucket:     "housechekk.firebasestorage.app",
  messagingSenderId: "943466556049",
  appId:             "1:943466556049:web:fadb7ae717932bd0b76d30",
});

const messaging = firebase.messaging();

// ── Notificaciones en background (navegador cerrado / en otra pestaña) ────────
messaging.onBackgroundMessage((payload) => {
  console.log('[SW] Mensaje en background recibido:', payload);

  const { title, body, icon } = payload.notification ?? {};
  const conversationId = payload.data?.conversation_id;

  self.registration.showNotification(title ?? 'Nuevo mensaje', {
    body:  body  ?? '',
    icon:  icon  ?? '/favicon.png',
    badge: '/favicon.png',
    tag:   conversationId ?? 'profio-msg',
    data:  { conversation_id: conversationId },
    actions: [
      { action: 'open', title: 'Ver mensaje' },
    ],
  });
});

// ── Clic en la notificación → abre/enfoca la app ─────────────────────────────
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const conversationId = event.notification.data?.conversation_id;
  const url = conversationId
      ? `${self.location.origin}/messages/${conversationId}`
      : self.location.origin;

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if (client.url.startsWith(self.location.origin) && 'focus' in client) {
          client.focus();
          client.navigate(url);
          return;
        }
      }
      if (clients.openWindow) return clients.openWindow(url);
    })
  );
});
