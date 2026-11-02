// Service worker da Bíblia Local: guarda o app inteiro (incl. o banco de textos) para abrir offline.
// Os marcadores de versão e de lista de arquivos abaixo são trocados por tools/build_web.py a cada build.
const VERSION = '__VERSION__';
const FILES = __FILES__;
const CACHE = 'biblia-' + VERSION;

self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE);
    for (const f of FILES) {
      const res = await fetch(f, { cache: 'reload' });
      // sessão expirada: o servidor devolve a página de login (redirect); não guardar isso como se fosse o arquivo
      if (!res.ok || res.redirected) throw new Error('falha ao baixar ' + f);
      await cache.put(f, res);
    }
  })());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    for (const k of await caches.keys()) {
      if (k.startsWith('biblia-') && k !== CACHE) await caches.delete(k);
    }
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.origin !== location.origin) return;
  event.respondWith((async () => {
    const cache = await caches.open(CACHE);
    const hit = (await cache.match(req, { ignoreSearch: true })) ||
      (req.mode === 'navigate' ? await cache.match('index.html') : undefined);
    if (hit) return hit;
    try {
      return await fetch(req);
    } catch (e) {
      return new Response('Sem conexão.', { status: 503 });
    }
  })());
});
