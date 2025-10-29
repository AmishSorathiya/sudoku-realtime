// server.js
const express = require('express');
const http = require('http');
const cors = require('cors');
const { Server } = require('socket.io');

const PORT = process.env.PORT || 3000;

const app = express();
app.use(cors());
app.use(express.json());

app.get('/', (_req, res) => res.send('Sudoku server running'));
app.get('/health', (_req, res) => res.json({ ok: true }));

const httpServer = http.createServer(app);
const io = new Server(httpServer, {
  cors: { origin: '*', methods: ['GET', 'POST'] },
});

// ---------------- State ----------------
const rooms = new Map();   // roomId -> { players, puzzle, startAtMs, finished, ready:Set, rematch:Set, gone:Map, dcTimer }
const queue = [];          // [{ socketId, name }]
const players = new Map(); // socketId -> { name, roomId, finding }

const GRACE_MS = 8000;     // faster disconnect grace (8s)

// --- Puzzle pool (same structure as client expects) ---
const puzzles = [
  [[0,0,0,2,6,0,7,0,1],[6,8,0,0,7,0,0,9,0],[1,9,0,0,0,4,5,0,0],[8,2,0,1,0,0,0,4,0],[0,0,4,6,0,2,9,0,0],[0,5,0,0,0,3,0,2,8],[0,0,9,3,0,0,0,7,4],[0,4,0,0,5,0,0,3,6],[7,0,3,0,1,8,0,0,0]],
  [[0,2,0,0,0,6,0,0,9],[0,0,0,0,9,0,0,5,0],[8,0,0,0,0,5,0,0,2],[0,0,8,0,0,0,0,2,0],[0,7,0,4,0,1,0,9,0],[0,3,0,0,0,0,6,0,0],[5,0,0,6,0,0,0,0,7],[0,4,0,0,1,0,0,0,0],[9,0,0,3,0,0,0,1,0]],
  [[0,0,6,0,0,0,2,8,0],[0,0,0,0,0,3,0,0,6],[7,0,0,0,8,0,0,0,4],[0,0,0,9,0,0,1,0,0],[5,0,0,0,0,0,0,0,2],[0,0,2,0,0,4,0,0,0],[2,0,0,0,1,0,0,0,7],[6,0,0,4,0,0,0,0,0],[0,5,1,0,0,0,8,0,0]],
];

function pickPuzzle() {
  const i = Math.floor(Math.random() * puzzles.length);
  return puzzles[i].map(r => [...r]); // deep copy
}

function makeRoomId() {
  return 'room_' + Math.random().toString(36).slice(2, 8);
}

function isSolved(grid) {
  if (!Array.isArray(grid) || grid.length !== 9) return false;
  const want = '123456789';
  for (let r = 0; r < 9; r++) {
    if (!Array.isArray(grid[r]) || grid[r].length !== 9) return false;
    if ([...grid[r]].sort().join('') !== want) return false;
  }
  for (let c = 0; c < 9; c++) {
    const col = [];
    for (let r = 0; r < 9; r++) col.push(grid[r][c]);
    if (col.sort().join('') !== want) return false;
  }
  for (let br = 0; br < 3; br++) {
    for (let bc = 0; bc < 3; bc++) {
      const box = [];
      for (let r = br*3; r < br*3+3; r++) {
        for (let c = bc*3; c < bc*3+3; c++) box.push(grid[r][c]);
      }
      if (box.sort().join('') !== want) return false;
    }
  }
  return true;
}

function tryMatch() {
  while (queue.length >= 2) {
    const a = queue.shift();
    const b = queue.shift();
    if (!a || !b || a.socketId === b.socketId) continue;
    const sA = io.sockets.sockets.get(a.socketId);
    const sB = io.sockets.sockets.get(b.socketId);
    if (!sA || !sB) continue;

    const roomId = makeRoomId();
    sA.join(roomId); sB.join(roomId);

    const pA = players.get(a.socketId) || {};
    const pB = players.get(b.socketId) || {};
    pA.roomId = roomId; pA.finding = false; pA.name = a.name || pA.name || 'Player A';
    pB.roomId = roomId; pB.finding = false; pB.name = b.name || pB.name || 'Player B';
    players.set(a.socketId, pA);
    players.set(b.socketId, pB);

    rooms.set(roomId, {
      players: [a.socketId, b.socketId],
      puzzle: pickPuzzle(),
      startAtMs: null,
      finished: false,
      ready: new Set(),
      rematch: new Set(),
      gone: new Map(),
      dcTimer: null,
    });

    sA.emit('match:found', { roomId, opponentName: pB.name });
    sB.emit('match:found', { roomId, opponentName: pA.name });
  }
}

// housekeeping (queue prune, stale rooms with both gone >30s)
setInterval(() => {
  const now = Date.now();
  for (const [id, room] of rooms.entries()) {
    const bothGone = room.players.every(pid => room.gone.has(pid));
    if (bothGone) {
      const oldest = Math.min(...room.players.map(pid => room.gone.get(pid) || now));
      if (now - oldest > 30000) rooms.delete(id);
    }
  }
  for (let i = queue.length - 1; i >= 0; i--) {
    if (!io.sockets.sockets.get(queue[i].socketId)) queue.splice(i, 1);
  }
}, 5000);

// ---------------- Sockets ----------------
io.on('connection', (socket) => {
  players.set(socket.id, { name: undefined, roomId: null, finding: false });
  socket.emit('server:welcome', { id: socket.id });

  socket.on('client:hello', (p) => {
    const m = players.get(socket.id) || {};
    if (p?.name) m.name = p.name;
    players.set(socket.id, m);
  });

  socket.on('client:ping', () => socket.emit('server:pong', { now: Date.now() }));

  socket.on('match:find', ({ name }) => {
    const meta = players.get(socket.id) || {};
    if (name) meta.name = name;
    meta.finding = true;
    players.set(socket.id, meta);

    if (!queue.some(q => q.socketId === socket.id)) {
      queue.push({ socketId: socket.id, name: meta.name || 'Player' });
      socket.emit('match:status', { finding: true, queueSize: queue.length });
      tryMatch();
    }
  });

  socket.on('match:cancel', () => {
    const idx = queue.findIndex(q => q.socketId === socket.id);
    if (idx !== -1) queue.splice(idx, 1);
    const meta = players.get(socket.id) || {};
    meta.finding = false;
    players.set(socket.id, meta);
    socket.emit('match:status', { finding: false, queueSize: queue.length });
  });

  socket.on('game:ready', ({ roomId }) => {
    const room = rooms.get(roomId);
    if (!room || !room.players.includes(socket.id)) return;
    room.ready.add(socket.id);
    if (room.ready.size === room.players.length) {
      room.startAtMs = Date.now() + 1500;
      rooms.set(roomId, room);
      io.to(roomId).emit('game:start', { roomId, puzzle: room.puzzle, startAt: room.startAtMs });
    }
  });

  socket.on('game:finish', ({ roomId, grid }) => {
    const room = rooms.get(roomId);
    if (!room || room.finished || !room.players.includes(socket.id)) return;

    if (!isSolved(grid)) {
      socket.emit('game:finish_rejected');
      return;
    }
    room.finished = true;
    rooms.set(roomId, room);
    const elapsedMs = Math.max(0, Date.now() - (room.startAtMs || Date.now()));
    io.to(roomId).emit('game:win', { winnerSocketId: socket.id, elapsedMs });
  });

  socket.on('game:rematch_request', ({ roomId }) => {
    const room = rooms.get(roomId);
    if (!room || !room.players.includes(socket.id)) return;

    // deny while someone is offline
    if (room.gone.size > 0) {
      socket.emit('game:rematch_denied', { reason: 'opponent_offline' });
      return;
    }

    room.rematch.add(socket.id);
    rooms.set(roomId, room);
    socket.to(roomId).emit('game:rematch_status', { waiting: true });

    if (room.rematch.size === room.players.length) {
      room.puzzle = pickPuzzle();
      room.finished = false;
      room.ready = new Set();
      room.rematch = new Set();
      room.startAtMs = Date.now() + 1500;
      rooms.set(roomId, room);
      io.to(roomId).emit('game:start', { roomId, puzzle: room.puzzle, startAt: room.startAtMs });
    }
  });

  socket.on('resume:request', ({ roomId, name }) => {
    const room = rooms.get(roomId);
    if (!room) return;

    let reclaimed = null;
    for (const pid of room.players) if (room.gone.has(pid)) { reclaimed = pid; break; }
    if (reclaimed == null) return;

    const idx = room.players.indexOf(reclaimed);
    if (idx >= 0) room.players[idx] = socket.id;

    room.gone.delete(reclaimed);
    if (room.dcTimer) { clearTimeout(room.dcTimer); room.dcTimer = null; }
    rooms.set(roomId, room);

    players.set(socket.id, { name: name || 'Player', roomId, finding: false });
    socket.join(roomId);

    socket.emit('resume:ok', { roomId, startAtMs: room.startAtMs, puzzle: room.puzzle });
    socket.to(roomId).emit('opponent:reconnected');
  });

  socket.on('disconnect', () => {
    // remove from queue
    const qIdx = queue.findIndex(q => q.socketId === socket.id);
    if (qIdx !== -1) queue.splice(qIdx, 1);

    const meta = players.get(socket.id);
    if (meta?.roomId) {
      const room = rooms.get(meta.roomId);
      if (room) {
        room.gone.set(socket.id, Date.now());
        // clear rematch while offline
        room.rematch.clear();

        // notify immediately + schedule auto-win
        io.to(meta.roomId).emit('opponent:disconnected', { graceMs: GRACE_MS });

        if (room.dcTimer) clearTimeout(room.dcTimer);
        room.dcTimer = setTimeout(() => {
          const r = rooms.get(meta.roomId);
          if (!r || r.finished) return;
          if (r.gone.has(socket.id)) {
            r.finished = true;
            rooms.set(meta.roomId, r);
            const other = r.players.find(p => p !== socket.id);
            io.to(meta.roomId).emit('game:win', {
              winnerSocketId: other,
              elapsedMs: Math.max(0, Date.now() - (r.startAtMs || Date.now())),
            });
          }
        }, GRACE_MS);

        rooms.set(meta.roomId, room);
      }
    }

    players.delete(socket.id);
  });
});

httpServer.listen(PORT, () => {
  console.log(`Server listening on ${PORT}`);
});
