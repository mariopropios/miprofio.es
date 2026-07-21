// ── Firebase Messaging Service Worker ────────────────────────────────────────
// Agrupa mensajes por conversación (estilo WhatsApp): una sola notificación
// expandible con todos los mensajes en orden.
// v2026-07-22: clic push → solo miprofio.es; skipWaiting en Android

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

function isIosUa() {
  try {
    return /iphone|ipad|ipod/i.test(self.navigator.userAgent || '');
  } catch (e) {
    return false;
  }
}

// Android/Chrome: activar SW nuevo ya (links canónicos miprofio.es).
// iOS: sin skipWaiting (rompe toques en PWA).
self.addEventListener('install', function (event) {
  if (!isIosUa()) {
    self.skipWaiting();
  }
});

self.addEventListener('activate', function (event) {
  if (!isIosUa()) {
    event.waitUntil(self.clients.claim());
  } else {
    event.waitUntil(Promise.resolve());
  }
});

const DB_NAME = 'profio-push';
const STORE_NAME = 'conversation_messages';
const MAX_LINES = 7;

const CANONICAL_ORIGIN = 'https://miprofio.es';

function buildChatUrl(data) {
  // Preferir link absoluto del payload FCM si ya es miprofio.es.
  if (data && typeof data.link === 'string' && data.link.indexOf('https://miprofio.es') === 0) {
    return data.link;
  }

  const professionalId = data.professional_id;
  const origin = CANONICAL_ORIGIN;
  if (!professionalId) return origin + '/messages';

  const params = new URLSearchParams();
  if (data.conversation_id) params.set('conversationId', data.conversation_id);
  if (data.sender_name) params.set('name', data.sender_name);
  if (data.as_prof === '1' || data.as_prof === 'true' || data.asProf === '1') {
    params.set('asProf', '1');
  }
  if (data.peer_user_id) params.set('peerUserId', data.peer_user_id);
  const qs = params.toString();
  return origin + '/go?to=' + encodeURIComponent(
    '/messages/' + professionalId + (qs ? '?' + qs : '')
  );
}

function isOurClientUrl(url) {
  try {
    var u = new URL(url);
    return u.hostname === 'miprofio.es' ||
      u.hostname === 'www.miprofio.es' ||
      u.hostname === 'profio-web.mariopropiosplaza.workers.dev';
  } catch (e) {
    return false;
  }
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
  // Incluir message_id en el tag fuerza aviso/sonido en cada mensaje en Android
  // (mismo tag sin cambio a veces no vuelve a sonar).
  var msgId = data.message_id || String(Date.now());
  var tag = 'chat-' + convId + '-' + msgId;

  return self.registration.showNotification(title, {
    body: body,
    icon: '/favicon.png',
    badge: '/favicon.png',
    tag: tag,
    renotify: true,
    silent: false,
    vibrate: [120, 60, 120],
    data: data,
    requireInteraction: false,
  }).then(function () {
    // Cerrar avisos viejos de la misma conversación (deja solo el último).
    return self.registration.getNotifications().then(function (list) {
      list.forEach(function (n) {
        if (!n.tag || n.tag === tag) return;
        if (n.tag.indexOf('chat-' + convId + '-') === 0) n.close();
      });
    });
  });
}

// Solo data (sin webpush.notification) → una única notificación agrupada aquí.
messaging.onBackgroundMessage(function (payload) {
  console.log('[SW] Push en background:', payload);

  // Si FCM ya trae notification, el sistema la muestra → no duplicar con SW.
  if (payload.notification) {
    return Promise.resolve();
  }

  var data = payload.data || {};
  var convId = data.conversation_id;
  if (!convId) return Promise.resolve();

  var line = data.body || 'Nuevo mensaje';
  var ts = parseInt(data.timestamp, 10) || Date.now();

  return appendMessage(convId, line, ts).then(function (messages) {
    return showGroupedNotification(data, messages);
  });
});

// Clic en la notificación → SIEMPRE abrir miprofio.es (nunca workers.dev).
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
        try {
          var host = new URL(client.url).hostname;
          if (host !== 'miprofio.es' && host !== 'www.miprofio.es') continue;
          if ('focus' in client) {
            client.focus();
            if ('navigate' in client) return client.navigate(url);
            client.postMessage({ type: 'NOTIFICATION_CLICK', url: url });
            return;
          }
        } catch (e) {}
      }
      // No reutilizar ventanas de workers.dev: abrir siempre el .es
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
