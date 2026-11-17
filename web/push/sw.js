self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

self.addEventListener('push', (event) => {
  let data = {};
  try {
    data = event.data ? event.data.json() : {};
  } catch (_) {
    data = { title: event.data ? event.data.text() : 'School' };
  }

  event.waitUntil(
    self.registration.showNotification(data.title || 'School', {
      body: data.body || '',
      icon: '../icons/Icon-192.png',
      badge: '../icons/Icon-192.png',
      data: { route: data.route || '/home' },
    }),
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const url = new URL('../#' + event.notification.data.route, self.location.href).href;

  event.waitUntil(
    (async () => {
      const tabs = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
      for (const tab of tabs) {
        if (new URL(tab.url).origin === self.location.origin) {
          await tab.focus();
          return tab.navigate(url);
        }
      }
      return self.clients.openWindow(url);
    })(),
  );
});
