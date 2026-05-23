// Thin wrapper around jQuery.ajax that adds the bearer token, retries refresh,
// and normalizes the error shape.

window.SA = window.SA || {};

SA.config = {
  apiBase: (window.SECRET_ADMIRER_API_BASE || 'http://localhost:8080')
};

SA.storage = {
  get access() { return localStorage.getItem('sa.access'); },
  set access(v) { v == null ? localStorage.removeItem('sa.access') : localStorage.setItem('sa.access', v); },
  get refresh() { return localStorage.getItem('sa.refresh'); },
  set refresh(v) { v == null ? localStorage.removeItem('sa.refresh') : localStorage.setItem('sa.refresh', v); },
  get user() { try { return JSON.parse(localStorage.getItem('sa.user') || 'null'); } catch { return null; } },
  set user(v) { v == null ? localStorage.removeItem('sa.user') : localStorage.setItem('sa.user', JSON.stringify(v)); },
  clear() { ['sa.access', 'sa.refresh', 'sa.user'].forEach(k => localStorage.removeItem(k)); }
};

SA.api = (function () {
  let refreshing = null;

  function request(method, path, { body, auth = true, raw = false, headers = {} } = {}) {
    const opts = {
      url: SA.config.apiBase + path,
      method,
      contentType: raw ? false : 'application/json',
      processData: !raw,
      data: raw ? body : (body !== undefined ? JSON.stringify(body) : undefined),
      dataType: 'json',
      headers: { ...headers }
    };
    if (auth && SA.storage.access) {
      opts.headers['Authorization'] = 'Bearer ' + SA.storage.access;
    }
    return $.ajax(opts).then(
      (data) => data,
      async (xhr) => {
        if (xhr.status === 401 && auth && SA.storage.refresh) {
          // Coalesce concurrent refreshes into a single request.
          refreshing = refreshing || refresh();
          try {
            await refreshing;
          } finally {
            refreshing = null;
          }
          opts.headers['Authorization'] = 'Bearer ' + SA.storage.access;
          return $.ajax(opts);
        }
        const err = (xhr.responseJSON && xhr.responseJSON.error) || { code: 'unknown', message: xhr.statusText };
        return Promise.reject(err);
      }
    );
  }

  async function refresh() {
    try {
      const res = await $.ajax({
        url: SA.config.apiBase + '/auth/refresh',
        method: 'POST',
        contentType: 'application/json',
        data: JSON.stringify({ refreshToken: SA.storage.refresh })
      });
      SA.storage.access = res.accessToken;
      SA.storage.refresh = res.refreshToken;
    } catch (e) {
      SA.storage.clear();
      if (location.pathname !== '/' && !location.pathname.endsWith('index.html')) {
        location.href = 'index.html';
      }
      throw e;
    }
  }

  return {
    get: (path, opts) => request('GET', path, opts),
    post: (path, body, opts) => request('POST', path, { ...(opts || {}), body }),
    patch: (path, body, opts) => request('PATCH', path, { ...(opts || {}), body }),
    put: (path, body, opts) => request('PUT', path, { ...(opts || {}), body }),
    del: (path, opts) => request('DELETE', path, opts)
  };
})();

SA.toast = function (msg, kind) {
  const $t = $('<div class="toast"></div>').addClass(kind || '').text(msg).appendTo(document.body);
  setTimeout(() => $t.fadeOut(250, function () { $(this).remove(); }), 3000);
};

SA.requireAuth = function () {
  if (!SA.storage.access) {
    location.href = 'index.html';
    return false;
  }
  return true;
};

SA.relativeTime = function (iso) {
  const then = new Date(iso).getTime();
  const now = Date.now();
  const diff = Math.max(0, now - then) / 1000;
  if (diff < 60) return 'just now';
  if (diff < 3600) return Math.floor(diff / 60) + 'm ago';
  if (diff < 86400) return Math.floor(diff / 3600) + 'h ago';
  return Math.floor(diff / 86400) + 'd ago';
};

SA.escape = function (s) {
  return String(s == null ? '' : s)
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
};

SA.initial = function (s) {
  return (s || '?').trim().charAt(0).toUpperCase();
};
