// ── Firebase Messaging Service Worker ────────────────────────────────────────
// Agrupa mensajes por conversación (estilo WhatsApp): una sola notificación
// expandible con todos los mensajes en orden.

importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey:            'AIzaSyCzizij9NpyiGx-RMz2ePzMXMfdOWMNItI',
  authDomain:        'housechekk.firebaseapp.com',
  projectId:         'housechekk',
  storageBucket:     'housechekk.firebasestorage.app',
  messagingSenderId: '943466556049',
  appId:             '1:943466556049:web:fadb7ae717932bd0b76d30',
});

const messaging = firebase.messaging();

// Necesario para que Chrome considere la PWA instalable.
self.addEventListener('install', function (event) {
  self.skipWaiting();
});

self.addEventListener('activate', function (event) {
  event.waitUntil(self.clients.claim());
});

const DB_NAME = 'profio-push';
const STORE_NAME = 'conversation_messages';
const MAX_LINES = 7;

function buildChatUrl(data) {
  const professionalId = data.professional_id;
  if (!professionalId) return self.location.origin + '/messages';

  const params = new URLSearchParams();
  if (data.conversation_id) params.set('conversationId', data.conversation_id);
  if (data.sender_name) params.set('name', data.sender_name);
  const qs = params.toString();
  return `${self.location.origin}/messages/${professionalId}${qs ? '?' + qs : ''}`;
}

function openDb() {
  return new Promise(function (resolve, reject) {
    const req = indexedDB.open(DB_NAME, 1);
    req.onupgradeneeded = function () {
      req.result.createObjectStore(STORE_NAME);
    };
    req.onsuccess = function () { resolve(req.result); };
    req.onerror = function () { reject(req.error); };
  });
}

function getStoredMessages(conversationId) {
  return openDb().then(function (db) {
    return new Promise(function (resolve, reject) {
      const tx = db.transaction(STORE_NAME, 'readonly');
      const req = tx.objectStore(STORE_NAME).get(conversationId);
      req.onsuccess = function () { resolve(req.result || []); };
      req.onerror = function () { reject(req.error); };
    });
  });
}

function saveMessages(conversationId, messages) {
  return openDb().then(function (db) {
    return new Promise(function (resolve, reject) {
      const tx = db.transaction(STORE_NAME, 'readwrite');
      tx.objectStore(STORE_NAME).put(messages, conversationId);
      tx.oncomplete = function () { resolve(messages); };
      tx.onerror = function () { reject(tx.error); };
    });
  });
}

function clearMessages(conversationId) {
  return openDb().then(function (db) {
    return new Promise(function (resolve, reject) {
      const tx = db.transaction(STORE_NAME, 'readwrite');
      tx.objectStore(STORE_NAME).delete(conversationId);
      tx.oncomplete = function () { resolve(); };
      tx.onerror = function () { reject(tx.error); };
    });
  });
}

function appendMessage(conversationId, line, timestamp) {
  return getStoredMessages(conversationId).then(function (existing) {
    var messages = existing.slice();
    messages.push({ body: line, ts: timestamp || Date.now() });
    messages.sort(function (a, b) { return a.ts - b.ts; });
    if (messages.length > MAX_LINES) {
      messages = messages.slice(messages.length - MAX_LINES);
    }
    return saveMessages(conversationId, messages);
  });
}

function showGroupedNotification(data, messages) {
  var senderName = data.sender_name || 'Nuevo mensaje';
  var count = messages.length;
  var title = count > 1
    ? senderName + ' (' + count + ' mensajes)'
    : senderName;
  var body = messages.map(function (m) { return m.body; }).join('\n');
  var convId = data.conversation_id;

  return self.registration.showNotification(title, {
    body: body,
    icon: '/favicon.png',
    badge: '/favicon.png',
    tag: 'chat-' + convId,
    renotify: true,
    data: data,
    requireInteraction: false,
  });
}

// Solo data (sin webpush.notification) → una única notificación agrupada aquí.
messaging.onBackgroundMessage(function (payload) {
  console.log('[SW] Push en background:', payload);

  var data = payload.data || {};
  var convId = data.conversation_id;
  if (!convId) return Promise.resolve();

  var line = data.body || payload.notification?.body || 'Nuevo mensaje';
  var ts = parseInt(data.timestamp, 10) || Date.now();

  return appendMessage(convId, line, ts).then(function (messages) {
    return showGroupedNotification(data, messages);
  });
});

// Clic en la notificación → abre el chat y limpia el grupo.
self.addEventListener('notificationclick', function (event) {
  event.notification.close();
  var data = event.notification.data || {};
  var convId = data.conversation_id;
  var url = buildChatUrl(data);

  event.waitUntil(
    Promise.resolve().then(function () {
      if (convId) return clearMessages(convId);
    }).then(function () {
      return clients.matchAll({ type: 'window', includeUncontrolled: true });
    }).then(function (clientList) {
      for (var i = 0; i < clientList.length; i++) {
        var client = clientList[i];
        if (client.url.startsWith(self.location.origin) && 'focus' in client) {
          client.focus();
          if ('navigate' in client) {
            return client.navigate(url);
          }
          client.postMessage({ type: 'NOTIFICATION_CLICK', url: url });
          return;
        }
      }
      if (clients.openWindow) return clients.openWindow(url);
    })
  );
});

// Limpiar mensajes agrupados cuando el usuario lee el chat en la app.
self.addEventListener('message', function (event) {
  if (!event.data || event.data.type !== 'CLEAR_CHAT_NOTIFICATIONS') return;
  var convId = event.data.conversationId;
  if (!convId) return;

  var tag = 'chat-' + convId;

  event.waitUntil(
    clearMessages(convId).then(function () {
      return self.registration.getNotifications();
    }).then(function (list) {
      list.forEach(function (n) {
        if (n.tag === tag || (n.data && n.data.conversation_id === convId)) {
          n.close();
        }
      });
    })
  );
});
