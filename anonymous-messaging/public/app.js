const state = {
  rooms: [],
  activeRoomId: null,
  lastMessageCount: 0,
  liked: new Set(),
};

const POLL_INTERVAL = 4000;
let pollTimer = null;

const els = {
  roomList: document.getElementById('roomList'),
  newRoomBtn: document.getElementById('newRoomBtn'),
  newRoomForm: document.getElementById('newRoomForm'),
  cancelRoomBtn: document.getElementById('cancelRoomBtn'),
  roomName: document.getElementById('roomName'),
  roomDesc: document.getElementById('roomDesc'),
  roomError: document.getElementById('roomError'),
  activeRoomName: document.getElementById('activeRoomName'),
  activeRoomDesc: document.getElementById('activeRoomDesc'),
  messages: document.getElementById('messages'),
  composerInput: document.getElementById('composerInput'),
  sendBtn: document.getElementById('sendBtn'),
  charCounter: document.getElementById('charCounter'),
  menuToggle: document.getElementById('menuToggle'),
  sidebar: document.getElementById('sidebar'),
};

function escapeHtml(str) {
  const div = document.createElement('div');
  div.textContent = str;
  return div.innerHTML;
}

function timeAgo(iso) {
  const then = new Date(iso.includes('Z') || iso.includes('T') ? iso : iso.replace(' ', 'T') + 'Z');
  const seconds = Math.floor((Date.now() - then.getTime()) / 1000);
  if (Number.isNaN(seconds)) return '';
  if (seconds < 5) return 'just now';
  if (seconds < 60) return `${seconds}s ago`;
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  if (days < 7) return `${days}d ago`;
  return then.toLocaleDateString();
}

function initials(alias) {
  if (!alias) return '?';
  return alias
    .split(' ')
    .map((w) => w[0])
    .join('')
    .slice(0, 2)
    .toUpperCase();
}

async function api(path, options) {
  const res = await fetch(path, {
    headers: { 'Content-Type': 'application/json' },
    ...options,
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error(data.error || `Request failed (${res.status})`);
  }
  return data;
}

async function loadRooms() {
  state.rooms = await api('/api/rooms');
  renderRooms();
}

function renderRooms() {
  els.roomList.innerHTML = '';
  for (const room of state.rooms) {
    const item = document.createElement('div');
    item.className = 'room-item' + (room.id === state.activeRoomId ? ' active' : '');
    item.dataset.id = room.id;

    const left = document.createElement('div');
    left.style.minWidth = '0';

    const name = document.createElement('div');
    name.className = 'room-name';
    name.textContent = room.name;
    left.appendChild(name);

    if (room.description) {
      const desc = document.createElement('div');
      desc.className = 'room-item-desc';
      desc.textContent = room.description;
      left.appendChild(desc);
    }

    const count = document.createElement('span');
    count.className = 'room-count';
    count.textContent = room.message_count;

    item.append(left, count);
    item.addEventListener('click', () => selectRoom(room.id));
    els.roomList.appendChild(item);
  }
}

function selectRoom(roomId) {
  state.activeRoomId = roomId;
  state.lastMessageCount = 0;
  const room = state.rooms.find((r) => r.id === roomId);

  els.activeRoomName.textContent = room ? room.name : 'Room';
  els.activeRoomDesc.textContent = room ? room.description || '' : '';
  els.composerInput.disabled = false;
  els.sendBtn.disabled = els.composerInput.value.trim().length === 0;
  els.sidebar.classList.remove('open');

  renderRooms();
  loadMessages(true);
  startPolling();
}

async function loadMessages(forceScroll = false) {
  if (!state.activeRoomId) return;
  try {
    const messages = await api(`/api/rooms/${state.activeRoomId}/messages`);
    const hasNew = messages.length !== state.lastMessageCount;
    state.lastMessageCount = messages.length;
    renderMessages(messages, forceScroll || hasNew);
  } catch (err) {
    console.error('Failed to load messages:', err);
  }
}

function renderMessages(messages, scroll) {
  if (messages.length === 0) {
    els.messages.innerHTML =
      '<p class="empty-state">No whispers yet. Be the first to break the silence.</p>';
    return;
  }

  const nearBottom =
    els.messages.scrollHeight - els.messages.scrollTop - els.messages.clientHeight < 120;

  els.messages.innerHTML = '';
  for (const msg of messages) {
    els.messages.appendChild(buildMessage(msg));
  }

  if (scroll || nearBottom) {
    els.messages.scrollTop = els.messages.scrollHeight;
  }
}

function buildMessage(msg) {
  const wrap = document.createElement('div');
  wrap.className = 'message';

  const avatar = document.createElement('div');
  avatar.className = 'avatar';
  avatar.style.background = msg.color || '#8b5cf6';
  avatar.textContent = initials(msg.alias);

  const bubble = document.createElement('div');
  bubble.className = 'bubble';

  const head = document.createElement('div');
  head.className = 'bubble-head';

  const alias = document.createElement('span');
  alias.className = 'bubble-alias';
  alias.textContent = msg.alias || 'Anonymous';

  const time = document.createElement('span');
  time.className = 'bubble-time';
  time.textContent = timeAgo(msg.created_at);

  head.append(alias, time);

  const text = document.createElement('div');
  text.className = 'bubble-text';
  text.textContent = msg.content;

  const likeBtn = document.createElement('button');
  likeBtn.className = 'like-btn' + (state.liked.has(msg.id) ? ' liked' : '');
  likeBtn.innerHTML = `<span>♥</span> <span class="like-count">${msg.likes}</span>`;
  likeBtn.addEventListener('click', () => likeMessage(msg.id, likeBtn));

  bubble.append(head, text, likeBtn);
  wrap.append(avatar, bubble);
  return wrap;
}

async function likeMessage(id, btn) {
  try {
    const { likes } = await api(`/api/messages/${id}/like`, { method: 'POST' });
    state.liked.add(id);
    btn.classList.add('liked');
    const counter = btn.querySelector('.like-count');
    if (counter) counter.textContent = likes;
  } catch (err) {
    console.error('Failed to like message:', err);
  }
}

async function sendMessage() {
  const content = els.composerInput.value.trim();
  if (!content || !state.activeRoomId) return;

  els.sendBtn.disabled = true;
  try {
    await api(`/api/rooms/${state.activeRoomId}/messages`, {
      method: 'POST',
      body: JSON.stringify({ content }),
    });
    els.composerInput.value = '';
    updateCharCounter();
    autoGrow();
    await loadMessages(true);
    await loadRooms();
  } catch (err) {
    alert(err.message);
  } finally {
    els.sendBtn.disabled = els.composerInput.value.trim().length === 0;
  }
}

function updateCharCounter() {
  const len = els.composerInput.value.length;
  els.charCounter.textContent = `${len} / 1000`;
  els.charCounter.classList.toggle('warn', len > 950);
  els.sendBtn.disabled = els.composerInput.value.trim().length === 0 || !state.activeRoomId;
}

function autoGrow() {
  els.composerInput.style.height = 'auto';
  els.composerInput.style.height = Math.min(els.composerInput.scrollHeight, 160) + 'px';
}

function startPolling() {
  stopPolling();
  pollTimer = setInterval(() => loadMessages(false), POLL_INTERVAL);
}

function stopPolling() {
  if (pollTimer) clearInterval(pollTimer);
  pollTimer = null;
}

async function createRoom(event) {
  event.preventDefault();
  els.roomError.textContent = '';
  const name = els.roomName.value.trim();
  const description = els.roomDesc.value.trim();
  if (!name) {
    els.roomError.textContent = 'Room name is required.';
    return;
  }
  try {
    const room = await api('/api/rooms', {
      method: 'POST',
      body: JSON.stringify({ name, description }),
    });
    els.roomName.value = '';
    els.roomDesc.value = '';
    els.newRoomForm.classList.add('hidden');
    els.newRoomBtn.classList.remove('hidden');
    await loadRooms();
    selectRoom(room.id);
  } catch (err) {
    els.roomError.textContent = err.message;
  }
}

function wireEvents() {
  els.newRoomBtn.addEventListener('click', () => {
    els.newRoomForm.classList.remove('hidden');
    els.newRoomBtn.classList.add('hidden');
    els.roomName.focus();
  });

  els.cancelRoomBtn.addEventListener('click', () => {
    els.newRoomForm.classList.add('hidden');
    els.newRoomBtn.classList.remove('hidden');
    els.roomError.textContent = '';
  });

  els.newRoomForm.addEventListener('submit', createRoom);

  els.composerInput.addEventListener('input', () => {
    updateCharCounter();
    autoGrow();
  });

  els.composerInput.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      sendMessage();
    }
  });

  els.sendBtn.addEventListener('click', sendMessage);

  els.menuToggle.addEventListener('click', () => {
    els.sidebar.classList.toggle('open');
  });
}

async function init() {
  wireEvents();
  await loadRooms();
  if (state.rooms.length > 0) {
    selectRoom(state.rooms[0].id);
  }
}

init();
