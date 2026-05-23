$(function () {
  if (!SA.requireAuth()) return;

  let currentMessage = null;

  function loadShareLink() {
    SA.api.get('/profile/link')
      .then(res => {
        $('#share-link').text(res.url).attr('href', res.url);
      })
      .catch(() => {});
  }

  function loadInbox() {
    SA.api.get('/messages/inbox?limit=50')
      .then(res => {
        const $list = $('#inbox-list').empty();
        $('#inbox-count').text(
          res.unreadCount > 0 ? `· ${res.unreadCount} unread` : ''
        );
        if (!res.items.length) {
          $list.html(`
            <div class="empty-state">
              <p>No notes yet.</p>
              <p class="muted" style="margin-top:8px">Share your link to start receiving messages from your secret admirers.</p>
            </div>
          `);
          return;
        }
        for (const m of res.items) {
          const $item = $(`
            <div class="inbox-item ${m.read ? '' : 'unread'}" data-id="${m.id}">
              <div class="avatar">?</div>
              <div class="preview">
                <div>${SA.escape(m.body.slice(0, 80))}${m.body.length > 80 ? '…' : ''}</div>
                <div class="time">${SA.relativeTime(m.receivedAt)}</div>
              </div>
            </div>
          `);
          $item.on('click', () => openMessage(m.id));
          $list.append($item);
        }
      })
      .catch(err => {
        $('#inbox-list').html(`<div class="empty-state">Couldn't load messages: ${SA.escape(err.message)}</div>`);
      });
  }

  function openMessage(id) {
    SA.api.get('/messages/' + id)
      .then(m => {
        currentMessage = m;
        $('#modal-body').text(m.body);
        $('#modal-time').text(SA.relativeTime(m.receivedAt));
        $('#message-modal').attr('hidden', false);
        // Mark the item read in the list optimistically.
        $(`.inbox-item[data-id="${id}"]`).removeClass('unread');
      })
      .catch(err => SA.toast(err.message || 'Could not open message', 'error'));
  }

  $('#modal-close').on('click', () => $('#message-modal').attr('hidden', true));
  $('#modal-delete').on('click', () => {
    if (!currentMessage) return;
    SA.api.del('/messages/' + currentMessage.id)
      .then(() => {
        $('#message-modal').attr('hidden', true);
        SA.toast('Deleted', 'success');
        loadInbox();
      })
      .catch(err => SA.toast(err.message || 'Could not delete', 'error'));
  });

  $('#copy-link').on('click', async () => {
    const url = $('#share-link').text();
    try {
      await navigator.clipboard.writeText(url);
      SA.toast('Link copied', 'success');
    } catch {
      SA.toast('Copy failed — long-press the link instead');
    }
  });

  $('#share-link-btn').on('click', () => {
    const url = $('#share-link').text();
    if (navigator.share) {
      navigator.share({ title: 'Send me a secret note', url }).catch(() => {});
    } else {
      window.open(url, '_blank');
    }
  });

  $('#logout').on('click', function (e) {
    e.preventDefault();
    SA.api.post('/auth/logout', { refreshToken: SA.storage.refresh })
      .catch(() => {})
      .always(() => { SA.storage.clear(); location.href = 'index.html'; });
  });

  loadShareLink();
  loadInbox();
});
