$(function () {
  if (SA.storage.access) {
    // Already signed in — straight to inbox.
    location.href = 'inbox.html';
    return;
  }

  $('.tabs .tab').on('click', function () {
    const tab = $(this).data('tab');
    $('.tabs .tab').removeClass('active');
    $(this).addClass('active');
    $('.tab-panel').attr('hidden', true);
    $('#' + tab + '-form').attr('hidden', false);
  });

  function persist(res) {
    SA.storage.access = res.accessToken;
    SA.storage.refresh = res.refreshToken;
    SA.storage.user = { userId: res.userId, handle: res.handle };
  }

  $('#login-form').on('submit', function (e) {
    e.preventDefault();
    $('#login-error').attr('hidden', true);
    const $btn = $(this).find('button[type="submit"]');
    $btn.prop('disabled', true).html('<span class="spinner"></span>');
    SA.api.post('/auth/login', {
      identifier: $('#login-identifier').val().trim(),
      password:   $('#login-password').val()
    }, { auth: false })
      .then(res => { persist(res); location.href = 'inbox.html'; })
      .catch(err => {
        $('#login-error').text(err.message || 'Sign in failed').attr('hidden', false);
      })
      .always(() => $btn.prop('disabled', false).text('Sign in'));
  });

  $('#register-form').on('submit', function (e) {
    e.preventDefault();
    $('#register-error').attr('hidden', true);
    const $btn = $(this).find('button[type="submit"]');
    $btn.prop('disabled', true).html('<span class="spinner"></span>');
    SA.api.post('/auth/register', {
      handle:   $('#reg-handle').val().trim().toLowerCase(),
      email:    $('#reg-email').val().trim().toLowerCase(),
      password: $('#reg-password').val()
    }, { auth: false })
      .then(res => { persist(res); location.href = 'inbox.html'; })
      .catch(err => {
        $('#register-error').text(err.message || 'Could not create account').attr('hidden', false);
      })
      .always(() => $btn.prop('disabled', false).text('Create account'));
  });
});
