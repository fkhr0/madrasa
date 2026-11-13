// Shows the school's notifications on the phone, even when the app is closed,
// and opens the right page when one is tapped.

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
      // The app's page, e.g. "/bus" (the app uses #/ addresses).
      data: { route: data.route || '/home' },
    }),
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const url = new URL('../#' + event.notification.data.route, self.location.href).href;

  event.waitUntil(
    (async () => {
      // An open tab of the app: bring it forward on that page.
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
