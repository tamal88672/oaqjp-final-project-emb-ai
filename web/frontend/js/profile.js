$(function () {
  if (!SA.requireAuth()) return;

  function renderAvatar(profile) {
    const $a = $('#avatar-large').empty();
    if (profile.avatarUrl) {
      $a.append($('<img>').attr('src', profile.avatarUrl).attr('alt', profile.handle));
    } else {
      $a.text(SA.initial(profile.displayName || profile.handle));
    }
  }

  function loadProfile() {
    SA.api.get('/profile/me')
      .then(p => {
        $('#profile-handle').val(p.handle);
        $('#profile-display-name').val(p.displayName || '');
        $('#profile-bio').val(p.bio || '');
        $('#profile-theme').val(p.theme || 'velvet');
        $('#profile-allow-replies').prop('checked', !!p.allowReplies);
        renderAvatar(p);
      })
      .catch(err => SA.toast(err.message || 'Could not load profile', 'error'));
  }

  function loadSessions() {
    SA.api.get('/auth/sessions')
      .then(list => {
        const $list = $('#sessions-list').empty();
        if (!list.length) {
          $list.html('<div class="muted">No active sessions.</div>');
          return;
        }
        for (const s of list) {
          const $row = $(`
            <div class="row" style="padding: 10px 0; border-bottom: 1px solid rgba(183,110,121,0.15);">
              <div style="flex:1;">
                <div>${SA.escape((s.device || '').slice(0, 50)) || 'Unknown device'}</div>
                <div class="muted" style="font-size:0.8rem">Last seen ${SA.relativeTime(s.lastSeen)}${s.ip ? ' · ' + SA.escape(s.ip) : ''}</div>
              </div>
              <button class="btn btn-ghost" data-id="${s.id}" style="width:auto; padding: 8px 14px;">Revoke</button>
            </div>
          `);
          $row.find('button').on('click', function () {
            const id = $(this).data('id');
            SA.api.del('/auth/sessions/' + id)
              .then(() => { SA.toast('Session revoked', 'success'); loadSessions(); })
              .catch(err => SA.toast(err.message || 'Could not revoke', 'error'));
          });
          $list.append($row);
        }
      })
      .catch(err => $('#sessions-list').text(err.message || 'Could not load sessions'));
  }

  $('#profile-form').on('submit', function (e) {
    e.preventDefault();
    $('#profile-success').attr('hidden', true);
    $('#profile-error').attr('hidden', true);
    const $btn = $(this).find('button[type="submit"]');
    $btn.prop('disabled', true).html('<span class="spinner"></span>');
    SA.api.patch('/profile', {
      displayName: $('#profile-display-name').val().trim(),
      bio:         $('#profile-bio').val().trim(),
      theme:       $('#profile-theme').val(),
      allowReplies: $('#profile-allow-replies').is(':checked')
    })
      .then(p => {
        renderAvatar(p);
        $('#profile-success').attr('hidden', false);
      })
      .catch(err => {
        $('#profile-error').text(err.message || 'Could not save').attr('hidden', false);
      })
      .always(() => $btn.prop('disabled', false).text('Save profile'));
  });

  $('#avatar-input').on('change', function () {
    const file = this.files && this.files[0];
    if (!file) return;
    if (file.size > 5 * 1024 * 1024) {
      SA.toast('Image too large (max 5MB)', 'error'); return;
    }
    const fd = new FormData();
    fd.append('avatar', file);
    SA.api.put('/profile/avatar', fd, { raw: true })
      .then(res => {
        renderAvatar({ avatarUrl: res.avatarUrl });
        SA.toast('Photo updated', 'success');
      })
      .catch(err => SA.toast(err.message || 'Could not upload', 'error'));
  });

  $('#logout-everywhere').on('click', function () {
    if (!confirm('Sign out of every device, including this one?')) return;
    SA.api.get('/auth/sessions')
      .then(async list => {
        for (const s of list) {
          try { await SA.api.del('/auth/sessions/' + s.id); } catch (_) {}
        }
        SA.storage.clear();
        location.href = 'index.html';
      });
  });

  $('#logout').on('click', function (e) {
    e.preventDefault();
    SA.api.post('/auth/logout', { refreshToken: SA.storage.refresh })
      .catch(() => {})
      .always(() => { SA.storage.clear(); location.href = 'index.html'; });
  });

  loadProfile();
  loadSessions();
});
