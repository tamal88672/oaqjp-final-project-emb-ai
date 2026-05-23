$(function () {
  // The recipient handle is either ?u=handle or the last path segment of /u/handle.
  const params = new URLSearchParams(location.search);
  let handle = params.get('u') || '';
  if (!handle) {
    const m = location.pathname.match(/\/u\/([a-z0-9_]{3,30})$/i);
    if (m) handle = m[1];
  }
  handle = (handle || '').toLowerCase();

  if (!handle) {
    $('#recipient-name').text('Hmm.');
    $('#recipient-bio').text('No recipient in the URL.');
    $('#send-form').remove();
    return;
  }

  function renderRecipient(p) {
    $('#recipient-name').text('@' + p.handle + (p.displayName ? ' · ' + p.displayName : ''));
    $('#recipient-bio').text(p.bio || '');
    const $a = $('#recipient-avatar').empty();
    if (p.avatarUrl) {
      $a.append($('<img>').attr('src', p.avatarUrl).attr('alt', p.handle));
    } else {
      $a.text(SA.initial(p.displayName || p.handle));
    }
    if (p.allowReplies === false) {
      $('#send-form').hide();
      $('#recipient-bio').after('<p class="muted center" style="margin-top:12px">This person isn\'t accepting messages right now.</p>');
    }
  }

  SA.api.get('/profile/by-handle/' + encodeURIComponent(handle), { auth: false })
    .then(renderRecipient)
    .catch(err => {
      $('#recipient-name').text('Not found');
      $('#recipient-bio').text(err.message || 'No one to deliver to.');
      $('#send-form').hide();
    });

  $('#send-body').on('input', function () {
    $('#char-count').text(String($(this).val().length));
  });

  $('#send-form').on('submit', function (e) {
    e.preventDefault();
    $('#send-error').attr('hidden', true);
    $('#send-success').attr('hidden', true);
    const body = $('#send-body').val().trim();
    if (!body) return;

    const $btn = $('#send-btn');
    $btn.prop('disabled', true).html('<span class="spinner"></span>');
    SA.api.post('/messages', { receiverHandle: handle, body }, { auth: false })
      .then(() => {
        $('#send-success').text('Note delivered — anonymously.').attr('hidden', false);
        $('#send-body').val('').trigger('input');
      })
      .catch(err => {
        if (err.code === 'message.rate_limit') {
          $('#send-error').text('You\'ve sent enough today — try again tomorrow.');
        } else {
          $('#send-error').text(err.message || 'Could not send');
        }
        $('#send-error').attr('hidden', false);
      })
      .always(() => $btn.prop('disabled', false).text('Send anonymously'));
  });
});
