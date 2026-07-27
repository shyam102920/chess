PRO CHESS — MULTIPLAYER CHESS — FULL SOURCE
=================================================

This file contains every text-based source file in the project, one after
another, so you can copy each section into its own file when setting up
the GitHub repo. Two binary files are NOT included here (can't be
represented as text) — get them from the .zip instead:
  - public/vendor/stockfish/stockfish-18-lite-single.wasm (7.3MB engine binary)

Folder structure to recreate:
  .gitignore
  README.md
  db.js
  package-lock.json
  package.json
  public/analysis.js
  public/client.js
  public/index.html
  public/stockfish-client.js
  public/style.css
  public/vendor/chess.esm.js
  public/vendor/stockfish/stockfish-18-lite-single.js
  public/vendor/stockfish/stockfish-18-lite-single.wasm
  server.js

=================================================


#################################################################
### FILE: .gitignore
#################################################################

node_modules/
db.json
.env
*.log


#################################################################
### FILE: package.json
#################################################################

{
  "name": "pro-chess",
  "version": "2.0.0",
  "description": "Real-time multiplayer chess with accounts, ratings, and Stockfish game review",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "bcryptjs": "^2.4.3",
    "chess.js": "^1.4.0",
    "express": "^4.19.2",
    "express-session": "^1.18.0",
    "socket.io": "^4.7.5"
  }
}


#################################################################
### FILE: README.md
#################################################################

# Pro Chess — Multiplayer Chess

A real-time two-player chess app: create a room, share the code (or invite link),
and play live with full rule enforcement, clocks, resign/draw, move history, chat,
accounts with Elo ratings, and Stockfish-powered game review.

## Features
- Full legal move validation (castling, en passant, promotion, pins, checks) via `chess.js`
- Checkmate / stalemate / draw detection, resignation, draw offers
- Per-side clock with increment, server-authoritative (can't be cheated by closing the tab)
- **Accounts**: sign up / log in, sessions persist across visits
- **Elo-style ratings**: when two logged-in accounts play, ratings update automatically
  after the game (checkmate, resignation, timeout, or draw). Guest games are unrated.
- Profile cards under the board showing rating, win/loss/draw record, and the
  rating change (+/-) right after a game, chess.com-style
- **Stockfish analysis**: an optional live evaluation bar during play, and a
  post-game "Analyze with Stockfish" button that classifies every move
  (Brilliant / Best / Excellent / Good / Inaccuracy / Mistake / Blunder) and
  gives each player an estimated accuracy percentage
- Move list in algebraic notation, in-game chat, rematch (auto-swaps colors)
- Shareable room code + invite link; spectator mode if a 3rd person opens the link

## Run it locally
```bash
npm install
node server.js
```
Open `http://localhost:3000`. To play with a friend on the **same Wi-Fi**,
share `http://<your-local-ip>:3000` instead of localhost.

## Push to GitHub, then deploy
GitHub itself (including GitHub Pages) only hosts **static files** — it cannot
run the Node.js/Socket.io server this app needs for real-time multiplayer and
accounts. The workflow is:

1. **Push this project to a GitHub repo** (`git init`, `git add .`, `git commit`,
   create a repo on GitHub, `git push`).
2. **Deploy the repo on a Node-friendly host** so it's actually reachable by
   your friend:
   - **Render.com** (free tier): New → Web Service → connect your GitHub repo →
     Build command `npm install`, Start command `node server.js`.
   - **Railway.app**: same idea, auto-detects `npm start`.
   - Both redeploy automatically whenever you push new commits to GitHub.
3. Share the resulting public URL + room code with your friend.

**Quick temporary option (no deploy at all):** run `node server.js` locally,
then use `ngrok http 3000` to get a temporary public URL to send your friend.

⚠️ **Before deploying publicly**, set a real `SESSION_SECRET` environment
variable on your host (used to sign login cookies) instead of the default
placeholder in `server.js`.

## How to play
1. Optionally sign up / log in (top of the lobby) so your rating is tracked.
   Otherwise just enter a name and play as a guest (unrated).
2. Click **Create room**, set the time control, and share the room code (or
   hit "Copy invite link") with your friend.
3. Your friend enters the code under **Join a friend** (or opens the invite link).
4. The game starts once both players are in. Click a piece to see legal moves
   highlighted, then click a destination square to move.
5. After the game ends, click **Analyze with Stockfish** for a full move-by-move
   review and accuracy score.

## Project structure
```
server.js                     Express + Socket.io server, authoritative game/room state
db.js                         Simple JSON-file account store (signup/login, Elo ratings)
public/index.html             Page layout
public/style.css              Visual design
public/client.js              Board rendering + client logic (ES module)
public/analysis.js            Move classification / accuracy math, built on the engine wrapper
public/stockfish-client.js    Thin wrapper around the Stockfish Web Worker
public/vendor/chess.esm.js    Bundled chess.js rules engine, used client-side for highlighting
public/vendor/stockfish/      Stockfish 18 (lite, single-threaded) engine — same one chess.com sponsors
```

## Notes on scope and testing
This is a solid, fully working core chess + accounts + analysis experience —
not a byte-for-byte clone of chess.com (no puzzles, tournaments, or social feed).
Multiplayer gameplay, accounts, and Elo rating updates were tested end-to-end
against a running server (signup/login, checkmate, resignation, draws, illegal
move rejection, and guest-vs-rated games all verified). The Stockfish engine
binary was confirmed to load and execute correctly; the live eval bar and game
review use the same documented Web Worker message protocol the engine ships
with, but the full in-browser Worker handshake wasn't executable in the build
sandbox — if you hit an issue with the eval bar or game review specifically,
open the browser console for details and let me know.


#################################################################
### FILE: db.js
#################################################################

const fs = require('fs');
const path = require('path');
const bcrypt = require('bcryptjs');

const DB_PATH = path.join(__dirname, 'db.json');

function load() {
  if (!fs.existsSync(DB_PATH)) return { users: {} };
  try {
    return JSON.parse(fs.readFileSync(DB_PATH, 'utf8'));
  } catch {
    return { users: {} };
  }
}

let db = load();
let saveTimer = null;
function persist() {
  clearTimeout(saveTimer);
  saveTimer = setTimeout(() => {
    fs.writeFileSync(DB_PATH, JSON.stringify(db, null, 2));
  }, 150);
}

function publicUser(u) {
  if (!u) return null;
  return {
    id: u.id,
    username: u.username,
    rating: u.rating,
    wins: u.wins,
    losses: u.losses,
    draws: u.draws,
    gamesPlayed: u.gamesPlayed,
    createdAt: u.createdAt,
  };
}

function findByUsername(username) {
  const key = username.toLowerCase();
  return Object.values(db.users).find((u) => u.username.toLowerCase() === key) || null;
}

function getById(id) {
  return db.users[id] || null;
}

function createUser(username, password) {
  username = String(username || '').trim();
  if (username.length < 3 || username.length > 20) {
    throw new Error('Username must be 3-20 characters.');
  }
  if (!/^[a-zA-Z0-9_]+$/.test(username)) {
    throw new Error('Username can only contain letters, numbers, and underscores.');
  }
  if (findByUsername(username)) {
    throw new Error('That username is already taken.');
  }
  if (!password || password.length < 6) {
    throw new Error('Password must be at least 6 characters.');
  }
  const id = 'u_' + Date.now().toString(36) + Math.random().toString(36).slice(2, 8);
  const user = {
    id,
    username,
    passwordHash: bcrypt.hashSync(password, 10),
    rating: 800,
    wins: 0,
    losses: 0,
    draws: 0,
    gamesPlayed: 0,
    createdAt: new Date().toISOString(),
  };
  db.users[id] = user;
  persist();
  return user;
}

function verifyLogin(username, password) {
  const user = findByUsername(username);
  if (!user) throw new Error('No account with that username.');
  if (!bcrypt.compareSync(password, user.passwordHash)) throw new Error('Incorrect password.');
  return user;
}

// Standard Elo update, K-factor higher for newer players
function applyGameResult(idWhite, idBlack, result) {
  // result: 'white' | 'black' | 'draw'
  const w = getById(idWhite);
  const b = getById(idBlack);
  if (!w || !b) return null;

  const kFor = (u) => (u.gamesPlayed < 20 ? 40 : u.rating >= 1600 ? 16 : 24);
  const expectedW = 1 / (1 + Math.pow(10, (b.rating - w.rating) / 400));
  const expectedB = 1 - expectedW;
  const scoreW = result === 'white' ? 1 : result === 'black' ? 0 : 0.5;
  const scoreB = 1 - scoreW;

  const deltaW = Math.round(kFor(w) * (scoreW - expectedW));
  const deltaB = Math.round(kFor(b) * (scoreB - expectedB));

  w.rating = Math.max(100, w.rating + deltaW);
  b.rating = Math.max(100, b.rating + deltaB);
  w.gamesPlayed++; b.gamesPlayed++;
  if (result === 'white') { w.wins++; b.losses++; }
  else if (result === 'black') { b.wins++; w.losses++; }
  else { w.draws++; b.draws++; }

  persist();
  return {
    white: { ...publicUser(w), delta: deltaW },
    black: { ...publicUser(b), delta: deltaB },
  };
}

module.exports = { createUser, verifyLogin, getById, findByUsername, publicUser, applyGameResult };


#################################################################
### FILE: server.js
#################################################################

const express = require('express');
const http = require('http');
const path = require('path');
const session = require('express-session');
const { Server } = require('socket.io');
const { Chess } = require('chess.js');
const db = require('./db');

const app = express();
const server = http.createServer(app);
const io = new Server(server);

const sessionMiddleware = session({
  secret: process.env.SESSION_SECRET || 'pro-chess-dev-secret-change-me',
  resave: false,
  saveUninitialized: false,
  cookie: { maxAge: 1000 * 60 * 60 * 24 * 30 }, // 30 days
});
app.use(sessionMiddleware);
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));
io.engine.use(sessionMiddleware); // share the same session/cookie with sockets

// ---------- Auth routes ----------
app.post('/api/signup', (req, res) => {
  try {
    const user = db.createUser(req.body.username, req.body.password);
    req.session.userId = user.id;
    res.json({ user: db.publicUser(user) });
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});

app.post('/api/login', (req, res) => {
  try {
    const user = db.verifyLogin(req.body.username, req.body.password);
    req.session.userId = user.id;
    res.json({ user: db.publicUser(user) });
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});

app.post('/api/logout', (req, res) => {
  req.session.destroy(() => res.json({ ok: true }));
});

app.get('/api/me', (req, res) => {
  const user = req.session.userId ? db.getById(req.session.userId) : null;
  res.json({ user: db.publicUser(user) });
});

// ---- In-memory room store ----
// rooms[code] = {
//   chess, players: {white: socketId, black: socketId}, spectators: [socketId],
//   names: {white, black}, clock: {white, black}, increment, running: 'white'|'black'|null,
//   lastTick, timeControlMs, drawOffer: null|'white'|'black', started: bool
// }
const rooms = {};

function getSessionUser(socket) {
  const userId = socket.request.session && socket.request.session.userId;
  return userId ? db.getById(userId) : null;
}

function genCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let code;
  do {
    code = Array.from({ length: 5 }, () => chars[Math.floor(Math.random() * chars.length)]).join('');
  } while (rooms[code]);
  return code;
}

function publicState(room) {
  return {
    fen: room.chess.fen(),
    turn: room.chess.turn(),
    history: room.chess.history({ verbose: true }),
    inCheck: room.chess.inCheck(),
    isCheckmate: room.chess.isCheckmate(),
    isStalemate: room.chess.isStalemate(),
    isDraw: room.chess.isDraw(),
    isGameOver: room.chess.isGameOver(),
    clock: room.clock,
    running: room.running,
    names: room.names,
    profiles: room.profiles,
    drawOffer: room.drawOffer,
    started: room.started,
    timeControlMs: room.timeControlMs,
    result: room.result || null,
    ratingUpdate: room.ratingUpdate || null,
  };
}

function broadcastState(code) {
  const room = rooms[code];
  if (!room) return;
  io.to(code).emit('state', publicState(room));
}

function stopClockAndTick(room) {
  if (!room.running) return;
  const now = Date.now();
  const elapsed = now - room.lastTick;
  room.clock[room.running] = Math.max(0, room.clock[room.running] - elapsed);
  room.lastTick = now;
}

function endGame(code, result) {
  const room = rooms[code];
  if (!room) return;
  room.running = null;
  room.result = result;

  // Rating update only when BOTH seats are logged-in accounts (guests play unrated)
  if (room.accountIds.white && room.accountIds.black) {
    let outcome = null;
    if (result.type === 'checkmate' || result.type === 'resignation' || result.type === 'timeout') {
      outcome = result.winner; // 'white' | 'black'
    } else if (result.type === 'draw') {
      outcome = 'draw';
    }
    if (outcome) {
      const ratingUpdate = db.applyGameResult(room.accountIds.white, room.accountIds.black, outcome);
      if (ratingUpdate) room.ratingUpdate = ratingUpdate;
    }
  }
  broadcastState(code);
}

// Server-authoritative flag-fall checker
setInterval(() => {
  for (const code of Object.keys(rooms)) {
    const room = rooms[code];
    if (!room.running || room.chess.isGameOver()) continue;
    stopClockAndTick(room);
    if (room.clock[room.running] <= 0) {
      const winner = room.running === 'white' ? 'black' : 'white';
      endGame(code, { type: 'timeout', winner });
    } else {
      // resume timer reference point and push a light update every second
      room.lastTick = Date.now();
      io.to(code).volatile.emit('clock', room.clock);
    }
  }
}, 1000);

io.on('connection', (socket) => {
  socket.on('create-room', ({ name, timeControlMin, increment }) => {
    const code = genCode();
    const timeControlMs = Math.max(1, Number(timeControlMin) || 10) * 60 * 1000;
    const account = getSessionUser(socket);
    rooms[code] = {
      chess: new Chess(),
      players: { white: socket.id, black: null },
      spectators: [],
      names: { white: account ? account.username : (name || 'Player 1'), black: null },
      accountIds: { white: account ? account.id : null, black: null },
      profiles: { white: account ? db.publicUser(account) : null, black: null },
      clock: { white: timeControlMs, black: timeControlMs },
      increment: Math.max(0, Number(increment) || 0) * 1000,
      running: null,
      lastTick: Date.now(),
      timeControlMs,
      drawOffer: null,
      started: false,
      result: null,
      ratingUpdate: null,
    };
    socket.join(code);
    socket.data.code = code;
    socket.data.color = 'white';
    socket.emit('joined', { code, color: 'white' });
    broadcastState(code);
  });

  socket.on('join-room', ({ code, name }) => {
    code = (code || '').toUpperCase().trim();
    const room = rooms[code];
    if (!room) return socket.emit('error-msg', 'Room not found.');
    socket.join(code);
    socket.data.code = code;
    const account = getSessionUser(socket);

    if (!room.players.white) {
      room.players.white = socket.id;
      room.names.white = account ? account.username : (name || 'Player 1');
      room.accountIds.white = account ? account.id : null;
      room.profiles.white = account ? db.publicUser(account) : null;
      socket.data.color = 'white';
    } else if (!room.players.black) {
      room.players.black = socket.id;
      room.names.black = account ? account.username : (name || 'Player 2');
      room.accountIds.black = account ? account.id : null;
      room.profiles.black = account ? db.publicUser(account) : null;
      socket.data.color = 'black';
    } else {
      room.spectators.push(socket.id);
      socket.data.color = 'spectator';
    }

    socket.emit('joined', { code, color: socket.data.color });

    if (room.players.white && room.players.black && !room.started) {
      room.started = true;
      room.running = 'white';
      room.lastTick = Date.now();
    }
    broadcastState(code);
  });

  socket.on('move', ({ from, to, promotion }) => {
    const code = socket.data.code;
    const room = rooms[code];
    if (!room || !room.started || room.chess.isGameOver()) return;
    const color = socket.data.color;
    const turnColor = room.chess.turn() === 'w' ? 'white' : 'black';
    if (color !== turnColor) return;

    stopClockAndTick(room);

    let move;
    try {
      move = room.chess.move({ from, to, promotion: promotion || 'q' });
    } catch (e) {
      move = null;
    }
    if (!move) {
      socket.emit('illegal-move', { from, to });
      return;
    }

    room.clock[color] += room.increment;
    room.drawOffer = null;

    if (room.chess.isGameOver()) {
      if (room.chess.isCheckmate()) {
        endGame(code, { type: 'checkmate', winner: color });
      } else {
        endGame(code, { type: 'draw', reason: room.chess.isStalemate() ? 'stalemate' : 'draw' });
      }
    } else {
      room.running = turnColor === 'white' ? 'black' : 'white';
      room.lastTick = Date.now();
      broadcastState(code);
    }
  });

  socket.on('resign', () => {
    const code = socket.data.code;
    const room = rooms[code];
    if (!room || room.chess.isGameOver() || !room.started) return;
    const color = socket.data.color;
    if (color !== 'white' && color !== 'black') return;
    stopClockAndTick(room);
    endGame(code, { type: 'resignation', winner: color === 'white' ? 'black' : 'white' });
  });

  socket.on('offer-draw', () => {
    const code = socket.data.code;
    const room = rooms[code];
    if (!room || room.chess.isGameOver()) return;
    room.drawOffer = socket.data.color;
    broadcastState(code);
  });

  socket.on('respond-draw', ({ accept }) => {
    const code = socket.data.code;
    const room = rooms[code];
    if (!room || !room.drawOffer) return;
    if (accept) {
      stopClockAndTick(room);
      endGame(code, { type: 'draw', reason: 'agreement' });
    } else {
      room.drawOffer = null;
      broadcastState(code);
    }
  });

  socket.on('rematch', () => {
    const code = socket.data.code;
    const room = rooms[code];
    if (!room) return;
    room.chess = new Chess();
    room.clock = { white: room.timeControlMs, black: room.timeControlMs };
    room.running = 'white';
    room.lastTick = Date.now();
    room.drawOffer = null;
    room.result = null;
    room.ratingUpdate = null;
    // swap colors for variety
    const tmp = room.players.white;
    room.players.white = room.players.black;
    room.players.black = tmp;
    [room.names, room.accountIds, room.profiles].forEach((obj) => {
      const t = obj.white; obj.white = obj.black; obj.black = t;
    });
    io.sockets.sockets.forEach((s) => {
      if (s.id === room.players.white) s.data.color = 'white';
      if (s.id === room.players.black) s.data.color = 'black';
    });
    io.to(code).emit('rematch-start');
    broadcastState(code);
  });

  socket.on('chat', (msg) => {
    const code = socket.data.code;
    if (!code || !rooms[code]) return;
    const name = rooms[code].names[socket.data.color] || 'Spectator';
    io.to(code).emit('chat', { name, msg: String(msg).slice(0, 300), color: socket.data.color });
  });

  socket.on('disconnect', () => {
    const code = socket.data.code;
    const room = rooms[code];
    if (!room) return;
    if (room.players.white === socket.id) io.to(code).emit('opponent-left', 'white');
    if (room.players.black === socket.id) io.to(code).emit('opponent-left', 'black');
  });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => console.log(`Chess server running on http://localhost:${PORT}`));


#################################################################
### FILE: public/index.html
#################################################################

<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<title>Pro Chess — Play Chess Together</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Fraunces:opsz,wght@9..144,500;9..144,700&family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="style.css" />
</head>
<body>

<div id="lobby" class="screen">
  <div class="lobby-card">
    <div class="lobby-top">
      <h1>Pro Chess</h1>
      <div id="accountBox" class="account-box">
        <button id="showAuthBtn" class="btn btn-ghost btn-small">Log in / Sign up</button>
      </div>
    </div>
    <p class="tagline">A quiet corner of the internet for one board and two people.</p>

    <div id="authPanel" class="auth-panel" style="display:none">
      <div class="auth-tabs">
        <button class="auth-tab active" data-tab="login">Log in</button>
        <button class="auth-tab" data-tab="signup">Sign up</button>
      </div>
      <form id="loginForm" class="auth-form">
        <label class="field"><span>Username</span><input id="loginUsername" type="text" required maxlength="20"/></label>
        <label class="field"><span>Password</span><input id="loginPassword" type="password" required maxlength="60"/></label>
        <button type="submit" class="btn btn-primary">Log in</button>
        <p class="error-msg" id="loginError"></p>
      </form>
      <form id="signupForm" class="auth-form" style="display:none">
        <label class="field"><span>Choose a username</span><input id="signupUsername" type="text" required maxlength="20"/></label>
        <label class="field"><span>Choose a password</span><input id="signupPassword" type="password" required maxlength="60"/></label>
        <button type="submit" class="btn btn-primary">Create account</button>
        <p class="error-msg" id="signupError"></p>
      </form>
    </div>

    <label class="field" id="guestNameField">
      <span>Your name (playing as guest)</span>
      <input id="nameInput" type="text" placeholder="e.g. Priya" maxlength="20" />
    </label>

    <div class="lobby-split">
      <div class="lobby-pane">
        <h2>Start a game</h2>
        <label class="field">
          <span>Minutes per side</span>
          <input id="timeInput" type="number" value="10" min="1" max="180" />
        </label>
        <label class="field">
          <span>Increment (seconds)</span>
          <input id="incInput" type="number" value="0" min="0" max="60" />
        </label>
        <button id="createBtn" class="btn btn-primary">Create room</button>
      </div>

      <div class="lobby-divider"><span>or</span></div>

      <div class="lobby-pane">
        <h2>Join a friend</h2>
        <label class="field">
          <span>Room code</span>
          <input id="codeInput" type="text" placeholder="e.g. K7QRT" maxlength="6" style="text-transform:uppercase" />
        </label>
        <button id="joinBtn" class="btn btn-secondary">Join room</button>
      </div>
    </div>
    <p id="lobbyError" class="error-msg"></p>
  </div>
</div>

<div id="game" class="screen" style="display:none">
  <header class="topbar">
    <div class="topbar-left">
      <span class="brand">Pro Chess</span>
      <span class="room-code">Room <strong id="roomCodeLabel"></strong></span>
    </div>
    <div class="topbar-right">
      <label class="eval-toggle"><input type="checkbox" id="evalToggle"/> Live engine eval</label>
      <button id="copyLinkBtn" class="btn btn-ghost btn-small">Copy invite link</button>
    </div>
  </header>

  <main class="board-layout">
    <div class="side-panel side-panel-left">
      <div class="player-card" id="opponentCard">
        <div class="player-identity">
          <div class="player-name" id="opponentName">Waiting for opponent…</div>
          <div class="player-rating" id="opponentRating"></div>
        </div>
        <div class="player-clock" id="opponentClock">--:--</div>
      </div>
    </div>

    <div class="evalbar-wrap" id="evalBarWrap" style="display:none">
      <div class="evalbar"><div class="evalbar-fill" id="evalFill"></div></div>
      <div class="evalbar-label" id="evalLabel">0.0</div>
    </div>

    <div class="board-wrap">
      <div id="board" class="board"></div>
      <div id="statusLine" class="status-line"></div>
    </div>

    <div class="side-panel side-panel-right">
      <div class="player-card" id="youCard">
        <div class="player-identity">
          <div class="player-name" id="youName">You</div>
          <div class="player-rating" id="youRating"></div>
        </div>
        <div class="player-clock" id="youClock">--:--</div>
      </div>

      <div class="panel-block">
        <h3>Moves</h3>
        <ol id="moveList" class="move-list"></ol>
      </div>

      <div class="panel-actions">
        <button id="resignBtn" class="btn btn-danger btn-small">Resign</button>
        <button id="drawBtn" class="btn btn-ghost btn-small">Offer draw</button>
      </div>

      <div class="panel-block" id="reviewBlock" style="display:none">
        <h3>Game review</h3>
        <button id="reviewBtn" class="btn btn-secondary btn-small">Analyze with Stockfish</button>
        <div id="reviewProgress" class="review-progress" style="display:none"></div>
        <div id="reviewResults" class="review-results" style="display:none">
          <div class="accuracy-row">
            <div class="accuracy-box"><span class="accuracy-label">White</span><span class="accuracy-value" id="accWhite">–</span></div>
            <div class="accuracy-box"><span class="accuracy-label">Black</span><span class="accuracy-value" id="accBlack">–</span></div>
          </div>
        </div>
      </div>

      <div class="panel-block chat-block">
        <h3>Chat</h3>
        <div id="chatLog" class="chat-log"></div>
        <form id="chatForm" class="chat-form">
          <input id="chatInput" type="text" maxlength="300" placeholder="Say something…" autocomplete="off" />
          <button type="submit" class="btn btn-small btn-primary">Send</button>
        </form>
      </div>
    </div>
  </main>
</div>

<div id="modalOverlay" class="modal-overlay" style="display:none">
  <div class="modal" id="modalContent"></div>
</div>

<script src="/socket.io/socket.io.js"></script>
<script type="module" src="client.js"></script>
</body>
</html>


#################################################################
### FILE: public/style.css
#################################################################

:root{
  --ink: #201a14;
  --paper: #f3ead9;
  --walnut-dark: #2a2016;
  --walnut: #4a3524;
  --brass: #c9a24b;
  --brass-bright: #e6bf6a;
  --square-light: #ecdfc4;
  --square-dark: #7c5a3a;
  --square-select: #d9b25a;
  --square-lastmove: #b98f4a88;
  --square-check: #b3423a;
  --green: #4f7a5b;
  --red: #a3453d;
  --panel: #241c15;
  --panel-line: #3d3122;
  --text-dim: #cbb999;
  font-size: 16px;
}

*{ box-sizing: border-box; }

html, body{
  margin:0; padding:0; height:100%;
  background: var(--ink);
  color: var(--paper);
  font-family: 'Inter', sans-serif;
}

body{
  background-image:
    radial-gradient(ellipse at top, #2c2318 0%, #171310 70%);
  min-height: 100vh;
}

h1, h2, h3{
  font-family: 'Fraunces', serif;
  font-weight: 700;
  margin: 0 0 .3em 0;
  color: var(--brass-bright);
}

.screen{ min-height: 100vh; }

/* ---------- LOBBY ---------- */
#lobby{
  display:flex; align-items:center; justify-content:center;
  padding: 24px;
}
.lobby-card{
  width: 100%; max-width: 640px;
  background: linear-gradient(180deg, #2a2116, #201911);
  border: 1px solid var(--panel-line);
  border-radius: 14px;
  padding: 40px;
  box-shadow: 0 30px 60px -20px rgba(0,0,0,.6);
}
.lobby-card h1{ font-size: 2.4rem; letter-spacing: .01em; }
.tagline{ color: var(--text-dim); margin-bottom: 28px; font-size: .95rem; }

.field{ display:block; margin-bottom: 14px; }
.field span{ display:block; font-size: .78rem; text-transform: uppercase; letter-spacing: .08em; color: var(--text-dim); margin-bottom: 6px; }
.field input{
  width: 100%; padding: 10px 12px;
  background: #1a140e; border: 1px solid var(--panel-line);
  border-radius: 8px; color: var(--paper); font-size: 1rem; font-family: inherit;
}
.field input:focus{ outline: 2px solid var(--brass); outline-offset: 1px; }

.lobby-split{ display:flex; gap: 20px; margin-top: 20px; align-items: stretch; }
.lobby-pane{ flex: 1; background: #1d160f; border: 1px solid var(--panel-line); border-radius: 10px; padding: 18px; }
.lobby-pane h2{ font-size: 1.1rem; margin-bottom: 14px; }
.lobby-divider{ display:flex; align-items:center; justify-content:center; color: var(--text-dim); font-size: .8rem; width: 24px; }

.btn{
  display:inline-block; border: none; border-radius: 8px;
  padding: 11px 18px; font-family: inherit; font-weight: 600; font-size: .92rem;
  cursor: pointer; transition: transform .08s ease, filter .15s ease;
  width: 100%; text-align: center;
}
.btn:hover{ filter: brightness(1.08); }
.btn:active{ transform: scale(.98); }
.btn-primary{ background: var(--brass); color: #201a10; }
.btn-secondary{ background: transparent; color: var(--brass-bright); border: 1px solid var(--brass); }
.btn-ghost{ background: #2c2318; color: var(--text-dim); border: 1px solid var(--panel-line); }
.btn-danger{ background: transparent; color: #e08a83; border: 1px solid var(--red); }
.btn-small{ width: auto; padding: 8px 14px; font-size: .82rem; }

.error-msg{ color: #e08a83; font-size: .85rem; margin-top: 14px; min-height: 1em; }

/* ---------- TOP BAR ---------- */
.topbar{
  display:flex; align-items:center; justify-content:space-between;
  padding: 14px 24px; border-bottom: 1px solid var(--panel-line);
  background: var(--panel);
}
.topbar-left{ display:flex; align-items:center; gap: 18px; }
.brand{ font-family:'Fraunces', serif; font-weight: 700; color: var(--brass-bright); font-size: 1.1rem; }
.room-code{ color: var(--text-dim); font-size: .85rem; }
.room-code strong{ color: var(--paper); letter-spacing: .1em; }

/* ---------- BOARD LAYOUT ---------- */
.board-layout{
  display:flex; gap: 28px; padding: 28px; max-width: 1200px; margin: 0 auto;
  align-items: flex-start; flex-wrap: wrap; justify-content: center;
}
.side-panel{ width: 260px; display:flex; flex-direction:column; gap: 16px; }
.side-panel-left{ order:1; }
.board-wrap{ order:2; display:flex; flex-direction:column; align-items:center; gap:10px; }
.side-panel-right{ order:3; }

.player-card{
  background: var(--panel); border: 1px solid var(--panel-line); border-radius: 10px;
  padding: 12px 16px; display:flex; align-items:center; justify-content:space-between;
}
.player-name{ font-weight: 600; }
.player-clock{
  font-family: 'Fraunces', serif; font-size: 1.3rem; font-variant-numeric: tabular-nums;
  color: var(--brass-bright); background: #171310; padding: 4px 10px; border-radius: 6px;
}
.player-clock.low{ color: #e08a83; }
.player-clock.active{ box-shadow: 0 0 0 1px var(--brass); }

.board{
  width: min(76vw, 560px); height: min(76vw, 560px);
  display: grid; grid-template-columns: repeat(8, 1fr); grid-template-rows: repeat(8, 1fr);
  border: 6px solid var(--walnut);
  border-radius: 4px;
  box-shadow: 0 20px 50px -15px rgba(0,0,0,.7);
  position: relative;
}
.square{
  position: relative; display:flex; align-items:center; justify-content:center;
  font-size: min(9vw, 3.4rem); user-select: none; cursor: pointer;
}
.square.light{ background: var(--square-light); }
.square.dark{ background: var(--square-dark); }
.square.selected{ box-shadow: inset 0 0 0 4px var(--square-select); }
.square.last-move{ background-image: linear-gradient(var(--square-lastmove), var(--square-lastmove)); }
.square.in-check{ background-image: radial-gradient(circle, var(--square-check) 30%, transparent 72%); }
.square .dot{
  position:absolute; width: 28%; height: 28%; border-radius: 50%;
  background: rgba(30,20,10,.35);
}
.square .ring{
  position:absolute; width: 88%; height: 88%; border-radius: 50%;
  box-shadow: inset 0 0 0 5px rgba(30,20,10,.35);
}
.square .piece{ pointer-events:none; filter: drop-shadow(0 2px 2px rgba(0,0,0,.35)); }
.square .coord{
  position:absolute; font-family:'Inter',sans-serif; font-size: .6rem; font-weight:700;
  opacity: .55; pointer-events:none;
}
.square .coord.file{ bottom: 2px; right: 4px; }
.square .coord.rank{ top: 2px; left: 4px; }
.square.light .coord{ color: var(--square-dark); }
.square.dark .coord{ color: var(--square-light); }

.status-line{ color: var(--text-dim); font-size: .95rem; min-height: 1.4em; text-align:center; }

.panel-block{
  background: var(--panel); border: 1px solid var(--panel-line); border-radius: 10px; padding: 14px;
}
.panel-block h3{ font-size: .95rem; margin-bottom: 10px; color: var(--brass-bright); }
.move-list{
  list-style: none; margin:0; padding:0; max-height: 220px; overflow-y:auto;
  font-family: 'Fraunces', serif; font-size: .92rem;
}
.move-list li{ display:flex; gap: 8px; padding: 3px 0; border-bottom: 1px dashed var(--panel-line); }
.move-list .mno{ color: var(--text-dim); width: 26px; }

.panel-actions{ display:flex; gap: 10px; }
.panel-actions .btn{ flex:1; }

.chat-log{
  height: 160px; overflow-y:auto; font-size: .85rem; margin-bottom: 10px;
  display:flex; flex-direction:column; gap: 6px;
}
.chat-log .msg strong{ color: var(--brass-bright); }
.chat-form{ display:flex; gap: 8px; }
.chat-form input{
  flex:1; padding: 8px 10px; background:#1a140e; border:1px solid var(--panel-line);
  border-radius: 6px; color: var(--paper); font-family: inherit;
}

/* ---------- MODAL ---------- */
.modal-overlay{
  position: fixed; inset:0; background: rgba(10,7,4,.7);
  display:flex; align-items:center; justify-content:center; z-index: 50;
}
.modal{
  background: #241c15; border: 1px solid var(--panel-line); border-radius: 12px;
  padding: 28px; max-width: 380px; text-align:center;
}
.modal h2{ margin-bottom: 10px; }
.modal p{ color: var(--text-dim); margin-bottom: 20px; }
.modal-actions{ display:flex; gap: 10px; justify-content:center; flex-wrap: wrap; }
.promo-choices{ display:flex; gap: 10px; justify-content:center; }
.promo-choices button{
  font-size: 2rem; width: 60px; height: 60px; border-radius: 8px; border: 1px solid var(--panel-line);
  background: #1a140e; cursor:pointer;
}
.promo-choices button:hover{ background: var(--brass); }

@media (max-width: 900px){
  .board-layout{ flex-direction: column; align-items:center; }
  .side-panel{ width: 100%; max-width: 560px; flex-direction: row; flex-wrap:wrap; }
  .side-panel-right{ flex-direction: column; }
  .board-wrap{ order: 0; }
  .side-panel-left{ order: -1; }
}

/* ---------- ACCOUNTS ---------- */
.lobby-top{ display:flex; align-items:flex-start; justify-content:space-between; gap: 16px; }
.account-box{ display:flex; align-items:center; gap: 10px; }
.account-chip{ display:flex; align-items:center; gap: 8px; background:#1d160f; border:1px solid var(--panel-line); border-radius: 20px; padding: 6px 12px; font-size:.85rem; }
.account-chip .rating-badge{ color: var(--brass-bright); font-weight:700; }

.auth-panel{ background:#1a140e; border:1px solid var(--panel-line); border-radius: 10px; padding: 16px; margin-bottom: 18px; }
.auth-tabs{ display:flex; gap: 6px; margin-bottom: 14px; }
.auth-tab{ flex:1; padding: 8px; border:none; border-radius: 6px; background: transparent; color: var(--text-dim); cursor:pointer; font-family:inherit; font-weight:600; }
.auth-tab.active{ background: var(--brass); color:#201a10; }
.auth-form .btn{ margin-top: 4px; }

/* ---------- TOPBAR RIGHT / EVAL TOGGLE ---------- */
.topbar-right{ display:flex; align-items:center; gap: 14px; }
.eval-toggle{ display:flex; align-items:center; gap: 6px; font-size:.82rem; color: var(--text-dim); cursor:pointer; }

/* ---------- EVAL BAR ---------- */
.evalbar-wrap{ display:flex; flex-direction:column; align-items:center; gap:6px; height: min(76vw, 560px); }
.evalbar{
  width: 20px; height: 100%; border-radius: 4px; overflow:hidden;
  background: #241a10; border: 1px solid var(--panel-line);
  display:flex; flex-direction:column-reverse;
}
.evalbar-fill{ background: var(--paper); width:100%; height:50%; transition: height .4s ease; }
.evalbar-label{ font-size:.72rem; color: var(--text-dim); font-variant-numeric: tabular-nums; }

/* ---------- PLAYER IDENTITY / RATING ---------- */
.player-identity{ display:flex; flex-direction:column; gap: 2px; }
.player-rating{ font-size:.75rem; color: var(--text-dim); }
.player-rating .delta-up{ color: #7fbf8f; font-weight:700; }
.player-rating .delta-down{ color: #e08a83; font-weight:700; }

/* ---------- MOVE TAGS ---------- */
.move-list li .tag{ font-size:.72rem; padding: 1px 5px; border-radius: 4px; margin-left:4px; font-family:'Inter',sans-serif; }
.tag-brilliant{ background:#1c5a63; color:#7fe3ef; }
.tag-best{ background:#1e4b2c; color:#8fe0a4; }
.tag-excellent{ background:#254a1e; color:#a2e08f; }
.tag-good{ background:#2c3a52; color:#9db8e0; }
.tag-inaccuracy{ background:#4a4420; color:#e0d38f; }
.tag-mistake{ background:#4a2f18; color:#e0a86f; }
.tag-blunder{ background:#4a1e1e; color:#e08f8f; }

/* ---------- REVIEW PANEL ---------- */
.review-progress{ font-size:.82rem; color: var(--text-dim); margin-top: 10px; }
.review-results{ margin-top: 12px; }
.accuracy-row{ display:flex; gap: 10px; }
.accuracy-box{
  flex:1; background:#1a140e; border:1px solid var(--panel-line); border-radius: 8px;
  padding: 10px; display:flex; flex-direction:column; align-items:center; gap:4px;
}
.accuracy-label{ font-size:.72rem; text-transform:uppercase; letter-spacing:.06em; color: var(--text-dim); }
.accuracy-value{ font-family:'Fraunces',serif; font-size:1.4rem; color: var(--brass-bright); }



#################################################################
### FILE: public/client.js
#################################################################

import { Chess } from './vendor/chess.esm.js';
import { evaluate, toWhiteCp, stop as stopEval } from './stockfish-client.js';
import { analyzeGame } from './analysis.js';

const socket = io();

const PIECE_GLYPHS = {
  wp:'♙', wn:'♘', wb:'♗', wr:'♖', wq:'♕', wk:'♔',
  bp:'♟', bn:'♞', bb:'♝', br:'♜', bq:'♛', bk:'♚',
};

let myColor = null;       // 'white' | 'black' | 'spectator'
let roomCode = null;
let localChess = new Chess(); // mirrors server FEN, used only to compute legal-move highlights
let selectedSquare = null;
let lastState = null;
let clockTickHandle = null;
let localClock = { white: 0, black: 0 };
let currentUser = null;   // logged-in account, or null for guest
let evalEnabled = false;
let evalTimer = null;
let reviewData = null;    // populated after "Analyze with Stockfish"

// ---------- DOM refs ----------
const lobbyScreen = document.getElementById('lobby');
const gameScreen = document.getElementById('game');
const nameInput = document.getElementById('nameInput');
const timeInput = document.getElementById('timeInput');
const incInput = document.getElementById('incInput');
const codeInput = document.getElementById('codeInput');
const createBtn = document.getElementById('createBtn');
const joinBtn = document.getElementById('joinBtn');
const lobbyError = document.getElementById('lobbyError');

const boardEl = document.getElementById('board');
const roomCodeLabel = document.getElementById('roomCodeLabel');
const copyLinkBtn = document.getElementById('copyLinkBtn');
const statusLine = document.getElementById('statusLine');
const moveList = document.getElementById('moveList');
const opponentName = document.getElementById('opponentName');
const opponentClock = document.getElementById('opponentClock');
const opponentRating = document.getElementById('opponentRating');
const youName = document.getElementById('youName');
const youClock = document.getElementById('youClock');
const youRating = document.getElementById('youRating');
const resignBtn = document.getElementById('resignBtn');
const drawBtn = document.getElementById('drawBtn');
const chatLog = document.getElementById('chatLog');
const chatForm = document.getElementById('chatForm');
const chatInput = document.getElementById('chatInput');
const modalOverlay = document.getElementById('modalOverlay');
const modalContent = document.getElementById('modalContent');

// Accounts
const accountBox = document.getElementById('accountBox');
const showAuthBtn = document.getElementById('showAuthBtn');
const authPanel = document.getElementById('authPanel');
const authTabs = document.querySelectorAll('.auth-tab');
const loginForm = document.getElementById('loginForm');
const signupForm = document.getElementById('signupForm');
const loginError = document.getElementById('loginError');
const signupError = document.getElementById('signupError');
const guestNameField = document.getElementById('guestNameField');

// Eval bar
const evalToggle = document.getElementById('evalToggle');
const evalBarWrap = document.getElementById('evalBarWrap');
const evalFill = document.getElementById('evalFill');
const evalLabel = document.getElementById('evalLabel');

// Game review
const reviewBlock = document.getElementById('reviewBlock');
const reviewBtn = document.getElementById('reviewBtn');
const reviewProgress = document.getElementById('reviewProgress');
const reviewResults = document.getElementById('reviewResults');
const accWhite = document.getElementById('accWhite');
const accBlack = document.getElementById('accBlack');
// ---------- Accounts / Auth ----------
showAuthBtn.addEventListener('click', () => {
  authPanel.style.display = authPanel.style.display === 'none' ? 'block' : 'none';
});

authTabs.forEach((tab) => {
  tab.addEventListener('click', () => {
    authTabs.forEach((t) => t.classList.remove('active'));
    tab.classList.add('active');
    const isLogin = tab.dataset.tab === 'login';
    loginForm.style.display = isLogin ? 'block' : 'none';
    signupForm.style.display = isLogin ? 'none' : 'block';
  });
});

async function apiPost(url, body) {
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body || {}),
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.error || 'Something went wrong.');
  return data;
}

function renderAccountBox() {
  if (currentUser) {
    accountBox.innerHTML = `
      <div class="account-chip">
        <span>${escapeHtml(currentUser.username)}</span>
        <span class="rating-badge">${currentUser.rating}</span>
      </div>
      <button id="logoutBtn" class="btn btn-ghost btn-small">Log out</button>`;
    document.getElementById('logoutBtn').addEventListener('click', async () => {
      await apiPost('/api/logout');
      currentUser = null;
      renderAccountBox();
    });
    authPanel.style.display = 'none';
    guestNameField.style.display = 'none';
  } else {
    accountBox.innerHTML = `<button id="showAuthBtn" class="btn btn-ghost btn-small">Log in / Sign up</button>`;
    document.getElementById('showAuthBtn').addEventListener('click', () => {
      authPanel.style.display = authPanel.style.display === 'none' ? 'block' : 'none';
    });
    guestNameField.style.display = 'block';
  }
}

loginForm.addEventListener('submit', async (e) => {
  e.preventDefault();
  loginError.textContent = '';
  try {
    const { user } = await apiPost('/api/login', {
      username: document.getElementById('loginUsername').value.trim(),
      password: document.getElementById('loginPassword').value,
    });
    currentUser = user;
    renderAccountBox();
  } catch (err) {
    loginError.textContent = err.message;
  }
});

signupForm.addEventListener('submit', async (e) => {
  e.preventDefault();
  signupError.textContent = '';
  try {
    const { user } = await apiPost('/api/signup', {
      username: document.getElementById('signupUsername').value.trim(),
      password: document.getElementById('signupPassword').value,
    });
    currentUser = user;
    renderAccountBox();
  } catch (err) {
    signupError.textContent = err.message;
  }
});

(async function checkSession() {
  try {
    const res = await fetch('/api/me');
    const data = await res.json();
    if (data.user) { currentUser = data.user; renderAccountBox(); }
  } catch { /* not logged in, ignore */ }
})();

// ---------- Lobby ----------
const params = new URLSearchParams(location.search);
if (params.get('room')) codeInput.value = params.get('room').toUpperCase();

createBtn.addEventListener('click', () => {
  lobbyError.textContent = '';
  socket.emit('create-room', {
    name: nameInput.value.trim(),
    timeControlMin: timeInput.value,
    increment: incInput.value,
  });
});

joinBtn.addEventListener('click', () => {
  lobbyError.textContent = '';
  const code = codeInput.value.trim().toUpperCase();
  if (!code) { lobbyError.textContent = 'Enter a room code.'; return; }
  socket.emit('join-room', { code, name: nameInput.value.trim() });
});

socket.on('error-msg', (msg) => { lobbyError.textContent = msg; });

socket.on('joined', ({ code, color }) => {
  roomCode = code;
  myColor = color;
  roomCodeLabel.textContent = code;
  lobbyScreen.style.display = 'none';
  gameScreen.style.display = 'block';
  history.replaceState(null, '', `?room=${code}`);
});

copyLinkBtn.addEventListener('click', () => {
  const url = `${location.origin}${location.pathname}?room=${roomCode}`;
  navigator.clipboard.writeText(url).then(() => {
    copyLinkBtn.textContent = 'Link copied!';
    setTimeout(() => (copyLinkBtn.textContent = 'Copy invite link'), 1500);
  });
});

// ---------- Board rendering ----------
function squareId(file, rank) { return 'abcdefgh'[file] + rank; } // rank 1-8

function buildBoardSkeleton() {
  boardEl.innerHTML = '';
  const flip = myColor === 'black';
  for (let visRow = 0; visRow < 8; visRow++) {
    for (let visCol = 0; visCol < 8; visCol++) {
      const rank = flip ? visRow + 1 : 8 - visRow;
      const file = flip ? 7 - visCol : visCol;
      const id = squareId(file, rank);
      const sq = document.createElement('div');
      sq.className = `square ${(file + rank) % 2 === 0 ? 'dark' : 'light'}`;
      sq.dataset.square = id;
      if (visCol === 0) {
        const c = document.createElement('span');
        c.className = 'coord rank'; c.textContent = rank; sq.appendChild(c);
      }
      if (visRow === 7) {
        const c = document.createElement('span');
        c.className = 'coord file'; c.textContent = 'abcdefgh'[file]; sq.appendChild(c);
      }
      sq.addEventListener('click', () => onSquareClick(id));
      boardEl.appendChild(sq);
    }
  }
}

function render() {
  if (!lastState) return;
  const { fen, history, inCheck, turn } = lastState;
  localChess.load(fen);

  // clear dynamic classes/content but keep coord labels
  document.querySelectorAll('.square').forEach((sq) => {
    sq.classList.remove('selected', 'last-move', 'in-check');
    const piece = sq.querySelector('.piece'); if (piece) piece.remove();
    const dot = sq.querySelector('.dot'); if (dot) dot.remove();
    const ring = sq.querySelector('.ring'); if (ring) ring.remove();
  });

  const board = localChess.board(); // 8x8 array, row0 = rank8
  for (let r = 0; r < 8; r++) {
    for (let c = 0; c < 8; c++) {
      const cell = board[r][c];
      if (!cell) continue;
      const rank = 8 - r, file = c;
      const id = squareId(file, rank);
      const sqEl = document.querySelector(`.square[data-square="${id}"]`);
      if (!sqEl) continue;
      const span = document.createElement('span');
      span.className = 'piece';
      span.textContent = PIECE_GLYPHS[cell.color + cell.type];
      sqEl.appendChild(span);
    }
  }

  // last move highlight
  if (history.length) {
    const last = history[history.length - 1];
    [last.from, last.to].forEach((sqId) => {
      const el = document.querySelector(`.square[data-square="${sqId}"]`);
      if (el) el.classList.add('last-move');
    });
  }

  // check highlight
  if (inCheck) {
    const kingColor = turn; // side to move is in check
    const kingSq = findKing(board, kingColor);
    if (kingSq) {
      const el = document.querySelector(`.square[data-square="${kingSq}"]`);
      if (el) el.classList.add('in-check');
    }
  }

  if (selectedSquare) {
    const el = document.querySelector(`.square[data-square="${selectedSquare}"]`);
    if (el) el.classList.add('selected');
    showLegalMoveDots(selectedSquare);
  }

  updateStatusAndNames();
  renderMoveList(history);
}

function findKing(board, color) {
  for (let r = 0; r < 8; r++) for (let c = 0; c < 8; c++) {
    const cell = board[r][c];
    if (cell && cell.type === 'k' && cell.color === color) return squareId(c, 8 - r);
  }
  return null;
}

function showLegalMoveDots(fromSq) {
  const moves = localChess.moves({ square: fromSq, verbose: true });
  moves.forEach((m) => {
    const el = document.querySelector(`.square[data-square="${m.to}"]`);
    if (!el) return;
    const marker = document.createElement('span');
    marker.className = m.captured ? 'ring' : 'dot';
    el.appendChild(marker);
  });
}

function renderMoveList(history) {
  moveList.innerHTML = '';
  for (let i = 0; i < history.length; i += 2) {
    const li = document.createElement('li');
    const num = document.createElement('span');
    num.className = 'mno'; num.textContent = (i / 2 + 1) + '.';
    li.appendChild(num);
    li.appendChild(moveSpan(history[i], i));
    if (history[i + 1]) li.appendChild(moveSpan(history[i + 1], i + 1));
    moveList.appendChild(li);
  }
  moveList.scrollTop = moveList.scrollHeight;
}

function moveSpan(move, ply) {
  const span = document.createElement('span');
  span.textContent = move.san;
  if (reviewData && reviewData.perMove[ply]) {
    const tag = reviewData.perMove[ply].tag;
    const badge = document.createElement('span');
    badge.className = `tag ${tag.className}`;
    badge.textContent = tag.glyph || tag.label[0];
    badge.title = tag.label;
    span.appendChild(badge);
  }
  return span;
}

function updateStatusAndNames() {
  const { names, profiles, turn, result, started, drawOffer, ratingUpdate } = lastState;
  const oppColor = myColor === 'white' ? 'black' : 'white';
  if (myColor === 'spectator') {
    youName.textContent = 'Spectating';
    opponentName.textContent = `${names.white || '?'} vs ${names.black || '?'}`;
  } else {
    youName.textContent = names[myColor] || 'You';
    opponentName.textContent = names[oppColor] || 'Waiting for opponent…';
  }

  const youC = myColor === 'spectator' ? 'white' : myColor;
  const oppC = myColor === 'spectator' ? 'black' : oppColor;
  youRating.innerHTML = ratingLabel(profiles && profiles[youC], ratingUpdate && ratingUpdate[youC]);
  opponentRating.innerHTML = ratingLabel(profiles && profiles[oppC], ratingUpdate && ratingUpdate[oppC]);

  if (!started) {
    statusLine.textContent = 'Waiting for a second player to join…';
  } else if (result) {
    if (result.type === 'checkmate') statusLine.textContent = `Checkmate — ${cap(result.winner)} wins.`;
    else if (result.type === 'resignation') statusLine.textContent = `${cap(result.winner === 'white' ? 'black' : 'white')} resigned — ${cap(result.winner)} wins.`;
    else if (result.type === 'timeout') statusLine.textContent = `Time's up — ${cap(result.winner)} wins.`;
    else if (result.type === 'draw') statusLine.textContent = `Draw (${result.reason}).`;
    showGameOverModal(result);
    reviewBlock.style.display = 'block';
  } else if (drawOffer && drawOffer !== myColor) {
    statusLine.textContent = `${cap(drawOffer)} offers a draw.`;
    showDrawOfferModal();
  } else {
    statusLine.textContent = `${cap(turn === 'w' ? 'white' : 'black')} to move${lastState.inCheck ? ' — check!' : ''}`;
  }

  resignBtn.disabled = !started || !!result || myColor === 'spectator';
  drawBtn.disabled = !started || !!result || myColor === 'spectator';
}

function ratingLabel(profile, delta) {
  if (!profile) return '<span>Guest (unrated)</span>';
  let html = `<span>Rating ${profile.rating}</span>`;
  if (delta && typeof delta.delta === 'number' && delta.delta !== 0) {
    const cls = delta.delta > 0 ? 'delta-up' : 'delta-down';
    const sign = delta.delta > 0 ? '+' : '';
    html += ` <span class="${cls}">${sign}${delta.delta}</span>`;
  }
  return html;
}

function cap(s) { return s ? s[0].toUpperCase() + s.slice(1) : s; }

// ---------- Interaction ----------
function onSquareClick(id) {
  if (!lastState || lastState.result || myColor === 'spectator') return;
  const turnColor = lastState.turn === 'w' ? 'white' : 'black';
  if (turnColor !== myColor) return;

  if (selectedSquare === id) { selectedSquare = null; render(); return; }

  const piece = localChess.get(id);
  if (selectedSquare) {
    const moves = localChess.moves({ square: selectedSquare, verbose: true });
    const target = moves.find((m) => m.to === id);
    if (target) {
      if (target.flags.includes('p')) {
        askPromotion((promo) => sendMove(selectedSquare, id, promo));
      } else {
        sendMove(selectedSquare, id, null);
      }
      selectedSquare = null;
      return;
    }
  }
  selectedSquare = (piece && (piece.color === (myColor === 'white' ? 'w' : 'b'))) ? id : null;
  render();
}

function sendMove(from, to, promotion) {
  socket.emit('move', { from, to, promotion: promotion || undefined });
}

function askPromotion(callback) {
  modalContent.innerHTML = `
    <h2>Promote pawn</h2>
    <p>Choose a piece for your pawn.</p>
    <div class="promo-choices">
      <button data-p="q">♕</button>
      <button data-p="r">♖</button>
      <button data-p="b">♗</button>
      <button data-p="n">♘</button>
    </div>`;
  modalOverlay.style.display = 'flex';
  modalContent.querySelectorAll('button[data-p]').forEach((btn) => {
    btn.addEventListener('click', () => {
      modalOverlay.style.display = 'none';
      callback(btn.dataset.p);
    }, { once: true });
  });
}

function showGameOverModal(result) {
  if (modalContent.dataset.shownFor === JSON.stringify(result)) return;
  modalContent.dataset.shownFor = JSON.stringify(result);
  let title = 'Game over';
  if (result.type === 'checkmate') title = `Checkmate — ${cap(result.winner)} wins`;
  if (result.type === 'resignation') title = `${cap(result.winner)} wins by resignation`;
  if (result.type === 'timeout') title = `${cap(result.winner)} wins on time`;
  if (result.type === 'draw') title = `Draw — ${result.reason}`;
  modalContent.innerHTML = `
    <h2>${title}</h2>
    <p>Good game.</p>
    <div class="modal-actions">
      <button id="rematchBtn" class="btn btn-primary">Rematch</button>
      <button id="closeModalBtn" class="btn btn-ghost">Close</button>
    </div>`;
  modalOverlay.style.display = 'flex';
  document.getElementById('rematchBtn').addEventListener('click', () => {
    socket.emit('rematch');
    modalOverlay.style.display = 'none';
  });
  document.getElementById('closeModalBtn').addEventListener('click', () => {
    modalOverlay.style.display = 'none';
  });
}

let drawOfferShown = false;
function showDrawOfferModal() {
  if (drawOfferShown) return;
  drawOfferShown = true;
  modalContent.innerHTML = `
    <h2>Draw offered</h2>
    <p>Your opponent has offered a draw.</p>
    <div class="modal-actions">
      <button id="acceptDraw" class="btn btn-primary">Accept</button>
      <button id="declineDraw" class="btn btn-ghost">Decline</button>
    </div>`;
  modalOverlay.style.display = 'flex';
  document.getElementById('acceptDraw').addEventListener('click', () => {
    socket.emit('respond-draw', { accept: true });
    modalOverlay.style.display = 'none'; drawOfferShown = false;
  });
  document.getElementById('declineDraw').addEventListener('click', () => {
    socket.emit('respond-draw', { accept: false });
    modalOverlay.style.display = 'none'; drawOfferShown = false;
  });
}

evalToggle.addEventListener('change', () => {
  evalEnabled = evalToggle.checked;
  evalBarWrap.style.display = evalEnabled ? 'flex' : 'none';
  if (evalEnabled) runEval();
  else if (evalTimer) { clearTimeout(evalTimer); stopEval(); }
});

let evalRequestId = 0;
async function runEval() {
  if (!evalEnabled || !lastState) return;
  const myRequest = ++evalRequestId;
  try {
    const fen = lastState.fen;
    const res = await evaluate(fen, { depth: 12 });
    if (myRequest !== evalRequestId || !evalEnabled) return; // stale/cancelled
    const turn = fen.split(' ')[1];
    const whiteCp = toWhiteCp(res, turn);
    paintEvalBar(whiteCp, res.mate);
  } catch { /* engine not ready yet, ignore this tick */ }
  if (evalEnabled) evalTimer = setTimeout(runEval, 600);
}

function paintEvalBar(whiteCp, mate) {
  const pawns = whiteCp / 100;
  // squash into 0-100% white-fill height, clamp extreme values
  const clamped = Math.max(-10, Math.min(10, pawns));
  const pct = 50 + clamped * 5; // each pawn = 5% shift
  evalFill.style.height = `${Math.max(2, Math.min(98, pct))}%`;
  evalLabel.textContent = mate !== null && mate !== undefined
    ? `M${Math.abs(mate)}`
    : (pawns > 0 ? '+' : '') + pawns.toFixed(1);
}

// ---------- Game review ----------
reviewBtn.addEventListener('click', async () => {
  if (!lastState || !lastState.history.length) return;
  reviewBtn.disabled = true;
  reviewProgress.style.display = 'block';
  reviewResults.style.display = 'none';
  reviewProgress.textContent = 'Warming up the engine…';
  try {
    reviewData = await analyzeGame(lastState.history, {
      depth: 12,
      onProgress: (done, total) => { reviewProgress.textContent = `Analyzing position ${done} of ${total}…`; },
    });
    reviewProgress.style.display = 'none';
    reviewResults.style.display = 'block';
    accWhite.textContent = reviewData.accuracy.white + '%';
    accBlack.textContent = reviewData.accuracy.black + '%';
    renderMoveList(lastState.history); // re-render to attach tags
  } catch (err) {
    reviewProgress.textContent = 'Analysis failed — engine may still be loading. Try again.';
    console.error(err);
  } finally {
    reviewBtn.disabled = false;
  }
});

resignBtn.addEventListener('click', () => {
  if (confirm('Resign this game?')) socket.emit('resign');
});
drawBtn.addEventListener('click', () => socket.emit('offer-draw'));

chatForm.addEventListener('submit', (e) => {
  e.preventDefault();
  const msg = chatInput.value.trim();
  if (!msg) return;
  socket.emit('chat', msg);
  chatInput.value = '';
});

socket.on('chat', ({ name, msg, color }) => {
  const div = document.createElement('div');
  div.className = 'msg';
  div.innerHTML = `<strong>${escapeHtml(name)}:</strong> ${escapeHtml(msg)}`;
  chatLog.appendChild(div);
  chatLog.scrollTop = chatLog.scrollHeight;
});

function escapeHtml(s) {
  return s.replace(/[&<>"']/g, (c) => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
}

socket.on('opponent-left', (color) => {
  statusLine.textContent = `${cap(color)} disconnected.`;
});

socket.on('rematch-start', () => {
  drawOfferShown = false;
  modalContent.dataset.shownFor = '';
  modalOverlay.style.display = 'none';
  selectedSquare = null;
  reviewData = null;
  reviewBlock.style.display = 'none';
  reviewResults.style.display = 'none';
});

// ---------- State sync ----------
let boardBuilt = false;
socket.on('state', (state) => {
  const first = !lastState;
  lastState = state;
  localClock = { ...state.clock };
  if (!boardBuilt || first) { buildBoardSkeleton(); boardBuilt = true; }
  render();
  restartClockTicker();
  if (evalEnabled) runEval();
});

socket.on('clock', (clock) => {
  localClock = { ...clock };
});

socket.on('illegal-move', () => {
  selectedSquare = null;
  render();
});

function restartClockTicker() {
  if (clockTickHandle) clearInterval(clockTickHandle);
  let last = Date.now();
  clockTickHandle = setInterval(() => {
    const now = Date.now();
    const delta = now - last;
    last = now;
    if (lastState && lastState.running && !lastState.result) {
      localClock[lastState.running] = Math.max(0, localClock[lastState.running] - delta);
    }
    paintClocks();
  }, 250);
  paintClocks();
}

function paintClocks() {
  if (!lastState) return;
  const oppColor = myColor === 'white' ? 'black' : (myColor === 'black' ? 'white' : 'black');
  const youC = myColor === 'spectator' ? 'white' : myColor;
  const oppC = myColor === 'spectator' ? 'black' : oppColor;

  youClock.textContent = fmt(localClock[youC]);
  opponentClock.textContent = fmt(localClock[oppC]);

  youClock.classList.toggle('active', lastState.running === youC);
  opponentClock.classList.toggle('active', lastState.running === oppC);
  youClock.classList.toggle('low', localClock[youC] < 20000);
  opponentClock.classList.toggle('low', localClock[oppC] < 20000);
}

function fmt(ms) {
  ms = Math.max(0, ms | 0);
  const totalSec = Math.ceil(ms / 1000);
  const m = Math.floor(totalSec / 60);
  const s = totalSec % 60;
  return `${m}:${String(s).padStart(2, '0')}`;
}


#################################################################
### FILE: public/analysis.js
#################################################################

import { Chess } from './vendor/chess.esm.js';
import { evaluate, toWhiteCp } from './stockfish-client.js';

const CLASSIFICATIONS = [
  { key: 'brilliant', label: 'Brilliant', glyph: '!!', className: 'tag-brilliant' },
  { key: 'best', label: 'Best', glyph: '★', className: 'tag-best' },
  { key: 'excellent', label: 'Excellent', glyph: '!', className: 'tag-excellent' },
  { key: 'good', label: 'Good', glyph: '', className: 'tag-good' },
  { key: 'inaccuracy', label: 'Inaccuracy', glyph: '?!', className: 'tag-inaccuracy' },
  { key: 'mistake', label: 'Mistake', glyph: '?', className: 'tag-mistake' },
  { key: 'blunder', label: 'Blunder', glyph: '??', className: 'tag-blunder' },
];

const PIECE_VALUES = { p: 1, n: 3, b: 3, r: 5, q: 9, k: 0 };

function materialFor(board, color) {
  let total = 0;
  for (const row of board) for (const cell of row) if (cell && cell.color === color) total += PIECE_VALUES[cell.type];
  return total;
}

function classify(cpLossForMover, isBestMove, wasSacrifice) {
  if (isBestMove && wasSacrifice) return CLASSIFICATIONS[0]; // brilliant
  if (isBestMove || cpLossForMover <= 4) return CLASSIFICATIONS[1]; // best
  if (cpLossForMover <= 20) return CLASSIFICATIONS[2]; // excellent
  if (cpLossForMover <= 50) return CLASSIFICATIONS[3]; // good
  if (cpLossForMover <= 100) return CLASSIFICATIONS[4]; // inaccuracy
  if (cpLossForMover <= 220) return CLASSIFICATIONS[5]; // mistake
  return CLASSIFICATIONS[6]; // blunder
}

function accuracyFromAvgLoss(avgLoss) {
  const acc = 103.1668 * Math.exp(-0.004354 * avgLoss) - 3.1668;
  return Math.max(0, Math.min(100, acc));
}

// history: chess.js verbose move history (from a completed or in-progress game)
// onProgress(done, total) called as analysis proceeds
export async function analyzeGame(history, { depth = 12, onProgress } = {}) {
  const replay = new Chess();
  const fens = [replay.fen()];
  const moverColors = [];
  for (const m of history) {
    replay.move({ from: m.from, to: m.to, promotion: m.promotion });
    fens.push(replay.fen());
    moverColors.push(m.color); // 'w' | 'b'
  }

  const total = fens.length;
  const whiteCpAt = [];
  const bestMoveAt = [];
  for (let i = 0; i < fens.length; i++) {
    const res = await evaluate(fens[i], { depth });
    const turn = fens[i].split(' ')[1];
    whiteCpAt.push(toWhiteCp(res, turn));
    bestMoveAt.push(res.bestMove || null);
    if (onProgress) onProgress(i + 1, total);
  }

  const perMove = [];
  const boardCache = new Chess();
  for (let i = 0; i < history.length; i++) {
    const mover = moverColors[i]; // 'w' | 'b'
    const before = whiteCpAt[i];
    const after = whiteCpAt[i + 1];
    let cpLoss = mover === 'w' ? (before - after) : (after - before);
    cpLoss = Math.max(0, Math.round(cpLoss));

    // was this move the engine's own top choice at that position?
    const played = history[i].from + history[i].to + (history[i].promotion || '');
    const isBestMove = bestMoveAt[i] && bestMoveAt[i].startsWith(played.slice(0, 4));

    // crude sacrifice heuristic: mover's material dropped by >=3 pts from this move
    boardCache.load(fens[i]);
    const matBefore = materialFor(boardCache.board(), mover);
    boardCache.load(fens[i + 1]);
    const matAfter = materialFor(boardCache.board(), mover);
    const wasSacrifice = (matBefore - matAfter) >= 3;

    const tag = classify(cpLoss, isBestMove, wasSacrifice);
    perMove.push({ ply: i, san: history[i].san, color: mover, cpLoss, tag });
  }

  const whiteLosses = perMove.filter((m) => m.color === 'w').map((m) => m.cpLoss);
  const blackLosses = perMove.filter((m) => m.color === 'b').map((m) => m.cpLoss);
  const avg = (arr) => (arr.length ? arr.reduce((a, b) => a + b, 0) / arr.length : 0);

  return {
    perMove,
    accuracy: {
      white: Math.round(accuracyFromAvgLoss(avg(whiteLosses)) * 10) / 10,
      black: Math.round(accuracyFromAvgLoss(avg(blackLosses)) * 10) / 10,
    },
    tally: {
      white: tallyFor(perMove, 'w'),
      black: tallyFor(perMove, 'b'),
    },
  };
}

function tallyFor(perMove, color) {
  const t = {};
  CLASSIFICATIONS.forEach((c) => (t[c.key] = 0));
  perMove.filter((m) => m.color === color).forEach((m) => t[m.tag.key]++);
  return t;
}

export { CLASSIFICATIONS };


#################################################################
### FILE: public/stockfish-client.js
#################################################################

// Thin wrapper around the Stockfish 18 (lite, single-threaded) Web Worker.
// Provides: evaluate(fen, {depth, movetime}) -> { cp, mate, bestMove }

let worker = null;
let ready = false;
let readyWaiters = [];
let pending = null; // { resolve, bestLine }

function ensureWorker() {
  if (worker) return;
  worker = new Worker('/vendor/stockfish/stockfish-18-lite-single.js');
  worker.onmessage = (e) => {
    const line = typeof e.data === 'string' ? e.data : (e.data && e.data.data) || '';
    handleLine(line);
  };
  worker.onerror = (e) => {
    console.error('Stockfish worker error:', e.message || e);
  };
  worker.postMessage('uci');
  worker.postMessage('setoption name Threads value 1');
  worker.postMessage('isready');
}

let lastInfo = null;

function handleLine(line) {
  if (!line) return;
  if (line === 'readyok') {
    ready = true;
    readyWaiters.forEach((r) => r());
    readyWaiters = [];
    return;
  }
  if (line.startsWith('info') && line.includes('score')) {
    lastInfo = parseInfo(line);
  }
  if (line.startsWith('bestmove')) {
    if (pending) {
      const parts = line.split(' ');
      const bestMove = parts[1];
      const result = lastInfo ? { ...lastInfo, bestMove } : { cp: 0, mate: null, bestMove };
      const { resolve } = pending;
      pending = null;
      resolve(result);
    }
  }
}

function parseInfo(line) {
  const cpMatch = line.match(/score cp (-?\d+)/);
  const mateMatch = line.match(/score mate (-?\d+)/);
  const pvMatch = line.match(/ pv (.+)$/);
  return {
    cp: cpMatch ? parseInt(cpMatch[1], 10) : null,
    mate: mateMatch ? parseInt(mateMatch[1], 10) : null,
    pv: pvMatch ? pvMatch[1].split(' ') : [],
  };
}

function whenReady() {
  ensureWorker();
  if (ready) return Promise.resolve();
  return new Promise((resolve) => readyWaiters.push(resolve));
}

// Evaluate a FEN. Returns a promise resolving to
// { cp, mate, bestMove, pv } where cp/mate are from the perspective of
// the side to move in that FEN (standard UCI convention).
export async function evaluate(fen, { depth = 12, movetime = null } = {}) {
  await whenReady();
  return new Promise((resolve) => {
    lastInfo = null;
    pending = { resolve };
    worker.postMessage('position fen ' + fen);
    worker.postMessage(movetime ? `go movetime ${movetime}` : `go depth ${depth}`);
  });
}

export function stop() {
  if (worker) worker.postMessage('stop');
}

export function terminate() {
  if (worker) { worker.postMessage('quit'); worker.terminate(); worker = null; ready = false; }
}

// Normalize a score to centipawns from White's perspective, given whose turn it is.
export function toWhiteCp({ cp, mate }, turn /* 'w' | 'b' */) {
  if (mate !== null && mate !== undefined) {
    const sign = mate > 0 ? 1 : -1;
    const val = sign * (100000 - Math.abs(mate)); // huge value, mate-in-N ordering preserved
    return turn === 'w' ? val : -val;
  }
  return turn === 'w' ? cp : -cp;
}


#################################################################
### FILE: public/vendor/chess.esm.js
#################################################################

// @generated by Peggy 4.2.0.
//
// https://peggyjs.org/



  function rootNode(comment) {
  	return comment !== null ? { comment, variations: [] } : { variations: []}
  }

  function node(move, suffix, nag, comment, variations) {
  	const node = { move, variations };

    if (suffix) {
    	node.suffix = suffix;
    }

    if (nag) {
    	node.nag = nag;
    }

    if (comment !== null) {
    	node.comment = comment;
    }

    return node
  }

  function lineToTree(...nodes) {
  	const [root, ...rest] = nodes;

    let parent = root;

    for (const child of rest) {
    	if (child !== null) {
        	parent.variations = [child, ...child.variations];
            child.variations = [];
            parent = child;
        }
    }

  	return root
  }

  function pgn(headers, game) {
  	if (game.marker && game.marker.comment) {
    	let node = game.root;
        while (true) {
        	const next = node.variations[0];
            if (!next) {
            	node.comment = game.marker.comment;
            	break
            }
            node = next;
        }
    }

  	return {
    	headers,
        root: game.root,
        result: (game.marker && game.marker.result) ?? undefined
    }
  }

function peg$subclass(child, parent) {
  function C() { this.constructor = child; }
  C.prototype = parent.prototype;
  child.prototype = new C();
}

function peg$SyntaxError(message, expected, found, location) {
  var self = Error.call(this, message);
  // istanbul ignore next Check is a necessary evil to support older environments
  if (Object.setPrototypeOf) {
    Object.setPrototypeOf(self, peg$SyntaxError.prototype);
  }
  self.expected = expected;
  self.found = found;
  self.location = location;
  self.name = "SyntaxError";
  return self;
}

peg$subclass(peg$SyntaxError, Error);

function peg$padEnd(str, targetLength, padString) {
  padString = padString || " ";
  if (str.length > targetLength) { return str; }
  targetLength -= str.length;
  padString += padString.repeat(targetLength);
  return str + padString.slice(0, targetLength);
}

peg$SyntaxError.prototype.format = function(sources) {
  var str = "Error: " + this.message;
  if (this.location) {
    var src = null;
    var k;
    for (k = 0; k < sources.length; k++) {
      if (sources[k].source === this.location.source) {
        src = sources[k].text.split(/\r\n|\n|\r/g);
        break;
      }
    }
    var s = this.location.start;
    var offset_s = (this.location.source && (typeof this.location.source.offset === "function"))
      ? this.location.source.offset(s)
      : s;
    var loc = this.location.source + ":" + offset_s.line + ":" + offset_s.column;
    if (src) {
      var e = this.location.end;
      var filler = peg$padEnd("", offset_s.line.toString().length, ' ');
      var line = src[s.line - 1];
      var last = s.line === e.line ? e.column : line.length + 1;
      var hatLen = (last - s.column) || 1;
      str += "\n --> " + loc + "\n"
          + filler + " |\n"
          + offset_s.line + " | " + line + "\n"
          + filler + " | " + peg$padEnd("", s.column - 1, ' ')
          + peg$padEnd("", hatLen, "^");
    } else {
      str += "\n at " + loc;
    }
  }
  return str;
};

peg$SyntaxError.buildMessage = function(expected, found) {
  var DESCRIBE_EXPECTATION_FNS = {
    literal: function(expectation) {
      return "\"" + literalEscape(expectation.text) + "\"";
    },

    class: function(expectation) {
      var escapedParts = expectation.parts.map(function(part) {
        return Array.isArray(part)
          ? classEscape(part[0]) + "-" + classEscape(part[1])
          : classEscape(part);
      });

      return "[" + (expectation.inverted ? "^" : "") + escapedParts.join("") + "]";
    },

    any: function() {
      return "any character";
    },

    end: function() {
      return "end of input";
    },

    other: function(expectation) {
      return expectation.description;
    }
  };

  function hex(ch) {
    return ch.charCodeAt(0).toString(16).toUpperCase();
  }

  function literalEscape(s) {
    return s
      .replace(/\\/g, "\\\\")
      .replace(/"/g,  "\\\"")
      .replace(/\0/g, "\\0")
      .replace(/\t/g, "\\t")
      .replace(/\n/g, "\\n")
      .replace(/\r/g, "\\r")
      .replace(/[\x00-\x0F]/g,          function(ch) { return "\\x0" + hex(ch); })
      .replace(/[\x10-\x1F\x7F-\x9F]/g, function(ch) { return "\\x"  + hex(ch); });
  }

  function classEscape(s) {
    return s
      .replace(/\\/g, "\\\\")
      .replace(/\]/g, "\\]")
      .replace(/\^/g, "\\^")
      .replace(/-/g,  "\\-")
      .replace(/\0/g, "\\0")
      .replace(/\t/g, "\\t")
      .replace(/\n/g, "\\n")
      .replace(/\r/g, "\\r")
      .replace(/[\x00-\x0F]/g,          function(ch) { return "\\x0" + hex(ch); })
      .replace(/[\x10-\x1F\x7F-\x9F]/g, function(ch) { return "\\x"  + hex(ch); });
  }

  function describeExpectation(expectation) {
    return DESCRIBE_EXPECTATION_FNS[expectation.type](expectation);
  }

  function describeExpected(expected) {
    var descriptions = expected.map(describeExpectation);
    var i, j;

    descriptions.sort();

    if (descriptions.length > 0) {
      for (i = 1, j = 1; i < descriptions.length; i++) {
        if (descriptions[i - 1] !== descriptions[i]) {
          descriptions[j] = descriptions[i];
          j++;
        }
      }
      descriptions.length = j;
    }

    switch (descriptions.length) {
      case 1:
        return descriptions[0];

      case 2:
        return descriptions[0] + " or " + descriptions[1];

      default:
        return descriptions.slice(0, -1).join(", ")
          + ", or "
          + descriptions[descriptions.length - 1];
    }
  }

  function describeFound(found) {
    return found ? "\"" + literalEscape(found) + "\"" : "end of input";
  }

  return "Expected " + describeExpected(expected) + " but " + describeFound(found) + " found.";
};

function peg$parse(input, options) {
  options = options !== undefined ? options : {};

  var peg$FAILED = {};
  var peg$source = options.grammarSource;

  var peg$startRuleFunctions = { pgn: peg$parsepgn };
  var peg$startRuleFunction = peg$parsepgn;

  var peg$c0 = "[";
  var peg$c1 = "\"";
  var peg$c2 = "]";
  var peg$c3 = ".";
  var peg$c4 = "O-O-O";
  var peg$c5 = "O-O";
  var peg$c6 = "0-0-0";
  var peg$c7 = "0-0";
  var peg$c8 = "$";
  var peg$c9 = "{";
  var peg$c10 = "}";
  var peg$c11 = ";";
  var peg$c12 = "(";
  var peg$c13 = ")";
  var peg$c14 = "1-0";
  var peg$c15 = "0-1";
  var peg$c16 = "1/2-1/2";
  var peg$c17 = "*";

  var peg$r0 = /^[a-zA-Z]/;
  var peg$r1 = /^[^"]/;
  var peg$r2 = /^[0-9]/;
  var peg$r3 = /^[.]/;
  var peg$r4 = /^[a-zA-Z1-8\-=]/;
  var peg$r5 = /^[+#]/;
  var peg$r6 = /^[!?]/;
  var peg$r7 = /^[^}]/;
  var peg$r8 = /^[^\r\n]/;
  var peg$r9 = /^[ \t\r\n]/;

  var peg$e0 = peg$otherExpectation("tag pair");
  var peg$e1 = peg$literalExpectation("[", false);
  var peg$e2 = peg$literalExpectation("\"", false);
  var peg$e3 = peg$literalExpectation("]", false);
  var peg$e4 = peg$otherExpectation("tag name");
  var peg$e5 = peg$classExpectation([["a", "z"], ["A", "Z"]], false, false);
  var peg$e6 = peg$otherExpectation("tag value");
  var peg$e7 = peg$classExpectation(["\""], true, false);
  var peg$e8 = peg$otherExpectation("move number");
  var peg$e9 = peg$classExpectation([["0", "9"]], false, false);
  var peg$e10 = peg$literalExpectation(".", false);
  var peg$e11 = peg$classExpectation(["."], false, false);
  var peg$e12 = peg$otherExpectation("standard algebraic notation");
  var peg$e13 = peg$literalExpectation("O-O-O", false);
  var peg$e14 = peg$literalExpectation("O-O", false);
  var peg$e15 = peg$literalExpectation("0-0-0", false);
  var peg$e16 = peg$literalExpectation("0-0", false);
  var peg$e17 = peg$classExpectation([["a", "z"], ["A", "Z"], ["1", "8"], "-", "="], false, false);
  var peg$e18 = peg$classExpectation(["+", "#"], false, false);
  var peg$e19 = peg$otherExpectation("suffix annotation");
  var peg$e20 = peg$classExpectation(["!", "?"], false, false);
  var peg$e21 = peg$otherExpectation("NAG");
  var peg$e22 = peg$literalExpectation("$", false);
  var peg$e23 = peg$otherExpectation("brace comment");
  var peg$e24 = peg$literalExpectation("{", false);
  var peg$e25 = peg$classExpectation(["}"], true, false);
  var peg$e26 = peg$literalExpectation("}", false);
  var peg$e27 = peg$otherExpectation("rest of line comment");
  var peg$e28 = peg$literalExpectation(";", false);
  var peg$e29 = peg$classExpectation(["\r", "\n"], true, false);
  var peg$e30 = peg$otherExpectation("variation");
  var peg$e31 = peg$literalExpectation("(", false);
  var peg$e32 = peg$literalExpectation(")", false);
  var peg$e33 = peg$otherExpectation("game termination marker");
  var peg$e34 = peg$literalExpectation("1-0", false);
  var peg$e35 = peg$literalExpectation("0-1", false);
  var peg$e36 = peg$literalExpectation("1/2-1/2", false);
  var peg$e37 = peg$literalExpectation("*", false);
  var peg$e38 = peg$otherExpectation("whitespace");
  var peg$e39 = peg$classExpectation([" ", "\t", "\r", "\n"], false, false);

  var peg$f0 = function(headers, game) { return pgn(headers, game) };
  var peg$f1 = function(tagPairs) { return Object.fromEntries(tagPairs) };
  var peg$f2 = function(tagName, tagValue) { return [tagName, tagValue] };
  var peg$f3 = function(root, marker) { return { root, marker} };
  var peg$f4 = function(comment, moves) { return lineToTree(rootNode(comment), ...moves.flat()) };
  var peg$f5 = function(san, suffix, nag, comment, variations) { return node(san, suffix, nag, comment, variations) };
  var peg$f6 = function(nag) { return nag };
  var peg$f7 = function(comment) { return comment.replace(/[\r\n]+/g, " ") };
  var peg$f8 = function(comment) { return comment.trim() };
  var peg$f9 = function(line) { return line };
  var peg$f10 = function(result, comment) { return { result, comment } };
  var peg$currPos = options.peg$currPos | 0;
  var peg$posDetailsCache = [{ line: 1, column: 1 }];
  var peg$maxFailPos = peg$currPos;
  var peg$maxFailExpected = options.peg$maxFailExpected || [];
  var peg$silentFails = options.peg$silentFails | 0;

  var peg$result;

  if (options.startRule) {
    if (!(options.startRule in peg$startRuleFunctions)) {
      throw new Error("Can't start parsing from rule \"" + options.startRule + "\".");
    }

    peg$startRuleFunction = peg$startRuleFunctions[options.startRule];
  }

  function peg$literalExpectation(text, ignoreCase) {
    return { type: "literal", text: text, ignoreCase: ignoreCase };
  }

  function peg$classExpectation(parts, inverted, ignoreCase) {
    return { type: "class", parts: parts, inverted: inverted, ignoreCase: ignoreCase };
  }

  function peg$endExpectation() {
    return { type: "end" };
  }

  function peg$otherExpectation(description) {
    return { type: "other", description: description };
  }

  function peg$computePosDetails(pos) {
    var details = peg$posDetailsCache[pos];
    var p;

    if (details) {
      return details;
    } else {
      if (pos >= peg$posDetailsCache.length) {
        p = peg$posDetailsCache.length - 1;
      } else {
        p = pos;
        while (!peg$posDetailsCache[--p]) {}
      }

      details = peg$posDetailsCache[p];
      details = {
        line: details.line,
        column: details.column
      };

      while (p < pos) {
        if (input.charCodeAt(p) === 10) {
          details.line++;
          details.column = 1;
        } else {
          details.column++;
        }

        p++;
      }

      peg$posDetailsCache[pos] = details;

      return details;
    }
  }

  function peg$computeLocation(startPos, endPos, offset) {
    var startPosDetails = peg$computePosDetails(startPos);
    var endPosDetails = peg$computePosDetails(endPos);

    var res = {
      source: peg$source,
      start: {
        offset: startPos,
        line: startPosDetails.line,
        column: startPosDetails.column
      },
      end: {
        offset: endPos,
        line: endPosDetails.line,
        column: endPosDetails.column
      }
    };
    return res;
  }

  function peg$fail(expected) {
    if (peg$currPos < peg$maxFailPos) { return; }

    if (peg$currPos > peg$maxFailPos) {
      peg$maxFailPos = peg$currPos;
      peg$maxFailExpected = [];
    }

    peg$maxFailExpected.push(expected);
  }

  function peg$buildStructuredError(expected, found, location) {
    return new peg$SyntaxError(
      peg$SyntaxError.buildMessage(expected, found),
      expected,
      found,
      location
    );
  }

  function peg$parsepgn() {
    var s0, s1, s2;

    s0 = peg$currPos;
    s1 = peg$parsetagPairSection();
    s2 = peg$parsemoveTextSection();
    s0 = peg$f0(s1, s2);

    return s0;
  }

  function peg$parsetagPairSection() {
    var s0, s1, s2;

    s0 = peg$currPos;
    s1 = [];
    s2 = peg$parsetagPair();
    while (s2 !== peg$FAILED) {
      s1.push(s2);
      s2 = peg$parsetagPair();
    }
    s2 = peg$parse_();
    s0 = peg$f1(s1);

    return s0;
  }

  function peg$parsetagPair() {
    var s0, s2, s4, s6, s7, s8, s10;

    peg$silentFails++;
    s0 = peg$currPos;
    peg$parse_();
    if (input.charCodeAt(peg$currPos) === 91) {
      s2 = peg$c0;
      peg$currPos++;
    } else {
      s2 = peg$FAILED;
      if (peg$silentFails === 0) { peg$fail(peg$e1); }
    }
    if (s2 !== peg$FAILED) {
      peg$parse_();
      s4 = peg$parsetagName();
      if (s4 !== peg$FAILED) {
        peg$parse_();
        if (input.charCodeAt(peg$currPos) === 34) {
          s6 = peg$c1;
          peg$currPos++;
        } else {
          s6 = peg$FAILED;
          if (peg$silentFails === 0) { peg$fail(peg$e2); }
        }
        if (s6 !== peg$FAILED) {
          s7 = peg$parsetagValue();
          if (input.charCodeAt(peg$currPos) === 34) {
            s8 = peg$c1;
            peg$currPos++;
          } else {
            s8 = peg$FAILED;
            if (peg$silentFails === 0) { peg$fail(peg$e2); }
          }
          if (s8 !== peg$FAILED) {
            peg$parse_();
            if (input.charCodeAt(peg$currPos) === 93) {
              s10 = peg$c2;
              peg$currPos++;
            } else {
              s10 = peg$FAILED;
              if (peg$silentFails === 0) { peg$fail(peg$e3); }
            }
            if (s10 !== peg$FAILED) {
              s0 = peg$f2(s4, s7);
            } else {
              peg$currPos = s0;
              s0 = peg$FAILED;
            }
          } else {
            peg$currPos = s0;
            s0 = peg$FAILED;
          }
        } else {
          peg$currPos = s0;
          s0 = peg$FAILED;
        }
      } else {
        peg$currPos = s0;
        s0 = peg$FAILED;
      }
    } else {
      peg$currPos = s0;
      s0 = peg$FAILED;
    }
    peg$silentFails--;
    if (s0 === peg$FAILED) {
      if (peg$silentFails === 0) { peg$fail(peg$e0); }
    }

    return s0;
  }

  function peg$parsetagName() {
    var s0, s1, s2;

    peg$silentFails++;
    s0 = peg$currPos;
    s1 = [];
    s2 = input.charAt(peg$currPos);
    if (peg$r0.test(s2)) {
      peg$currPos++;
    } else {
      s2 = peg$FAILED;
      if (peg$silentFails === 0) { peg$fail(peg$e5); }
    }
    if (s2 !== peg$FAILED) {
      while (s2 !== peg$FAILED) {
        s1.push(s2);
        s2 = input.charAt(peg$currPos);
        if (peg$r0.test(s2)) {
          peg$currPos++;
        } else {
          s2 = peg$FAILED;
          if (peg$silentFails === 0) { peg$fail(peg$e5); }
        }
      }
    } else {
      s1 = peg$FAILED;
    }
    if (s1 !== peg$FAILED) {
      s0 = input.substring(s0, peg$currPos);
    } else {
      s0 = s1;
    }
    peg$silentFails--;
    if (s0 === peg$FAILED) {
      s1 = peg$FAILED;
      if (peg$silentFails === 0) { peg$fail(peg$e4); }
    }

    return s0;
  }

  function peg$parsetagValue() {
    var s0, s1, s2;

    peg$silentFails++;
    s0 = peg$currPos;
    s1 = [];
    s2 = input.charAt(peg$currPos);
    if (peg$r1.test(s2)) {
      peg$currPos++;
    } else {
      s2 = peg$FAILED;
      if (peg$silentFails === 0) { peg$fail(peg$e7); }
    }
    while (s2 !== peg$FAILED) {
      s1.push(s2);
      s2 = input.charAt(peg$currPos);
      if (peg$r1.test(s2)) {
        peg$currPos++;
      } else {
        s2 = peg$FAILED;
        if (peg$silentFails === 0) { peg$fail(peg$e7); }
      }
    }
    s0 = input.substring(s0, peg$currPos);
    peg$silentFails--;
    s1 = peg$FAILED;
    if (peg$silentFails === 0) { peg$fail(peg$e6); }

    return s0;
  }

  function peg$parsemoveTextSection() {
    var s0, s1, s3;

    s0 = peg$currPos;
    s1 = peg$parseline();
    peg$parse_();
    s3 = peg$parsegameTerminationMarker();
    if (s3 === peg$FAILED) {
      s3 = null;
    }
    peg$parse_();
    s0 = peg$f3(s1, s3);

    return s0;
  }

  function peg$parseline() {
    var s0, s1, s2, s3;

    s0 = peg$currPos;
    s1 = peg$parsecomment();
    if (s1 === peg$FAILED) {
      s1 = null;
    }
    s2 = [];
    s3 = peg$parsemove();
    while (s3 !== peg$FAILED) {
      s2.push(s3);
      s3 = peg$parsemove();
    }
    s0 = peg$f4(s1, s2);

    return s0;
  }

  function peg$parsemove() {
    var s0, s4, s5, s6, s7, s8, s9, s10;

    s0 = peg$currPos;
    peg$parse_();
    peg$parsemoveNumber();
    peg$parse_();
    s4 = peg$parsesan();
    if (s4 !== peg$FAILED) {
      s5 = peg$parsesuffixAnnotation();
      if (s5 === peg$FAILED) {
        s5 = null;
      }
      s6 = [];
      s7 = peg$parsenag();
      while (s7 !== peg$FAILED) {
        s6.push(s7);
        s7 = peg$parsenag();
      }
      s7 = peg$parse_();
      s8 = peg$parsecomment();
      if (s8 === peg$FAILED) {
        s8 = null;
      }
      s9 = [];
      s10 = peg$parsevariation();
      while (s10 !== peg$FAILED) {
        s9.push(s10);
        s10 = peg$parsevariation();
      }
      s0 = peg$f5(s4, s5, s6, s8, s9);
    } else {
      peg$currPos = s0;
      s0 = peg$FAILED;
    }

    return s0;
  }

  function peg$parsemoveNumber() {
    var s0, s1, s2, s3, s4, s5;

    peg$silentFails++;
    s0 = peg$currPos;
    s1 = [];
    s2 = input.charAt(peg$currPos);
    if (peg$r2.test(s2)) {
      peg$currPos++;
    } else {
      s2 = peg$FAILED;
      if (peg$silentFails === 0) { peg$fail(peg$e9); }
    }
    while (s2 !== peg$FAILED) {
      s1.push(s2);
      s2 = input.charAt(peg$currPos);
      if (peg$r2.test(s2)) {
        peg$currPos++;
      } else {
        s2 = peg$FAILED;
        if (peg$silentFails === 0) { peg$fail(peg$e9); }
      }
    }
    if (input.charCodeAt(peg$currPos) === 46) {
      s2 = peg$c3;
      peg$currPos++;
    } else {
      s2 = peg$FAILED;
      if (peg$silentFails === 0) { peg$fail(peg$e10); }
    }
    if (s2 !== peg$FAILED) {
      s3 = peg$parse_();
      s4 = [];
      s5 = input.charAt(peg$currPos);
      if (peg$r3.test(s5)) {
        peg$currPos++;
      } else {
        s5 = peg$FAILED;
        if (peg$silentFails === 0) { peg$fail(peg$e11); }
      }
      while (s5 !== peg$FAILED) {
        s4.push(s5);
        s5 = input.charAt(peg$currPos);
        if (peg$r3.test(s5)) {
          peg$currPos++;
        } else {
          s5 = peg$FAILED;
          if (peg$silentFails === 0) { peg$fail(peg$e11); }
        }
      }
      s1 = [s1, s2, s3, s4];
      s0 = s1;
    } else {
      peg$currPos = s0;
      s0 = peg$FAILED;
    }
    peg$silentFails--;
    if (s0 === peg$FAILED) {
      s1 = peg$FAILED;
      if (peg$silentFails === 0) { peg$fail(peg$e8); }
    }

    return s0;
  }

  function peg$parsesan() {
    var s0, s1, s2, s3, s4, s5;

    peg$silentFails++;
    s0 = peg$currPos;
    s1 = peg$currPos;
    if (input.substr(peg$currPos, 5) === peg$c4) {
      s2 = peg$c4;
      peg$currPos += 5;
    } else {
      s2 = peg$FAILED;
      if (peg$silentFails === 0) { peg$fail(peg$e13); }
    }
    if (s2 === peg$FAILED) {
      if (input.substr(peg$currPos, 3) === peg$c5) {
        s2 = peg$c5;
        peg$currPos += 3;
      } else {
        s2 = peg$FAILED;
        if (peg$silentFails === 0) { peg$fail(peg$e14); }
      }
      if (s2 === peg$FAILED) {
        if (input.substr(peg$currPos, 5) === peg$c6) {
          s2 = peg$c6;
          peg$currPos += 5;
        } else {
          s2 = peg$FAILED;
          if (peg$silentFails === 0) { peg$fail(peg$e15); }
        }
        if (s2 === peg$FAILED) {
          if (input.substr(peg$currPos, 3) === peg$c7) {
            s2 = peg$c7;
            peg$currPos += 3;
          } else {
            s2 = peg$FAILED;
            if (peg$silentFails === 0) { peg$fail(peg$e16); }
          }
          if (s2 === peg$FAILED) {
            s2 = peg$currPos;
            s3 = input.charAt(peg$currPos);
            if (peg$r0.test(s3)) {
              peg$currPos++;
            } else {
              s3 = peg$FAILED;
              if (peg$silentFails === 0) { peg$fail(peg$e5); }
            }
            if (s3 !== peg$FAILED) {
              s4 = [];
              s5 = input.charAt(peg$currPos);
              if (peg$r4.test(s5)) {
                peg$currPos++;
              } else {
                s5 = peg$FAILED;
                if (peg$silentFails === 0) { peg$fail(peg$e17); }
              }
              if (s5 !== peg$FAILED) {
                while (s5 !== peg$FAILED) {
                  s4.push(s5);
                  s5 = input.charAt(peg$currPos);
                  if (peg$r4.test(s5)) {
                    peg$currPos++;
                  } else {
                    s5 = peg$FAILED;
                    if (peg$silentFails === 0) { peg$fail(peg$e17); }
                  }
                }
              } else {
                s4 = peg$FAILED;
              }
              if (s4 !== peg$FAILED) {
                s3 = [s3, s4];
                s2 = s3;
              } else {
                peg$currPos = s2;
                s2 = peg$FAILED;
              }
            } else {
              peg$currPos = s2;
              s2 = peg$FAILED;
            }
          }
        }
      }
    }
    if (s2 !== peg$FAILED) {
      s3 = input.charAt(peg$currPos);
      if (peg$r5.test(s3)) {
        peg$currPos++;
      } else {
        s3 = peg$FAILED;
        if (peg$silentFails === 0) { peg$fail(peg$e18); }
      }
      if (s3 === peg$FAILED) {
        s3 = null;
      }
      s2 = [s2, s3];
      s1 = s2;
    } else {
      peg$currPos = s1;
      s1 = peg$FAILED;
    }
    if (s1 !== peg$FAILED) {
      s0 = input.substring(s0, peg$currPos);
    } else {
      s0 = s1;
    }
    peg$silentFails--;
    if (s0 === peg$FAILED) {
      s1 = peg$FAILED;
      if (peg$silentFails === 0) { peg$fail(peg$e12); }
    }

    return s0;
  }

  function peg$parsesuffixAnnotation() {
    var s0, s1, s2;

    peg$silentFails++;
    s0 = peg$currPos;
    s1 = [];
    s2 = input.charAt(peg$currPos);
    if (peg$r6.test(s2)) {
      peg$currPos++;
    } else {
      s2 = peg$FAILED;
      if (peg$silentFails === 0) { peg$fail(peg$e20); }
    }
    while (s2 !== peg$FAILED) {
      s1.push(s2);
      if (s1.length >= 2) {
        s2 = peg$FAILED;
      } else {
        s2 = input.charAt(peg$currPos);
        if (peg$r6.test(s2)) {
          peg$currPos++;
        } else {
          s2 = peg$FAILED;
          if (peg$silentFails === 0) { peg$fail(peg$e20); }
        }
      }
    }
    if (s1.length < 1) {
      peg$currPos = s0;
      s0 = peg$FAILED;
    } else {
      s0 = s1;
    }
    peg$silentFails--;
    if (s0 === peg$FAILED) {
      s1 = peg$FAILED;
      if (peg$silentFails === 0) { peg$fail(peg$e19); }
    }

    return s0;
  }

  function peg$parsenag() {
    var s0, s2, s3, s4, s5;

    peg$silentFails++;
    s0 = peg$currPos;
    peg$parse_();
    if (input.charCodeAt(peg$currPos) === 36) {
      s2 = peg$c8;
      peg$currPos++;
    } else {
      s2 = peg$FAILED;
      if (peg$silentFails === 0) { peg$fail(peg$e22); }
    }
    if (s2 !== peg$FAILED) {
      s3 = peg$currPos;
      s4 = [];
      s5 = input.charAt(peg$currPos);
      if (peg$r2.test(s5)) {
        peg$currPos++;
      } else {
        s5 = peg$FAILED;
        if (peg$silentFails === 0) { peg$fail(peg$e9); }
      }
      if (s5 !== peg$FAILED) {
        while (s5 !== peg$FAILED) {
          s4.push(s5);
          s5 = input.charAt(peg$currPos);
          if (peg$r2.test(s5)) {
            peg$currPos++;
          } else {
            s5 = peg$FAILED;
            if (peg$silentFails === 0) { peg$fail(peg$e9); }
          }
        }
      } else {
        s4 = peg$FAILED;
      }
      if (s4 !== peg$FAILED) {
        s3 = input.substring(s3, peg$currPos);
      } else {
        s3 = s4;
      }
      if (s3 !== peg$FAILED) {
        s0 = peg$f6(s3);
      } else {
        peg$currPos = s0;
        s0 = peg$FAILED;
      }
    } else {
      peg$currPos = s0;
      s0 = peg$FAILED;
    }
    peg$silentFails--;
    if (s0 === peg$FAILED) {
      if (peg$silentFails === 0) { peg$fail(peg$e21); }
    }

    return s0;
  }

  function peg$parsecomment() {
    var s0;

    s0 = peg$parsebraceComment();
    if (s0 === peg$FAILED) {
      s0 = peg$parserestOfLineComment();
    }

    return s0;
  }

  function peg$parsebraceComment() {
    var s0, s1, s2, s3, s4;

    peg$silentFails++;
    s0 = peg$currPos;
    if (input.charCodeAt(peg$currPos) === 123) {
      s1 = peg$c9;
      peg$currPos++;
    } else {
      s1 = peg$FAILED;
      if (peg$silentFails === 0) { peg$fail(peg$e24); }
    }
    if (s1 !== peg$FAILED) {
      s2 = peg$currPos;
      s3 = [];
      s4 = input.charAt(peg$currPos);
      if (peg$r7.test(s4)) {
        peg$currPos++;
      } else {
        s4 = peg$FAILED;
        if (peg$silentFails === 0) { peg$fail(peg$e25); }
      }
      while (s4 !== peg$FAILED) {
        s3.push(s4);
        s4 = input.charAt(peg$currPos);
        if (peg$r7.test(s4)) {
          peg$currPos++;
        } else {
          s4 = peg$FAILED;
          if (peg$silentFails === 0) { peg$fail(peg$e25); }
        }
      }
      s2 = input.substring(s2, peg$currPos);
      if (input.charCodeAt(peg$currPos) === 125) {
        s3 = peg$c10;
        peg$currPos++;
      } else {
        s3 = peg$FAILED;
        if (peg$silentFails === 0) { peg$fail(peg$e26); }
      }
      if (s3 !== peg$FAILED) {
        s0 = peg$f7(s2);
      } else {
        peg$currPos = s0;
        s0 = peg$FAILED;
      }
    } else {
      peg$currPos = s0;
      s0 = peg$FAILED;
    }
    peg$silentFails--;
    if (s0 === peg$FAILED) {
      s1 = peg$FAILED;
      if (peg$silentFails === 0) { peg$fail(peg$e23); }
    }

    return s0;
  }

  function peg$parserestOfLineComment() {
    var s0, s1, s2, s3, s4;

    peg$silentFails++;
    s0 = peg$currPos;
    if (input.charCodeAt(peg$currPos) === 59) {
      s1 = peg$c11;
      peg$currPos++;
    } else {
      s1 = peg$FAILED;
      if (peg$silentFails === 0) { peg$fail(peg$e28); }
    }
    if (s1 !== peg$FAILED) {
      s2 = peg$currPos;
      s3 = [];
      s4 = input.charAt(peg$currPos);
      if (peg$r8.test(s4)) {
        peg$currPos++;
      } else {
        s4 = peg$FAILED;
        if (peg$silentFails === 0) { peg$fail(peg$e29); }
      }
      while (s4 !== peg$FAILED) {
        s3.push(s4);
        s4 = input.charAt(peg$currPos);
        if (peg$r8.test(s4)) {
          peg$currPos++;
        } else {
          s4 = peg$FAILED;
          if (peg$silentFails === 0) { peg$fail(peg$e29); }
        }
      }
      s2 = input.substring(s2, peg$currPos);
      s0 = peg$f8(s2);
    } else {
      peg$currPos = s0;
      s0 = peg$FAILED;
    }
    peg$silentFails--;
    if (s0 === peg$FAILED) {
      s1 = peg$FAILED;
      if (peg$silentFails === 0) { peg$fail(peg$e27); }
    }

    return s0;
  }

  function peg$parsevariation() {
    var s0, s2, s3, s5;

    peg$silentFails++;
    s0 = peg$currPos;
    peg$parse_();
    if (input.charCodeAt(peg$currPos) === 40) {
      s2 = peg$c12;
      peg$currPos++;
    } else {
      s2 = peg$FAILED;
      if (peg$silentFails === 0) { peg$fail(peg$e31); }
    }
    if (s2 !== peg$FAILED) {
      s3 = peg$parseline();
      if (s3 !== peg$FAILED) {
        peg$parse_();
        if (input.charCodeAt(peg$currPos) === 41) {
          s5 = peg$c13;
          peg$currPos++;
        } else {
          s5 = peg$FAILED;
          if (peg$silentFails === 0) { peg$fail(peg$e32); }
        }
        if (s5 !== peg$FAILED) {
          s0 = peg$f9(s3);
        } else {
          peg$currPos = s0;
          s0 = peg$FAILED;
        }
      } else {
        peg$currPos = s0;
        s0 = peg$FAILED;
      }
    } else {
      peg$currPos = s0;
      s0 = peg$FAILED;
    }
    peg$silentFails--;
    if (s0 === peg$FAILED) {
      if (peg$silentFails === 0) { peg$fail(peg$e30); }
    }

    return s0;
  }

  function peg$parsegameTerminationMarker() {
    var s0, s1, s3;

    peg$silentFails++;
    s0 = peg$currPos;
    if (input.substr(peg$currPos, 3) === peg$c14) {
      s1 = peg$c14;
      peg$currPos += 3;
    } else {
      s1 = peg$FAILED;
      if (peg$silentFails === 0) { peg$fail(peg$e34); }
    }
    if (s1 === peg$FAILED) {
      if (input.substr(peg$currPos, 3) === peg$c15) {
        s1 = peg$c15;
        peg$currPos += 3;
      } else {
        s1 = peg$FAILED;
        if (peg$silentFails === 0) { peg$fail(peg$e35); }
      }
      if (s1 === peg$FAILED) {
        if (input.substr(peg$currPos, 7) === peg$c16) {
          s1 = peg$c16;
          peg$currPos += 7;
        } else {
          s1 = peg$FAILED;
          if (peg$silentFails === 0) { peg$fail(peg$e36); }
        }
        if (s1 === peg$FAILED) {
          if (input.charCodeAt(peg$currPos) === 42) {
            s1 = peg$c17;
            peg$currPos++;
          } else {
            s1 = peg$FAILED;
            if (peg$silentFails === 0) { peg$fail(peg$e37); }
          }
        }
      }
    }
    if (s1 !== peg$FAILED) {
      peg$parse_();
      s3 = peg$parsecomment();
      if (s3 === peg$FAILED) {
        s3 = null;
      }
      s0 = peg$f10(s1, s3);
    } else {
      peg$currPos = s0;
      s0 = peg$FAILED;
    }
    peg$silentFails--;
    if (s0 === peg$FAILED) {
      s1 = peg$FAILED;
      if (peg$silentFails === 0) { peg$fail(peg$e33); }
    }

    return s0;
  }

  function peg$parse_() {
    var s0, s1;

    peg$silentFails++;
    s0 = [];
    s1 = input.charAt(peg$currPos);
    if (peg$r9.test(s1)) {
      peg$currPos++;
    } else {
      s1 = peg$FAILED;
      if (peg$silentFails === 0) { peg$fail(peg$e39); }
    }
    while (s1 !== peg$FAILED) {
      s0.push(s1);
      s1 = input.charAt(peg$currPos);
      if (peg$r9.test(s1)) {
        peg$currPos++;
      } else {
        s1 = peg$FAILED;
        if (peg$silentFails === 0) { peg$fail(peg$e39); }
      }
    }
    peg$silentFails--;
    s1 = peg$FAILED;
    if (peg$silentFails === 0) { peg$fail(peg$e38); }

    return s0;
  }

  peg$result = peg$startRuleFunction();

  if (options.peg$library) {
    return /** @type {any} */ ({
      peg$result,
      peg$currPos,
      peg$FAILED,
      peg$maxFailExpected,
      peg$maxFailPos
    });
  }
  if (peg$result !== peg$FAILED && peg$currPos === input.length) {
    return peg$result;
  } else {
    if (peg$result !== peg$FAILED && peg$currPos < input.length) {
      peg$fail(peg$endExpectation());
    }

    throw peg$buildStructuredError(
      peg$maxFailExpected,
      peg$maxFailPos < input.length ? input.charAt(peg$maxFailPos) : null,
      peg$maxFailPos < input.length
        ? peg$computeLocation(peg$maxFailPos, peg$maxFailPos + 1)
        : peg$computeLocation(peg$maxFailPos, peg$maxFailPos)
    );
  }
}

/**
 * @license
 * Copyright (c) 2025, Jeff Hlywa (jhlywa@gmail.com)
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */
const MASK64 = 0xffffffffffffffffn;
function rotl(x, k) {
    return ((x << k) | (x >> (64n - k))) & 0xffffffffffffffffn;
}
function wrappingMul(x, y) {
    return (x * y) & MASK64;
}
// xoroshiro128**
function xoroshiro128(state) {
    return function () {
        let s0 = BigInt(state & MASK64);
        let s1 = BigInt((state >> 64n) & MASK64);
        const result = wrappingMul(rotl(wrappingMul(s0, 5n), 7n), 9n);
        s1 ^= s0;
        s0 = (rotl(s0, 24n) ^ s1 ^ (s1 << 16n)) & MASK64;
        s1 = rotl(s1, 37n);
        state = (s1 << 64n) | s0;
        return result;
    };
}
const rand = xoroshiro128(0xa187eb39cdcaed8f31c4b365b102e01en);
const PIECE_KEYS = Array.from({ length: 2 }, () => Array.from({ length: 6 }, () => Array.from({ length: 128 }, () => rand())));
const EP_KEYS = Array.from({ length: 8 }, () => rand());
const CASTLING_KEYS = Array.from({ length: 16 }, () => rand());
const SIDE_KEY = rand();
const WHITE = 'w';
const BLACK = 'b';
const PAWN = 'p';
const KNIGHT = 'n';
const BISHOP = 'b';
const ROOK = 'r';
const QUEEN = 'q';
const KING = 'k';
const DEFAULT_POSITION = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
class Move {
    color;
    from;
    to;
    piece;
    captured;
    promotion;
    /**
     * @deprecated This field is deprecated and will be removed in version 2.0.0.
     * Please use move descriptor functions instead: `isCapture`, `isPromotion`,
     * `isEnPassant`, `isKingsideCastle`, `isQueensideCastle`, `isCastle`, and
     * `isBigPawn`
     */
    flags;
    san;
    lan;
    before;
    after;
    constructor(chess, internal) {
        const { color, piece, from, to, flags, captured, promotion } = internal;
        const fromAlgebraic = algebraic(from);
        const toAlgebraic = algebraic(to);
        this.color = color;
        this.piece = piece;
        this.from = fromAlgebraic;
        this.to = toAlgebraic;
        /*
         * HACK: The chess['_method']() calls below invoke private methods in the
         * Chess class to generate SAN and FEN. It's a bit of a hack, but makes the
         * code cleaner elsewhere.
         */
        this.san = chess['_moveToSan'](internal, chess['_moves']({ legal: true }));
        this.lan = fromAlgebraic + toAlgebraic;
        this.before = chess.fen();
        // Generate the FEN for the 'after' key
        chess['_makeMove'](internal);
        this.after = chess.fen();
        chess['_undoMove']();
        // Build the text representation of the move flags
        this.flags = '';
        for (const flag in BITS) {
            if (BITS[flag] & flags) {
                this.flags += FLAGS[flag];
            }
        }
        if (captured) {
            this.captured = captured;
        }
        if (promotion) {
            this.promotion = promotion;
            this.lan += promotion;
        }
    }
    isCapture() {
        return this.flags.indexOf(FLAGS['CAPTURE']) > -1;
    }
    isPromotion() {
        return this.flags.indexOf(FLAGS['PROMOTION']) > -1;
    }
    isEnPassant() {
        return this.flags.indexOf(FLAGS['EP_CAPTURE']) > -1;
    }
    isKingsideCastle() {
        return this.flags.indexOf(FLAGS['KSIDE_CASTLE']) > -1;
    }
    isQueensideCastle() {
        return this.flags.indexOf(FLAGS['QSIDE_CASTLE']) > -1;
    }
    isBigPawn() {
        return this.flags.indexOf(FLAGS['BIG_PAWN']) > -1;
    }
}
const EMPTY = -1;
const FLAGS = {
    NORMAL: 'n',
    CAPTURE: 'c',
    BIG_PAWN: 'b',
    EP_CAPTURE: 'e',
    PROMOTION: 'p',
    KSIDE_CASTLE: 'k',
    QSIDE_CASTLE: 'q',
    NULL_MOVE: '-',
};
// prettier-ignore
const SQUARES = [
    'a8', 'b8', 'c8', 'd8', 'e8', 'f8', 'g8', 'h8',
    'a7', 'b7', 'c7', 'd7', 'e7', 'f7', 'g7', 'h7',
    'a6', 'b6', 'c6', 'd6', 'e6', 'f6', 'g6', 'h6',
    'a5', 'b5', 'c5', 'd5', 'e5', 'f5', 'g5', 'h5',
    'a4', 'b4', 'c4', 'd4', 'e4', 'f4', 'g4', 'h4',
    'a3', 'b3', 'c3', 'd3', 'e3', 'f3', 'g3', 'h3',
    'a2', 'b2', 'c2', 'd2', 'e2', 'f2', 'g2', 'h2',
    'a1', 'b1', 'c1', 'd1', 'e1', 'f1', 'g1', 'h1'
];
const BITS = {
    NORMAL: 1,
    CAPTURE: 2,
    BIG_PAWN: 4,
    EP_CAPTURE: 8,
    PROMOTION: 16,
    KSIDE_CASTLE: 32,
    QSIDE_CASTLE: 64,
    NULL_MOVE: 128,
};
/* eslint-disable @typescript-eslint/naming-convention */
// these are required, according to spec
const SEVEN_TAG_ROSTER = {
    Event: '?',
    Site: '?',
    Date: '????.??.??',
    Round: '?',
    White: '?',
    Black: '?',
    Result: '*',
};
/**
 * These nulls are placeholders to fix the order of tags (as they appear in PGN spec); null values will be
 * eliminated in getHeaders()
 */
const SUPLEMENTAL_TAGS = {
    WhiteTitle: null,
    BlackTitle: null,
    WhiteElo: null,
    BlackElo: null,
    WhiteUSCF: null,
    BlackUSCF: null,
    WhiteNA: null,
    BlackNA: null,
    WhiteType: null,
    BlackType: null,
    EventDate: null,
    EventSponsor: null,
    Section: null,
    Stage: null,
    Board: null,
    Opening: null,
    Variation: null,
    SubVariation: null,
    ECO: null,
    NIC: null,
    Time: null,
    UTCTime: null,
    UTCDate: null,
    TimeControl: null,
    SetUp: null,
    FEN: null,
    Termination: null,
    Annotator: null,
    Mode: null,
    PlyCount: null,
};
const HEADER_TEMPLATE = {
    ...SEVEN_TAG_ROSTER,
    ...SUPLEMENTAL_TAGS,
};
/* eslint-enable @typescript-eslint/naming-convention */
/*
 * NOTES ABOUT 0x88 MOVE GENERATION ALGORITHM
 * ----------------------------------------------------------------------------
 * From https://github.com/jhlywa/chess.js/issues/230
 *
 * A lot of people are confused when they first see the internal representation
 * of chess.js. It uses the 0x88 Move Generation Algorithm which internally
 * stores the board as an 8x16 array. This is purely for efficiency but has a
 * couple of interesting benefits:
 *
 * 1. 0x88 offers a very inexpensive "off the board" check. Bitwise AND (&) any
 *    square with 0x88, if the result is non-zero then the square is off the
 *    board. For example, assuming a knight square A8 (0 in 0x88 notation),
 *    there are 8 possible directions in which the knight can move. These
 *    directions are relative to the 8x16 board and are stored in the
 *    PIECE_OFFSETS map. One possible move is A8 - 18 (up one square, and two
 *    squares to the left - which is off the board). 0 - 18 = -18 & 0x88 = 0x88
 *    (because of two-complement representation of -18). The non-zero result
 *    means the square is off the board and the move is illegal. Take the
 *    opposite move (from A8 to C7), 0 + 18 = 18 & 0x88 = 0. A result of zero
 *    means the square is on the board.
 *
 * 2. The relative distance (or difference) between two squares on a 8x16 board
 *    is unique and can be used to inexpensively determine if a piece on a
 *    square can attack any other arbitrary square. For example, let's see if a
 *    pawn on E7 can attack E2. The difference between E7 (20) - E2 (100) is
 *    -80. We add 119 to make the ATTACKS array index non-negative (because the
 *    worst case difference is A8 - H1 = -119). The ATTACKS array contains a
 *    bitmask of pieces that can attack from that distance and direction.
 *    ATTACKS[-80 + 119=39] gives us 24 or 0b11000 in binary. Look at the
 *    PIECE_MASKS map to determine the mask for a given piece type. In our pawn
 *    example, we would check to see if 24 & 0x1 is non-zero, which it is
 *    not. So, naturally, a pawn on E7 can't attack a piece on E2. However, a
 *    rook can since 24 & 0x8 is non-zero. The only thing left to check is that
 *    there are no blocking pieces between E7 and E2. That's where the RAYS
 *    array comes in. It provides an offset (in this case 16) to add to E7 (20)
 *    to check for blocking pieces. E7 (20) + 16 = E6 (36) + 16 = E5 (52) etc.
 */
// prettier-ignore
// eslint-disable-next-line
const Ox88 = {
    a8: 0, b8: 1, c8: 2, d8: 3, e8: 4, f8: 5, g8: 6, h8: 7,
    a7: 16, b7: 17, c7: 18, d7: 19, e7: 20, f7: 21, g7: 22, h7: 23,
    a6: 32, b6: 33, c6: 34, d6: 35, e6: 36, f6: 37, g6: 38, h6: 39,
    a5: 48, b5: 49, c5: 50, d5: 51, e5: 52, f5: 53, g5: 54, h5: 55,
    a4: 64, b4: 65, c4: 66, d4: 67, e4: 68, f4: 69, g4: 70, h4: 71,
    a3: 80, b3: 81, c3: 82, d3: 83, e3: 84, f3: 85, g3: 86, h3: 87,
    a2: 96, b2: 97, c2: 98, d2: 99, e2: 100, f2: 101, g2: 102, h2: 103,
    a1: 112, b1: 113, c1: 114, d1: 115, e1: 116, f1: 117, g1: 118, h1: 119
};
const PAWN_OFFSETS = {
    b: [16, 32, 17, 15],
    w: [-16, -32, -17, -15],
};
const PIECE_OFFSETS = {
    n: [-18, -33, -31, -14, 18, 33, 31, 14],
    b: [-17, -15, 17, 15],
    r: [-16, 1, 16, -1],
    q: [-17, -16, -15, 1, 17, 16, 15, -1],
    k: [-17, -16, -15, 1, 17, 16, 15, -1],
};
// prettier-ignore
const ATTACKS = [
    20, 0, 0, 0, 0, 0, 0, 24, 0, 0, 0, 0, 0, 0, 20, 0,
    0, 20, 0, 0, 0, 0, 0, 24, 0, 0, 0, 0, 0, 20, 0, 0,
    0, 0, 20, 0, 0, 0, 0, 24, 0, 0, 0, 0, 20, 0, 0, 0,
    0, 0, 0, 20, 0, 0, 0, 24, 0, 0, 0, 20, 0, 0, 0, 0,
    0, 0, 0, 0, 20, 0, 0, 24, 0, 0, 20, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 20, 2, 24, 2, 20, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 2, 53, 56, 53, 2, 0, 0, 0, 0, 0, 0,
    24, 24, 24, 24, 24, 24, 56, 0, 56, 24, 24, 24, 24, 24, 24, 0,
    0, 0, 0, 0, 0, 2, 53, 56, 53, 2, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 20, 2, 24, 2, 20, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 20, 0, 0, 24, 0, 0, 20, 0, 0, 0, 0, 0,
    0, 0, 0, 20, 0, 0, 0, 24, 0, 0, 0, 20, 0, 0, 0, 0,
    0, 0, 20, 0, 0, 0, 0, 24, 0, 0, 0, 0, 20, 0, 0, 0,
    0, 20, 0, 0, 0, 0, 0, 24, 0, 0, 0, 0, 0, 20, 0, 0,
    20, 0, 0, 0, 0, 0, 0, 24, 0, 0, 0, 0, 0, 0, 20
];
// prettier-ignore
const RAYS = [
    17, 0, 0, 0, 0, 0, 0, 16, 0, 0, 0, 0, 0, 0, 15, 0,
    0, 17, 0, 0, 0, 0, 0, 16, 0, 0, 0, 0, 0, 15, 0, 0,
    0, 0, 17, 0, 0, 0, 0, 16, 0, 0, 0, 0, 15, 0, 0, 0,
    0, 0, 0, 17, 0, 0, 0, 16, 0, 0, 0, 15, 0, 0, 0, 0,
    0, 0, 0, 0, 17, 0, 0, 16, 0, 0, 15, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 17, 0, 16, 0, 15, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 17, 16, 15, 0, 0, 0, 0, 0, 0, 0,
    1, 1, 1, 1, 1, 1, 1, 0, -1, -1, -1, -1, -1, -1, -1, 0,
    0, 0, 0, 0, 0, 0, -15, -16, -17, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, -15, 0, -16, 0, -17, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, -15, 0, 0, -16, 0, 0, -17, 0, 0, 0, 0, 0,
    0, 0, 0, -15, 0, 0, 0, -16, 0, 0, 0, -17, 0, 0, 0, 0,
    0, 0, -15, 0, 0, 0, 0, -16, 0, 0, 0, 0, -17, 0, 0, 0,
    0, -15, 0, 0, 0, 0, 0, -16, 0, 0, 0, 0, 0, -17, 0, 0,
    -15, 0, 0, 0, 0, 0, 0, -16, 0, 0, 0, 0, 0, 0, -17
];
const PIECE_MASKS = { p: 0x1, n: 0x2, b: 0x4, r: 0x8, q: 0x10, k: 0x20 };
const SYMBOLS = 'pnbrqkPNBRQK';
const PROMOTIONS = [KNIGHT, BISHOP, ROOK, QUEEN];
const RANK_1 = 7;
const RANK_2 = 6;
/*
 * const RANK_3 = 5
 * const RANK_4 = 4
 * const RANK_5 = 3
 * const RANK_6 = 2
 */
const RANK_7 = 1;
const RANK_8 = 0;
const SIDES = {
    [KING]: BITS.KSIDE_CASTLE,
    [QUEEN]: BITS.QSIDE_CASTLE,
};
const ROOKS = {
    w: [
        { square: Ox88.a1, flag: BITS.QSIDE_CASTLE },
        { square: Ox88.h1, flag: BITS.KSIDE_CASTLE },
    ],
    b: [
        { square: Ox88.a8, flag: BITS.QSIDE_CASTLE },
        { square: Ox88.h8, flag: BITS.KSIDE_CASTLE },
    ],
};
const SECOND_RANK = { b: RANK_7, w: RANK_2 };
const SAN_NULLMOVE = '--';
// Extracts the zero-based rank of an 0x88 square.
function rank(square) {
    return square >> 4;
}
// Extracts the zero-based file of an 0x88 square.
function file(square) {
    return square & 0xf;
}
function isDigit(c) {
    return '0123456789'.indexOf(c) !== -1;
}
// Converts a 0x88 square to algebraic notation.
function algebraic(square) {
    const f = file(square);
    const r = rank(square);
    return ('abcdefgh'.substring(f, f + 1) +
        '87654321'.substring(r, r + 1));
}
function swapColor(color) {
    return color === WHITE ? BLACK : WHITE;
}
function validateFen(fen) {
    // 1st criterion: 6 space-seperated fields?
    const tokens = fen.split(/\s+/);
    if (tokens.length !== 6) {
        return {
            ok: false,
            error: 'Invalid FEN: must contain six space-delimited fields',
        };
    }
    // 2nd criterion: move number field is a integer value > 0?
    const moveNumber = parseInt(tokens[5], 10);
    if (isNaN(moveNumber) || moveNumber <= 0) {
        return {
            ok: false,
            error: 'Invalid FEN: move number must be a positive integer',
        };
    }
    // 3rd criterion: half move counter is an integer >= 0?
    const halfMoves = parseInt(tokens[4], 10);
    if (isNaN(halfMoves) || halfMoves < 0) {
        return {
            ok: false,
            error: 'Invalid FEN: half move counter number must be a non-negative integer',
        };
    }
    // 4th criterion: 4th field is a valid e.p.-string?
    if (!/^(-|[abcdefgh][36])$/.test(tokens[3])) {
        return { ok: false, error: 'Invalid FEN: en-passant square is invalid' };
    }
    // 5th criterion: 3th field is a valid castle-string?
    if (/[^kKqQ-]/.test(tokens[2])) {
        return { ok: false, error: 'Invalid FEN: castling availability is invalid' };
    }
    // 6th criterion: 2nd field is "w" (white) or "b" (black)?
    if (!/^(w|b)$/.test(tokens[1])) {
        return { ok: false, error: 'Invalid FEN: side-to-move is invalid' };
    }
    // 7th criterion: 1st field contains 8 rows?
    const rows = tokens[0].split('/');
    if (rows.length !== 8) {
        return {
            ok: false,
            error: "Invalid FEN: piece data does not contain 8 '/'-delimited rows",
        };
    }
    // 8th criterion: every row is valid?
    for (let i = 0; i < rows.length; i++) {
        // check for right sum of fields AND not two numbers in succession
        let sumFields = 0;
        let previousWasNumber = false;
        for (let k = 0; k < rows[i].length; k++) {
            if (isDigit(rows[i][k])) {
                if (previousWasNumber) {
                    return {
                        ok: false,
                        error: 'Invalid FEN: piece data is invalid (consecutive number)',
                    };
                }
                sumFields += parseInt(rows[i][k], 10);
                previousWasNumber = true;
            }
            else {
                if (!/^[prnbqkPRNBQK]$/.test(rows[i][k])) {
                    return {
                        ok: false,
                        error: 'Invalid FEN: piece data is invalid (invalid piece)',
                    };
                }
                sumFields += 1;
                previousWasNumber = false;
            }
        }
        if (sumFields !== 8) {
            return {
                ok: false,
                error: 'Invalid FEN: piece data is invalid (too many squares in rank)',
            };
        }
    }
    // 9th criterion: is en-passant square legal?
    if ((tokens[3][1] == '3' && tokens[1] == 'w') ||
        (tokens[3][1] == '6' && tokens[1] == 'b')) {
        return { ok: false, error: 'Invalid FEN: illegal en-passant square' };
    }
    // 10th criterion: does chess position contain exact two kings?
    const kings = [
        { color: 'white', regex: /K/g },
        { color: 'black', regex: /k/g },
    ];
    for (const { color, regex } of kings) {
        if (!regex.test(tokens[0])) {
            return { ok: false, error: `Invalid FEN: missing ${color} king` };
        }
        if ((tokens[0].match(regex) || []).length > 1) {
            return { ok: false, error: `Invalid FEN: too many ${color} kings` };
        }
    }
    // 11th criterion: are any pawns on the first or eighth rows?
    if (Array.from(rows[0] + rows[7]).some((char) => char.toUpperCase() === 'P')) {
        return {
            ok: false,
            error: 'Invalid FEN: some pawns are on the edge rows',
        };
    }
    return { ok: true };
}
// this function is used to uniquely identify ambiguous moves
function getDisambiguator(move, moves) {
    const from = move.from;
    const to = move.to;
    const piece = move.piece;
    let ambiguities = 0;
    let sameRank = 0;
    let sameFile = 0;
    for (let i = 0, len = moves.length; i < len; i++) {
        const ambigFrom = moves[i].from;
        const ambigTo = moves[i].to;
        const ambigPiece = moves[i].piece;
        /*
         * if a move of the same piece type ends on the same to square, we'll need
         * to add a disambiguator to the algebraic notation
         */
        if (piece === ambigPiece && from !== ambigFrom && to === ambigTo) {
            ambiguities++;
            if (rank(from) === rank(ambigFrom)) {
                sameRank++;
            }
            if (file(from) === file(ambigFrom)) {
                sameFile++;
            }
        }
    }
    if (ambiguities > 0) {
        if (sameRank > 0 && sameFile > 0) {
            /*
             * if there exists a similar moving piece on the same rank and file as
             * the move in question, use the square as the disambiguator
             */
            return algebraic(from);
        }
        else if (sameFile > 0) {
            /*
             * if the moving piece rests on the same file, use the rank symbol as the
             * disambiguator
             */
            return algebraic(from).charAt(1);
        }
        else {
            // else use the file symbol
            return algebraic(from).charAt(0);
        }
    }
    return '';
}
function addMove(moves, color, from, to, piece, captured = undefined, flags = BITS.NORMAL) {
    const r = rank(to);
    if (piece === PAWN && (r === RANK_1 || r === RANK_8)) {
        for (let i = 0; i < PROMOTIONS.length; i++) {
            const promotion = PROMOTIONS[i];
            moves.push({
                color,
                from,
                to,
                piece,
                captured,
                promotion,
                flags: flags | BITS.PROMOTION,
            });
        }
    }
    else {
        moves.push({
            color,
            from,
            to,
            piece,
            captured,
            flags,
        });
    }
}
function inferPieceType(san) {
    let pieceType = san.charAt(0);
    if (pieceType >= 'a' && pieceType <= 'h') {
        const matches = san.match(/[a-h]\d.*[a-h]\d/);
        if (matches) {
            return undefined;
        }
        return PAWN;
    }
    pieceType = pieceType.toLowerCase();
    if (pieceType === 'o') {
        return KING;
    }
    return pieceType;
}
// parses all of the decorators out of a SAN string
function strippedSan(move) {
    return move.replace(/=/, '').replace(/[+#]?[?!]*$/, '');
}
class Chess {
    _board = new Array(128);
    _turn = WHITE;
    _header = {};
    _kings = { w: EMPTY, b: EMPTY };
    _epSquare = -1;
    _halfMoves = 0;
    _moveNumber = 0;
    _history = [];
    _comments = {};
    _castling = { w: 0, b: 0 };
    _hash = 0n;
    // tracks number of times a position has been seen for repetition checking
    _positionCount = new Map();
    constructor(fen = DEFAULT_POSITION, { skipValidation = false } = {}) {
        this.load(fen, { skipValidation });
    }
    clear({ preserveHeaders = false } = {}) {
        this._board = new Array(128);
        this._kings = { w: EMPTY, b: EMPTY };
        this._turn = WHITE;
        this._castling = { w: 0, b: 0 };
        this._epSquare = EMPTY;
        this._halfMoves = 0;
        this._moveNumber = 1;
        this._history = [];
        this._comments = {};
        this._header = preserveHeaders ? this._header : { ...HEADER_TEMPLATE };
        this._hash = this._computeHash();
        this._positionCount = new Map();
        /*
         * Delete the SetUp and FEN headers (if preserved), the board is empty and
         * these headers don't make sense in this state. They'll get added later
         * via .load() or .put()
         */
        this._header['SetUp'] = null;
        this._header['FEN'] = null;
    }
    load(fen, { skipValidation = false, preserveHeaders = false } = {}) {
        let tokens = fen.split(/\s+/);
        // append commonly omitted fen tokens
        if (tokens.length >= 2 && tokens.length < 6) {
            const adjustments = ['-', '-', '0', '1'];
            fen = tokens.concat(adjustments.slice(-(6 - tokens.length))).join(' ');
        }
        tokens = fen.split(/\s+/);
        if (!skipValidation) {
            const { ok, error } = validateFen(fen);
            if (!ok) {
                throw new Error(error);
            }
        }
        const position = tokens[0];
        let square = 0;
        this.clear({ preserveHeaders });
        for (let i = 0; i < position.length; i++) {
            const piece = position.charAt(i);
            if (piece === '/') {
                square += 8;
            }
            else if (isDigit(piece)) {
                square += parseInt(piece, 10);
            }
            else {
                const color = piece < 'a' ? WHITE : BLACK;
                this._put({ type: piece.toLowerCase(), color }, algebraic(square));
                square++;
            }
        }
        this._turn = tokens[1];
        if (tokens[2].indexOf('K') > -1) {
            this._castling.w |= BITS.KSIDE_CASTLE;
        }
        if (tokens[2].indexOf('Q') > -1) {
            this._castling.w |= BITS.QSIDE_CASTLE;
        }
        if (tokens[2].indexOf('k') > -1) {
            this._castling.b |= BITS.KSIDE_CASTLE;
        }
        if (tokens[2].indexOf('q') > -1) {
            this._castling.b |= BITS.QSIDE_CASTLE;
        }
        this._epSquare = tokens[3] === '-' ? EMPTY : Ox88[tokens[3]];
        this._halfMoves = parseInt(tokens[4], 10);
        this._moveNumber = parseInt(tokens[5], 10);
        this._hash = this._computeHash();
        this._updateSetup(fen);
        this._incPositionCount();
    }
    fen({ forceEnpassantSquare = false, } = {}) {
        let empty = 0;
        let fen = '';
        for (let i = Ox88.a8; i <= Ox88.h1; i++) {
            if (this._board[i]) {
                if (empty > 0) {
                    fen += empty;
                    empty = 0;
                }
                const { color, type: piece } = this._board[i];
                fen += color === WHITE ? piece.toUpperCase() : piece.toLowerCase();
            }
            else {
                empty++;
            }
            if ((i + 1) & 0x88) {
                if (empty > 0) {
                    fen += empty;
                }
                if (i !== Ox88.h1) {
                    fen += '/';
                }
                empty = 0;
                i += 8;
            }
        }
        let castling = '';
        if (this._castling[WHITE] & BITS.KSIDE_CASTLE) {
            castling += 'K';
        }
        if (this._castling[WHITE] & BITS.QSIDE_CASTLE) {
            castling += 'Q';
        }
        if (this._castling[BLACK] & BITS.KSIDE_CASTLE) {
            castling += 'k';
        }
        if (this._castling[BLACK] & BITS.QSIDE_CASTLE) {
            castling += 'q';
        }
        // do we have an empty castling flag?
        castling = castling || '-';
        let epSquare = '-';
        /*
         * only print the ep square if en passant is a valid move (pawn is present
         * and ep capture is not pinned)
         */
        if (this._epSquare !== EMPTY) {
            if (forceEnpassantSquare) {
                epSquare = algebraic(this._epSquare);
            }
            else {
                const bigPawnSquare = this._epSquare + (this._turn === WHITE ? 16 : -16);
                const squares = [bigPawnSquare + 1, bigPawnSquare - 1];
                for (const square of squares) {
                    // is the square off the board?
                    if (square & 0x88) {
                        continue;
                    }
                    const color = this._turn;
                    // is there a pawn that can capture the epSquare?
                    if (this._board[square]?.color === color &&
                        this._board[square]?.type === PAWN) {
                        // if the pawn makes an ep capture, does it leave its king in check?
                        this._makeMove({
                            color,
                            from: square,
                            to: this._epSquare,
                            piece: PAWN,
                            captured: PAWN,
                            flags: BITS.EP_CAPTURE,
                        });
                        const isLegal = !this._isKingAttacked(color);
                        this._undoMove();
                        // if ep is legal, break and set the ep square in the FEN output
                        if (isLegal) {
                            epSquare = algebraic(this._epSquare);
                            break;
                        }
                    }
                }
            }
        }
        return [
            fen,
            this._turn,
            castling,
            epSquare,
            this._halfMoves,
            this._moveNumber,
        ].join(' ');
    }
    _pieceKey(i) {
        if (!this._board[i]) {
            return 0n;
        }
        const { color, type } = this._board[i];
        const colorIndex = {
            w: 0,
            b: 1,
        }[color];
        const typeIndex = {
            p: 0,
            n: 1,
            b: 2,
            r: 3,
            q: 4,
            k: 5,
        }[type];
        return PIECE_KEYS[colorIndex][typeIndex][i];
    }
    _epKey() {
        return this._epSquare === EMPTY ? 0n : EP_KEYS[this._epSquare & 7];
    }
    _castlingKey() {
        const index = (this._castling.w >> 5) | (this._castling.b >> 3);
        return CASTLING_KEYS[index];
    }
    _computeHash() {
        let hash = 0n;
        for (let i = Ox88.a8; i <= Ox88.h1; i++) {
            // did we run off the end of the board
            if (i & 0x88) {
                i += 7;
                continue;
            }
            if (this._board[i]) {
                hash ^= this._pieceKey(i);
            }
        }
        hash ^= this._epKey();
        hash ^= this._castlingKey();
        if (this._turn === 'b') {
            hash ^= SIDE_KEY;
        }
        return hash;
    }
    /*
     * Called when the initial board setup is changed with put() or remove().
     * modifies the SetUp and FEN properties of the header object. If the FEN
     * is equal to the default position, the SetUp and FEN are deleted the setup
     * is only updated if history.length is zero, ie moves haven't been made.
     */
    _updateSetup(fen) {
        if (this._history.length > 0)
            return;
        if (fen !== DEFAULT_POSITION) {
            this._header['SetUp'] = '1';
            this._header['FEN'] = fen;
        }
        else {
            this._header['SetUp'] = null;
            this._header['FEN'] = null;
        }
    }
    reset() {
        this.load(DEFAULT_POSITION);
    }
    get(square) {
        return this._board[Ox88[square]];
    }
    findPiece(piece) {
        const squares = [];
        for (let i = Ox88.a8; i <= Ox88.h1; i++) {
            // did we run off the end of the board
            if (i & 0x88) {
                i += 7;
                continue;
            }
            // if empty square or wrong color
            if (!this._board[i] || this._board[i]?.color !== piece.color) {
                continue;
            }
            // check if square contains the requested piece
            if (this._board[i].color === piece.color &&
                this._board[i].type === piece.type) {
                squares.push(algebraic(i));
            }
        }
        return squares;
    }
    put({ type, color }, square) {
        if (this._put({ type, color }, square)) {
            this._updateCastlingRights();
            this._updateEnPassantSquare();
            this._updateSetup(this.fen());
            return true;
        }
        return false;
    }
    _set(sq, piece) {
        this._hash ^= this._pieceKey(sq);
        this._board[sq] = piece;
        this._hash ^= this._pieceKey(sq);
    }
    _put({ type, color }, square) {
        // check for piece
        if (SYMBOLS.indexOf(type.toLowerCase()) === -1) {
            return false;
        }
        // check for valid square
        if (!(square in Ox88)) {
            return false;
        }
        const sq = Ox88[square];
        // don't let the user place more than one king
        if (type == KING &&
            !(this._kings[color] == EMPTY || this._kings[color] == sq)) {
            return false;
        }
        const currentPieceOnSquare = this._board[sq];
        // if one of the kings will be replaced by the piece from args, set the `_kings` respective entry to `EMPTY`
        if (currentPieceOnSquare && currentPieceOnSquare.type === KING) {
            this._kings[currentPieceOnSquare.color] = EMPTY;
        }
        this._set(sq, { type: type, color: color });
        if (type === KING) {
            this._kings[color] = sq;
        }
        return true;
    }
    _clear(sq) {
        this._hash ^= this._pieceKey(sq);
        delete this._board[sq];
    }
    remove(square) {
        const piece = this.get(square);
        this._clear(Ox88[square]);
        if (piece && piece.type === KING) {
            this._kings[piece.color] = EMPTY;
        }
        this._updateCastlingRights();
        this._updateEnPassantSquare();
        this._updateSetup(this.fen());
        return piece;
    }
    _updateCastlingRights() {
        this._hash ^= this._castlingKey();
        const whiteKingInPlace = this._board[Ox88.e1]?.type === KING &&
            this._board[Ox88.e1]?.color === WHITE;
        const blackKingInPlace = this._board[Ox88.e8]?.type === KING &&
            this._board[Ox88.e8]?.color === BLACK;
        if (!whiteKingInPlace ||
            this._board[Ox88.a1]?.type !== ROOK ||
            this._board[Ox88.a1]?.color !== WHITE) {
            this._castling.w &= -65;
        }
        if (!whiteKingInPlace ||
            this._board[Ox88.h1]?.type !== ROOK ||
            this._board[Ox88.h1]?.color !== WHITE) {
            this._castling.w &= -33;
        }
        if (!blackKingInPlace ||
            this._board[Ox88.a8]?.type !== ROOK ||
            this._board[Ox88.a8]?.color !== BLACK) {
            this._castling.b &= -65;
        }
        if (!blackKingInPlace ||
            this._board[Ox88.h8]?.type !== ROOK ||
            this._board[Ox88.h8]?.color !== BLACK) {
            this._castling.b &= -33;
        }
        this._hash ^= this._castlingKey();
    }
    _updateEnPassantSquare() {
        if (this._epSquare === EMPTY) {
            return;
        }
        const startSquare = this._epSquare + (this._turn === WHITE ? -16 : 16);
        const currentSquare = this._epSquare + (this._turn === WHITE ? 16 : -16);
        const attackers = [currentSquare + 1, currentSquare - 1];
        if (this._board[startSquare] !== null ||
            this._board[this._epSquare] !== null ||
            this._board[currentSquare]?.color !== swapColor(this._turn) ||
            this._board[currentSquare]?.type !== PAWN) {
            this._hash ^= this._epKey();
            this._epSquare = EMPTY;
            return;
        }
        const canCapture = (square) => !(square & 0x88) &&
            this._board[square]?.color === this._turn &&
            this._board[square]?.type === PAWN;
        if (!attackers.some(canCapture)) {
            this._hash ^= this._epKey();
            this._epSquare = EMPTY;
        }
    }
    _attacked(color, square, verbose) {
        const attackers = [];
        for (let i = Ox88.a8; i <= Ox88.h1; i++) {
            // did we run off the end of the board
            if (i & 0x88) {
                i += 7;
                continue;
            }
            // if empty square or wrong color
            if (this._board[i] === undefined || this._board[i].color !== color) {
                continue;
            }
            const piece = this._board[i];
            const difference = i - square;
            // skip - to/from square are the same
            if (difference === 0) {
                continue;
            }
            const index = difference + 119;
            if (ATTACKS[index] & PIECE_MASKS[piece.type]) {
                if (piece.type === PAWN) {
                    if ((difference > 0 && piece.color === WHITE) ||
                        (difference <= 0 && piece.color === BLACK)) {
                        if (!verbose) {
                            return true;
                        }
                        else {
                            attackers.push(algebraic(i));
                        }
                    }
                    continue;
                }
                // if the piece is a knight or a king
                if (piece.type === 'n' || piece.type === 'k') {
                    if (!verbose) {
                        return true;
                    }
                    else {
                        attackers.push(algebraic(i));
                        continue;
                    }
                }
                const offset = RAYS[index];
                let j = i + offset;
                let blocked = false;
                while (j !== square) {
                    if (this._board[j] != null) {
                        blocked = true;
                        break;
                    }
                    j += offset;
                }
                if (!blocked) {
                    if (!verbose) {
                        return true;
                    }
                    else {
                        attackers.push(algebraic(i));
                        continue;
                    }
                }
            }
        }
        if (verbose) {
            return attackers;
        }
        else {
            return false;
        }
    }
    attackers(square, attackedBy) {
        if (!attackedBy) {
            return this._attacked(this._turn, Ox88[square], true);
        }
        else {
            return this._attacked(attackedBy, Ox88[square], true);
        }
    }
    _isKingAttacked(color) {
        const square = this._kings[color];
        return square === -1 ? false : this._attacked(swapColor(color), square);
    }
    hash() {
        return this._hash.toString(16);
    }
    isAttacked(square, attackedBy) {
        return this._attacked(attackedBy, Ox88[square]);
    }
    isCheck() {
        return this._isKingAttacked(this._turn);
    }
    inCheck() {
        return this.isCheck();
    }
    isCheckmate() {
        return this.isCheck() && this._moves().length === 0;
    }
    isStalemate() {
        return !this.isCheck() && this._moves().length === 0;
    }
    isInsufficientMaterial() {
        /*
         * k.b. vs k.b. (of opposite colors) with mate in 1:
         * 8/8/8/8/1b6/8/B1k5/K7 b - - 0 1
         *
         * k.b. vs k.n. with mate in 1:
         * 8/8/8/8/1n6/8/B7/K1k5 b - - 2 1
         */
        const pieces = {
            b: 0,
            n: 0,
            r: 0,
            q: 0,
            k: 0,
            p: 0,
        };
        const bishops = [];
        let numPieces = 0;
        let squareColor = 0;
        for (let i = Ox88.a8; i <= Ox88.h1; i++) {
            squareColor = (squareColor + 1) % 2;
            if (i & 0x88) {
                i += 7;
                continue;
            }
            const piece = this._board[i];
            if (piece) {
                pieces[piece.type] = piece.type in pieces ? pieces[piece.type] + 1 : 1;
                if (piece.type === BISHOP) {
                    bishops.push(squareColor);
                }
                numPieces++;
            }
        }
        // k vs. k
        if (numPieces === 2) {
            return true;
        }
        else if (
        // k vs. kn .... or .... k vs. kb
        numPieces === 3 &&
            (pieces[BISHOP] === 1 || pieces[KNIGHT] === 1)) {
            return true;
        }
        else if (numPieces === pieces[BISHOP] + 2) {
            // kb vs. kb where any number of bishops are all on the same color
            let sum = 0;
            const len = bishops.length;
            for (let i = 0; i < len; i++) {
                sum += bishops[i];
            }
            if (sum === 0 || sum === len) {
                return true;
            }
        }
        return false;
    }
    isThreefoldRepetition() {
        return this._getPositionCount(this._hash) >= 3;
    }
    isDrawByFiftyMoves() {
        return this._halfMoves >= 100; // 50 moves per side = 100 half moves
    }
    isDraw() {
        return (this.isDrawByFiftyMoves() ||
            this.isStalemate() ||
            this.isInsufficientMaterial() ||
            this.isThreefoldRepetition());
    }
    isGameOver() {
        return this.isCheckmate() || this.isDraw();
    }
    moves({ verbose = false, square = undefined, piece = undefined, } = {}) {
        const moves = this._moves({ square, piece });
        if (verbose) {
            return moves.map((move) => new Move(this, move));
        }
        else {
            return moves.map((move) => this._moveToSan(move, moves));
        }
    }
    _moves({ legal = true, piece = undefined, square = undefined, } = {}) {
        const forSquare = square ? square.toLowerCase() : undefined;
        const forPiece = piece?.toLowerCase();
        const moves = [];
        const us = this._turn;
        const them = swapColor(us);
        let firstSquare = Ox88.a8;
        let lastSquare = Ox88.h1;
        let singleSquare = false;
        // are we generating moves for a single square?
        if (forSquare) {
            // illegal square, return empty moves
            if (!(forSquare in Ox88)) {
                return [];
            }
            else {
                firstSquare = lastSquare = Ox88[forSquare];
                singleSquare = true;
            }
        }
        for (let from = firstSquare; from <= lastSquare; from++) {
            // did we run off the end of the board
            if (from & 0x88) {
                from += 7;
                continue;
            }
            // empty square or opponent, skip
            if (!this._board[from] || this._board[from].color === them) {
                continue;
            }
            const { type } = this._board[from];
            let to;
            if (type === PAWN) {
                if (forPiece && forPiece !== type)
                    continue;
                // single square, non-capturing
                to = from + PAWN_OFFSETS[us][0];
                if (!this._board[to]) {
                    addMove(moves, us, from, to, PAWN);
                    // double square
                    to = from + PAWN_OFFSETS[us][1];
                    if (SECOND_RANK[us] === rank(from) && !this._board[to]) {
                        addMove(moves, us, from, to, PAWN, undefined, BITS.BIG_PAWN);
                    }
                }
                // pawn captures
                for (let j = 2; j < 4; j++) {
                    to = from + PAWN_OFFSETS[us][j];
                    if (to & 0x88)
                        continue;
                    if (this._board[to]?.color === them) {
                        addMove(moves, us, from, to, PAWN, this._board[to].type, BITS.CAPTURE);
                    }
                    else if (to === this._epSquare) {
                        addMove(moves, us, from, to, PAWN, PAWN, BITS.EP_CAPTURE);
                    }
                }
            }
            else {
                if (forPiece && forPiece !== type)
                    continue;
                for (let j = 0, len = PIECE_OFFSETS[type].length; j < len; j++) {
                    const offset = PIECE_OFFSETS[type][j];
                    to = from;
                    while (true) {
                        to += offset;
                        if (to & 0x88)
                            break;
                        if (!this._board[to]) {
                            addMove(moves, us, from, to, type);
                        }
                        else {
                            // own color, stop loop
                            if (this._board[to].color === us)
                                break;
                            addMove(moves, us, from, to, type, this._board[to].type, BITS.CAPTURE);
                            break;
                        }
                        /* break, if knight or king */
                        if (type === KNIGHT || type === KING)
                            break;
                    }
                }
            }
        }
        /*
         * check for castling if we're:
         *   a) generating all moves, or
         *   b) doing single square move generation on the king's square
         */
        if (forPiece === undefined || forPiece === KING) {
            if (!singleSquare || lastSquare === this._kings[us]) {
                // king-side castling
                if (this._castling[us] & BITS.KSIDE_CASTLE) {
                    const castlingFrom = this._kings[us];
                    const castlingTo = castlingFrom + 2;
                    if (!this._board[castlingFrom + 1] &&
                        !this._board[castlingTo] &&
                        !this._attacked(them, this._kings[us]) &&
                        !this._attacked(them, castlingFrom + 1) &&
                        !this._attacked(them, castlingTo)) {
                        addMove(moves, us, this._kings[us], castlingTo, KING, undefined, BITS.KSIDE_CASTLE);
                    }
                }
                // queen-side castling
                if (this._castling[us] & BITS.QSIDE_CASTLE) {
                    const castlingFrom = this._kings[us];
                    const castlingTo = castlingFrom - 2;
                    if (!this._board[castlingFrom - 1] &&
                        !this._board[castlingFrom - 2] &&
                        !this._board[castlingFrom - 3] &&
                        !this._attacked(them, this._kings[us]) &&
                        !this._attacked(them, castlingFrom - 1) &&
                        !this._attacked(them, castlingTo)) {
                        addMove(moves, us, this._kings[us], castlingTo, KING, undefined, BITS.QSIDE_CASTLE);
                    }
                }
            }
        }
        /*
         * return all pseudo-legal moves (this includes moves that allow the king
         * to be captured)
         */
        if (!legal || this._kings[us] === -1) {
            return moves;
        }
        // filter out illegal moves
        const legalMoves = [];
        for (let i = 0, len = moves.length; i < len; i++) {
            this._makeMove(moves[i]);
            if (!this._isKingAttacked(us)) {
                legalMoves.push(moves[i]);
            }
            this._undoMove();
        }
        return legalMoves;
    }
    move(move, { strict = false } = {}) {
        /*
         * The move function can be called with in the following parameters:
         *
         * .move('Nxb7')       <- argument is a case-sensitive SAN string
         *
         * .move({ from: 'h7', <- argument is a move object
         *         to :'h8',
         *         promotion: 'q' })
         *
         *
         * An optional strict argument may be supplied to tell chess.js to
         * strictly follow the SAN specification.
         */
        let moveObj = null;
        if (typeof move === 'string') {
            moveObj = this._moveFromSan(move, strict);
        }
        else if (move === null) {
            moveObj = this._moveFromSan(SAN_NULLMOVE, strict);
        }
        else if (typeof move === 'object') {
            const moves = this._moves();
            // convert the pretty move object to an ugly move object
            for (let i = 0, len = moves.length; i < len; i++) {
                if (move.from === algebraic(moves[i].from) &&
                    move.to === algebraic(moves[i].to) &&
                    (!('promotion' in moves[i]) || move.promotion === moves[i].promotion)) {
                    moveObj = moves[i];
                    break;
                }
            }
        }
        // failed to find move
        if (!moveObj) {
            if (typeof move === 'string') {
                throw new Error(`Invalid move: ${move}`);
            }
            else {
                throw new Error(`Invalid move: ${JSON.stringify(move)}`);
            }
        }
        //disallow null moves when in check
        if (this.isCheck() && moveObj.flags & BITS.NULL_MOVE) {
            throw new Error('Null move not allowed when in check');
        }
        /*
         * need to make a copy of move because we can't generate SAN after the move
         * is made
         */
        const prettyMove = new Move(this, moveObj);
        this._makeMove(moveObj);
        this._incPositionCount();
        return prettyMove;
    }
    _push(move) {
        this._history.push({
            move,
            kings: { b: this._kings.b, w: this._kings.w },
            turn: this._turn,
            castling: { b: this._castling.b, w: this._castling.w },
            epSquare: this._epSquare,
            halfMoves: this._halfMoves,
            moveNumber: this._moveNumber,
        });
    }
    _movePiece(from, to) {
        this._hash ^= this._pieceKey(from);
        this._board[to] = this._board[from];
        delete this._board[from];
        this._hash ^= this._pieceKey(to);
    }
    _makeMove(move) {
        const us = this._turn;
        const them = swapColor(us);
        this._push(move);
        if (move.flags & BITS.NULL_MOVE) {
            if (us === BLACK) {
                this._moveNumber++;
            }
            this._halfMoves++;
            this._turn = them;
            this._epSquare = EMPTY;
            return;
        }
        this._hash ^= this._epKey();
        this._hash ^= this._castlingKey();
        if (move.captured) {
            this._hash ^= this._pieceKey(move.to);
        }
        this._movePiece(move.from, move.to);
        // if ep capture, remove the captured pawn
        if (move.flags & BITS.EP_CAPTURE) {
            if (this._turn === BLACK) {
                this._clear(move.to - 16);
            }
            else {
                this._clear(move.to + 16);
            }
        }
        // if pawn promotion, replace with new piece
        if (move.promotion) {
            this._clear(move.to);
            this._set(move.to, { type: move.promotion, color: us });
        }
        // if we moved the king
        if (this._board[move.to].type === KING) {
            this._kings[us] = move.to;
            // if we castled, move the rook next to the king
            if (move.flags & BITS.KSIDE_CASTLE) {
                const castlingTo = move.to - 1;
                const castlingFrom = move.to + 1;
                this._movePiece(castlingFrom, castlingTo);
            }
            else if (move.flags & BITS.QSIDE_CASTLE) {
                const castlingTo = move.to + 1;
                const castlingFrom = move.to - 2;
                this._movePiece(castlingFrom, castlingTo);
            }
            // turn off castling
            this._castling[us] = 0;
        }
        // turn off castling if we move a rook
        if (this._castling[us]) {
            for (let i = 0, len = ROOKS[us].length; i < len; i++) {
                if (move.from === ROOKS[us][i].square &&
                    this._castling[us] & ROOKS[us][i].flag) {
                    this._castling[us] ^= ROOKS[us][i].flag;
                    break;
                }
            }
        }
        // turn off castling if we capture a rook
        if (this._castling[them]) {
            for (let i = 0, len = ROOKS[them].length; i < len; i++) {
                if (move.to === ROOKS[them][i].square &&
                    this._castling[them] & ROOKS[them][i].flag) {
                    this._castling[them] ^= ROOKS[them][i].flag;
                    break;
                }
            }
        }
        this._hash ^= this._castlingKey();
        // if big pawn move, update the en passant square
        if (move.flags & BITS.BIG_PAWN) {
            let epSquare;
            if (us === BLACK) {
                epSquare = move.to - 16;
            }
            else {
                epSquare = move.to + 16;
            }
            if ((!((move.to - 1) & 0x88) &&
                this._board[move.to - 1]?.type === PAWN &&
                this._board[move.to - 1]?.color === them) ||
                (!((move.to + 1) & 0x88) &&
                    this._board[move.to + 1]?.type === PAWN &&
                    this._board[move.to + 1]?.color === them)) {
                this._epSquare = epSquare;
                this._hash ^= this._epKey();
            }
            else {
                this._epSquare = EMPTY;
            }
        }
        else {
            this._epSquare = EMPTY;
        }
        // reset the 50 move counter if a pawn is moved or a piece is captured
        if (move.piece === PAWN) {
            this._halfMoves = 0;
        }
        else if (move.flags & (BITS.CAPTURE | BITS.EP_CAPTURE)) {
            this._halfMoves = 0;
        }
        else {
            this._halfMoves++;
        }
        if (us === BLACK) {
            this._moveNumber++;
        }
        this._turn = them;
        this._hash ^= SIDE_KEY;
    }
    undo() {
        const hash = this._hash;
        const move = this._undoMove();
        if (move) {
            const prettyMove = new Move(this, move);
            this._decPositionCount(hash);
            return prettyMove;
        }
        return null;
    }
    _undoMove() {
        const old = this._history.pop();
        if (old === undefined) {
            return null;
        }
        this._hash ^= this._epKey();
        this._hash ^= this._castlingKey();
        const move = old.move;
        this._kings = old.kings;
        this._turn = old.turn;
        this._castling = old.castling;
        this._epSquare = old.epSquare;
        this._halfMoves = old.halfMoves;
        this._moveNumber = old.moveNumber;
        this._hash ^= this._epKey();
        this._hash ^= this._castlingKey();
        this._hash ^= SIDE_KEY;
        const us = this._turn;
        const them = swapColor(us);
        if (move.flags & BITS.NULL_MOVE) {
            return move;
        }
        this._movePiece(move.to, move.from);
        // to undo any promotions
        if (move.piece) {
            this._clear(move.from);
            this._set(move.from, { type: move.piece, color: us });
        }
        if (move.captured) {
            if (move.flags & BITS.EP_CAPTURE) {
                // en passant capture
                let index;
                if (us === BLACK) {
                    index = move.to - 16;
                }
                else {
                    index = move.to + 16;
                }
                this._set(index, { type: PAWN, color: them });
            }
            else {
                // regular capture
                this._set(move.to, { type: move.captured, color: them });
            }
        }
        if (move.flags & (BITS.KSIDE_CASTLE | BITS.QSIDE_CASTLE)) {
            let castlingTo, castlingFrom;
            if (move.flags & BITS.KSIDE_CASTLE) {
                castlingTo = move.to + 1;
                castlingFrom = move.to - 1;
            }
            else {
                castlingTo = move.to - 2;
                castlingFrom = move.to + 1;
            }
            this._movePiece(castlingFrom, castlingTo);
        }
        return move;
    }
    pgn({ newline = '\n', maxWidth = 0, } = {}) {
        /*
         * using the specification from http://www.chessclub.com/help/PGN-spec
         * example for html usage: .pgn({ max_width: 72, newline_char: "<br />" })
         */
        const result = [];
        let headerExists = false;
        /* add the PGN header information */
        for (const i in this._header) {
            /*
             * TODO: order of enumerated properties in header object is not
             * guaranteed, see ECMA-262 spec (section 12.6.4)
             *
             * By using HEADER_TEMPLATE, the order of tags should be preserved; we
             * do have to check for null placeholders, though, and omit them
             */
            const headerTag = this._header[i];
            if (headerTag)
                result.push(`[${i} "${this._header[i]}"]` + newline);
            headerExists = true;
        }
        if (headerExists && this._history.length) {
            result.push(newline);
        }
        const appendComment = (moveString) => {
            const comment = this._comments[this.fen()];
            if (typeof comment !== 'undefined') {
                const delimiter = moveString.length > 0 ? ' ' : '';
                moveString = `${moveString}${delimiter}{${comment}}`;
            }
            return moveString;
        };
        // pop all of history onto reversed_history
        const reversedHistory = [];
        while (this._history.length > 0) {
            reversedHistory.push(this._undoMove());
        }
        const moves = [];
        let moveString = '';
        // special case of a commented starting position with no moves
        if (reversedHistory.length === 0) {
            moves.push(appendComment(''));
        }
        // build the list of moves.  a move_string looks like: "3. e3 e6"
        while (reversedHistory.length > 0) {
            moveString = appendComment(moveString);
            const move = reversedHistory.pop();
            // make TypeScript stop complaining about move being undefined
            if (!move) {
                break;
            }
            // if the position started with black to move, start PGN with #. ...
            if (!this._history.length && move.color === 'b') {
                const prefix = `${this._moveNumber}. ...`;
                // is there a comment preceding the first move?
                moveString = moveString ? `${moveString} ${prefix}` : prefix;
            }
            else if (move.color === 'w') {
                // store the previous generated move_string if we have one
                if (moveString.length) {
                    moves.push(moveString);
                }
                moveString = this._moveNumber + '.';
            }
            moveString =
                moveString + ' ' + this._moveToSan(move, this._moves({ legal: true }));
            this._makeMove(move);
        }
        // are there any other leftover moves?
        if (moveString.length) {
            moves.push(appendComment(moveString));
        }
        // is there a result? (there ALWAYS has to be a result according to spec; see Seven Tag Roster)
        moves.push(this._header.Result || '*');
        /*
         * history should be back to what it was before we started generating PGN,
         * so join together moves
         */
        if (maxWidth === 0) {
            return result.join('') + moves.join(' ');
        }
        // TODO (jah): huh?
        const strip = function () {
            if (result.length > 0 && result[result.length - 1] === ' ') {
                result.pop();
                return true;
            }
            return false;
        };
        // NB: this does not preserve comment whitespace.
        const wrapComment = function (width, move) {
            for (const token of move.split(' ')) {
                if (!token) {
                    continue;
                }
                if (width + token.length > maxWidth) {
                    while (strip()) {
                        width--;
                    }
                    result.push(newline);
                    width = 0;
                }
                result.push(token);
                width += token.length;
                result.push(' ');
                width++;
            }
            if (strip()) {
                width--;
            }
            return width;
        };
        // wrap the PGN output at max_width
        let currentWidth = 0;
        for (let i = 0; i < moves.length; i++) {
            if (currentWidth + moves[i].length > maxWidth) {
                if (moves[i].includes('{')) {
                    currentWidth = wrapComment(currentWidth, moves[i]);
                    continue;
                }
            }
            // if the current move will push past max_width
            if (currentWidth + moves[i].length > maxWidth && i !== 0) {
                // don't end the line with whitespace
                if (result[result.length - 1] === ' ') {
                    result.pop();
                }
                result.push(newline);
                currentWidth = 0;
            }
            else if (i !== 0) {
                result.push(' ');
                currentWidth++;
            }
            result.push(moves[i]);
            currentWidth += moves[i].length;
        }
        return result.join('');
    }
    /**
     * @deprecated Use `setHeader` and `getHeaders` instead. This method will return null header tags (which is not what you want)
     */
    header(...args) {
        for (let i = 0; i < args.length; i += 2) {
            if (typeof args[i] === 'string' && typeof args[i + 1] === 'string') {
                this._header[args[i]] = args[i + 1];
            }
        }
        return this._header;
    }
    // TODO: value validation per spec
    setHeader(key, value) {
        this._header[key] = value ?? SEVEN_TAG_ROSTER[key] ?? null;
        return this.getHeaders();
    }
    removeHeader(key) {
        if (key in this._header) {
            this._header[key] = SEVEN_TAG_ROSTER[key] || null;
            return true;
        }
        return false;
    }
    // return only non-null headers (omit placemarker nulls)
    getHeaders() {
        const nonNullHeaders = {};
        for (const [key, value] of Object.entries(this._header)) {
            if (value !== null) {
                nonNullHeaders[key] = value;
            }
        }
        return nonNullHeaders;
    }
    loadPgn(pgn, { strict = false, newlineChar = '\r?\n', } = {}) {
        // If newlineChar is not the default, replace all instances with \n
        if (newlineChar !== '\r?\n') {
            pgn = pgn.replace(new RegExp(newlineChar, 'g'), '\n');
        }
        const parsedPgn = peg$parse(pgn);
        // Put the board in the starting position
        this.reset();
        // parse PGN header
        const headers = parsedPgn.headers;
        let fen = '';
        for (const key in headers) {
            // check to see user is including fen (possibly with wrong tag case)
            if (key.toLowerCase() === 'fen') {
                fen = headers[key];
            }
            this.header(key, headers[key]);
        }
        /*
         * the permissive parser should attempt to load a fen tag, even if it's the
         * wrong case and doesn't include a corresponding [SetUp "1"] tag
         */
        if (!strict) {
            if (fen) {
                this.load(fen, { preserveHeaders: true });
            }
        }
        else {
            /*
             * strict parser - load the starting position indicated by [Setup '1']
             * and [FEN position]
             */
            if (headers['SetUp'] === '1') {
                if (!('FEN' in headers)) {
                    throw new Error('Invalid PGN: FEN tag must be supplied with SetUp tag');
                }
                // don't clear the headers when loading
                this.load(headers['FEN'], { preserveHeaders: true });
            }
        }
        let node = parsedPgn.root;
        while (node) {
            if (node.move) {
                const move = this._moveFromSan(node.move, strict);
                if (move == null) {
                    throw new Error(`Invalid move in PGN: ${node.move}`);
                }
                else {
                    this._makeMove(move);
                    this._incPositionCount();
                }
            }
            if (node.comment !== undefined) {
                this._comments[this.fen()] = node.comment;
            }
            node = node.variations[0];
        }
        /*
         * Per section 8.2.6 of the PGN spec, the Result tag pair must match match
         * the termination marker. Only do this when headers are present, but the
         * result tag is missing
         */
        const result = parsedPgn.result;
        if (result &&
            Object.keys(this._header).length &&
            this._header['Result'] !== result) {
            this.setHeader('Result', result);
        }
    }
    /*
     * Convert a move from 0x88 coordinates to Standard Algebraic Notation
     * (SAN)
     *
     * @param {boolean} strict Use the strict SAN parser. It will throw errors
     * on overly disambiguated moves (see below):
     *
     * r1bqkbnr/ppp2ppp/2n5/1B1pP3/4P3/8/PPPP2PP/RNBQK1NR b KQkq - 2 4
     * 4. ... Nge7 is overly disambiguated because the knight on c6 is pinned
     * 4. ... Ne7 is technically the valid SAN
     */
    _moveToSan(move, moves) {
        let output = '';
        if (move.flags & BITS.KSIDE_CASTLE) {
            output = 'O-O';
        }
        else if (move.flags & BITS.QSIDE_CASTLE) {
            output = 'O-O-O';
        }
        else if (move.flags & BITS.NULL_MOVE) {
            return SAN_NULLMOVE;
        }
        else {
            if (move.piece !== PAWN) {
                const disambiguator = getDisambiguator(move, moves);
                output += move.piece.toUpperCase() + disambiguator;
            }
            if (move.flags & (BITS.CAPTURE | BITS.EP_CAPTURE)) {
                if (move.piece === PAWN) {
                    output += algebraic(move.from)[0];
                }
                output += 'x';
            }
            output += algebraic(move.to);
            if (move.promotion) {
                output += '=' + move.promotion.toUpperCase();
            }
        }
        this._makeMove(move);
        if (this.isCheck()) {
            if (this.isCheckmate()) {
                output += '#';
            }
            else {
                output += '+';
            }
        }
        this._undoMove();
        return output;
    }
    // convert a move from Standard Algebraic Notation (SAN) to 0x88 coordinates
    _moveFromSan(move, strict = false) {
        // strip off any move decorations: e.g Nf3+?! becomes Nf3
        let cleanMove = strippedSan(move);
        if (!strict) {
            if (cleanMove === '0-0') {
                cleanMove = 'O-O';
            }
            else if (cleanMove === '0-0-0') {
                cleanMove = 'O-O-O';
            }
        }
        //first implementation of null with a dummy move (black king moves from a8 to a8), maybe this can be implemented better
        if (cleanMove == SAN_NULLMOVE) {
            const res = {
                color: this._turn,
                from: 0,
                to: 0,
                piece: 'k',
                flags: BITS.NULL_MOVE,
            };
            return res;
        }
        let pieceType = inferPieceType(cleanMove);
        let moves = this._moves({ legal: true, piece: pieceType });
        // strict parser
        for (let i = 0, len = moves.length; i < len; i++) {
            if (cleanMove === strippedSan(this._moveToSan(moves[i], moves))) {
                return moves[i];
            }
        }
        // the strict parser failed
        if (strict) {
            return null;
        }
        let piece = undefined;
        let matches = undefined;
        let from = undefined;
        let to = undefined;
        let promotion = undefined;
        /*
         * The default permissive (non-strict) parser allows the user to parse
         * non-standard chess notations. This parser is only run after the strict
         * Standard Algebraic Notation (SAN) parser has failed.
         *
         * When running the permissive parser, we'll run a regex to grab the piece, the
         * to/from square, and an optional promotion piece. This regex will
         * parse common non-standard notation like: Pe2-e4, Rc1c4, Qf3xf7,
         * f7f8q, b1c3
         *
         * NOTE: Some positions and moves may be ambiguous when using the permissive
         * parser. For example, in this position: 6k1/8/8/B7/8/8/8/BN4K1 w - - 0 1,
         * the move b1c3 may be interpreted as Nc3 or B1c3 (a disambiguated bishop
         * move). In these cases, the permissive parser will default to the most
         * basic interpretation (which is b1c3 parsing to Nc3).
         */
        let overlyDisambiguated = false;
        matches = cleanMove.match(/([pnbrqkPNBRQK])?([a-h][1-8])x?-?([a-h][1-8])([qrbnQRBN])?/);
        if (matches) {
            piece = matches[1];
            from = matches[2];
            to = matches[3];
            promotion = matches[4];
            if (from.length == 1) {
                overlyDisambiguated = true;
            }
        }
        else {
            /*
             * The [a-h]?[1-8]? portion of the regex below handles moves that may be
             * overly disambiguated (e.g. Nge7 is unnecessary and non-standard when
             * there is one legal knight move to e7). In this case, the value of
             * 'from' variable will be a rank or file, not a square.
             */
            matches = cleanMove.match(/([pnbrqkPNBRQK])?([a-h]?[1-8]?)x?-?([a-h][1-8])([qrbnQRBN])?/);
            if (matches) {
                piece = matches[1];
                from = matches[2];
                to = matches[3];
                promotion = matches[4];
                if (from.length == 1) {
                    overlyDisambiguated = true;
                }
            }
        }
        pieceType = inferPieceType(cleanMove);
        moves = this._moves({
            legal: true,
            piece: piece ? piece : pieceType,
        });
        if (!to) {
            return null;
        }
        for (let i = 0, len = moves.length; i < len; i++) {
            if (!from) {
                // if there is no from square, it could be just 'x' missing from a capture
                if (cleanMove ===
                    strippedSan(this._moveToSan(moves[i], moves)).replace('x', '')) {
                    return moves[i];
                }
                // hand-compare move properties with the results from our permissive regex
            }
            else if ((!piece || piece.toLowerCase() == moves[i].piece) &&
                Ox88[from] == moves[i].from &&
                Ox88[to] == moves[i].to &&
                (!promotion || promotion.toLowerCase() == moves[i].promotion)) {
                return moves[i];
            }
            else if (overlyDisambiguated) {
                /*
                 * SPECIAL CASE: we parsed a move string that may have an unneeded
                 * rank/file disambiguator (e.g. Nge7).  The 'from' variable will
                 */
                const square = algebraic(moves[i].from);
                if ((!piece || piece.toLowerCase() == moves[i].piece) &&
                    Ox88[to] == moves[i].to &&
                    (from == square[0] || from == square[1]) &&
                    (!promotion || promotion.toLowerCase() == moves[i].promotion)) {
                    return moves[i];
                }
            }
        }
        return null;
    }
    ascii() {
        let s = '   +------------------------+\n';
        for (let i = Ox88.a8; i <= Ox88.h1; i++) {
            // display the rank
            if (file(i) === 0) {
                s += ' ' + '87654321'[rank(i)] + ' |';
            }
            if (this._board[i]) {
                const piece = this._board[i].type;
                const color = this._board[i].color;
                const symbol = color === WHITE ? piece.toUpperCase() : piece.toLowerCase();
                s += ' ' + symbol + ' ';
            }
            else {
                s += ' . ';
            }
            if ((i + 1) & 0x88) {
                s += '|\n';
                i += 8;
            }
        }
        s += '   +------------------------+\n';
        s += '     a  b  c  d  e  f  g  h';
        return s;
    }
    perft(depth) {
        const moves = this._moves({ legal: false });
        let nodes = 0;
        const color = this._turn;
        for (let i = 0, len = moves.length; i < len; i++) {
            this._makeMove(moves[i]);
            if (!this._isKingAttacked(color)) {
                if (depth - 1 > 0) {
                    nodes += this.perft(depth - 1);
                }
                else {
                    nodes++;
                }
            }
            this._undoMove();
        }
        return nodes;
    }
    setTurn(color) {
        if (this._turn == color) {
            return false;
        }
        this.move('--');
        return true;
    }
    turn() {
        return this._turn;
    }
    board() {
        const output = [];
        let row = [];
        for (let i = Ox88.a8; i <= Ox88.h1; i++) {
            if (this._board[i] == null) {
                row.push(null);
            }
            else {
                row.push({
                    square: algebraic(i),
                    type: this._board[i].type,
                    color: this._board[i].color,
                });
            }
            if ((i + 1) & 0x88) {
                output.push(row);
                row = [];
                i += 8;
            }
        }
        return output;
    }
    squareColor(square) {
        if (square in Ox88) {
            const sq = Ox88[square];
            return (rank(sq) + file(sq)) % 2 === 0 ? 'light' : 'dark';
        }
        return null;
    }
    history({ verbose = false } = {}) {
        const reversedHistory = [];
        const moveHistory = [];
        while (this._history.length > 0) {
            reversedHistory.push(this._undoMove());
        }
        while (true) {
            const move = reversedHistory.pop();
            if (!move) {
                break;
            }
            if (verbose) {
                moveHistory.push(new Move(this, move));
            }
            else {
                moveHistory.push(this._moveToSan(move, this._moves()));
            }
            this._makeMove(move);
        }
        return moveHistory;
    }
    /*
     * Keeps track of position occurrence counts for the purpose of repetition
     * checking. Old positions are removed from the map if their counts are reduced to 0.
     */
    _getPositionCount(hash) {
        return this._positionCount.get(hash) ?? 0;
    }
    _incPositionCount() {
        this._positionCount.set(this._hash, (this._positionCount.get(this._hash) ?? 0) + 1);
    }
    _decPositionCount(hash) {
        const currentCount = this._positionCount.get(hash) ?? 0;
        if (currentCount === 1) {
            this._positionCount.delete(hash);
        }
        else {
            this._positionCount.set(hash, currentCount - 1);
        }
    }
    _pruneComments() {
        const reversedHistory = [];
        const currentComments = {};
        const copyComment = (fen) => {
            if (fen in this._comments) {
                currentComments[fen] = this._comments[fen];
            }
        };
        while (this._history.length > 0) {
            reversedHistory.push(this._undoMove());
        }
        copyComment(this.fen());
        while (true) {
            const move = reversedHistory.pop();
            if (!move) {
                break;
            }
            this._makeMove(move);
            copyComment(this.fen());
        }
        this._comments = currentComments;
    }
    getComment() {
        return this._comments[this.fen()];
    }
    setComment(comment) {
        this._comments[this.fen()] = comment.replace('{', '[').replace('}', ']');
    }
    /**
     * @deprecated Renamed to `removeComment` for consistency
     */
    deleteComment() {
        return this.removeComment();
    }
    removeComment() {
        const comment = this._comments[this.fen()];
        delete this._comments[this.fen()];
        return comment;
    }
    getComments() {
        this._pruneComments();
        return Object.keys(this._comments).map((fen) => {
            return { fen: fen, comment: this._comments[fen] };
        });
    }
    /**
     * @deprecated Renamed to `removeComments` for consistency
     */
    deleteComments() {
        return this.removeComments();
    }
    removeComments() {
        this._pruneComments();
        return Object.keys(this._comments).map((fen) => {
            const comment = this._comments[fen];
            delete this._comments[fen];
            return { fen: fen, comment: comment };
        });
    }
    setCastlingRights(color, rights) {
        for (const side of [KING, QUEEN]) {
            if (rights[side] !== undefined) {
                if (rights[side]) {
                    this._castling[color] |= SIDES[side];
                }
                else {
                    this._castling[color] &= ~SIDES[side];
                }
            }
        }
        this._updateCastlingRights();
        const result = this.getCastlingRights(color);
        return ((rights[KING] === undefined || rights[KING] === result[KING]) &&
            (rights[QUEEN] === undefined || rights[QUEEN] === result[QUEEN]));
    }
    getCastlingRights(color) {
        return {
            [KING]: (this._castling[color] & SIDES[KING]) !== 0,
            [QUEEN]: (this._castling[color] & SIDES[QUEEN]) !== 0,
        };
    }
    moveNumber() {
        return this._moveNumber;
    }
}

export { BISHOP, BLACK, Chess, DEFAULT_POSITION, KING, KNIGHT, Move, PAWN, QUEEN, ROOK, SEVEN_TAG_ROSTER, SQUARES, WHITE, validateFen, xoroshiro128 };
//# sourceMappingURL=chess.js.map


#################################################################
### FILE: public/vendor/stockfish/stockfish-18-lite-single.js
#################################################################

/*!
 * Stockfish.js 18 (c) 2026, Chess.com, LLC
 * https://github.com/nmrugg/stockfish.js
 * License: GPLv3
 *
 * Based on Stockfish (c) T. Romstad, M. Costalba, J. Kiiski, G. Linscott and other contributors.
 * https://github.com/official-stockfish/Stockfish
 *
 * Nets by Linmiao Xu (linrock)
 * https://tests.stockfishchess.org/nns?network_name=nn-9067e33176e
 */!function(){var u,s,e,c,r,n,l=7295411;function t(){function e(e){e=e||{},(f=f||(void 0!==e?e:{})).ready=new Promise(function(e,n){j=e,a=n}),"undefined"!=typeof global&&"[object process]"===Object.prototype.toString.call(global.process)&&"undefined"!=typeof fetch&&("undefined"==typeof XMLHttpRequest&&(global.XMLHttpRequest=function(){var t,r={open:function(e,n){t=n},send:function(){require("fs").readFile(t,function(e,n){r.readyState=4,e?(console.error(e),r.status=404,r.onerror(e)):(r.status=200,r.response=n,r.onreadystatechange(),r.onload())})}};return r}),fetch=null),f.print=function(e){f.listener?f.listener(e):console.log(e)},f.printErr=function(e){f.listener?f.listener(e):console.error(e)},f.terminate=function(){"undefined"!=typeof PThread&&PThread.Z()};var f,j,a,n,t,H,r,k,i,o=Object.assign({},f),u=[],s="./this.program",c=(e,n)=>{throw n},U="object"==typeof window,l="function"==typeof importScripts,W="object"==typeof process&&"object"==typeof process.versions&&"string"==typeof process.versions.node,p="",L=(W?(p=l?require("path").dirname(p)+"/":__dirname+"/",k=()=>{r||(H=require("fs"),r=require("path"))},n=function(e,n){return k(),e=r.normalize(e),H.readFileSync(e,n?void 0:"utf8")},t=e=>e=(e=n(e,!0)).buffer?e:new Uint8Array(e),1<process.argv.length&&(s=process.argv[1].replace(/\\/g,"/")),u=process.argv.slice(2),process.on("uncaughtException",function(e){if(!(e instanceof Y))throw e}),process.on("unhandledRejection",function(e){throw e}),c=(e,n)=>{if(m||0<_)throw process.exitCode=e,n;n instanceof Y||d("exiting due to exception: "+n),process.exit(e)},f.inspect=function(){return"[Emscripten Module object]"}):(U||l)&&(l?p=self.location.href:"undefined"!=typeof document&&document.currentScript&&(p=document.currentScript.src),p=0!==(p=je?je:p).indexOf("blob:")?p.substr(0,p.replace(/[?#].*/,"").lastIndexOf("/")+1):"",n=e=>{var n=new XMLHttpRequest;return n.open("GET",e,!1),n.send(null),n.responseText},l)&&(t=e=>{var n=new XMLHttpRequest;return n.open("GET",e,!1),n.responseType="arraybuffer",n.send(null),new Uint8Array(n.response)}),f.print||console.log.bind(console)),d=f.printErr||console.warn.bind(console),m=(Object.assign(f,o),f.arguments&&(u=f.arguments),f.thisProgram&&(s=f.thisProgram),f.quit&&(c=f.quit),f.wasmBinary&&(i=f.wasmBinary),f.noExitRuntime||!0);"object"!=typeof WebAssembly&&A("no native wasm support detected");var q,B,h,y,g,N,v=!1,K="undefined"!=typeof TextDecoder?new TextDecoder("utf8"):void 0;function X(e,n,t){var r=n+t;for(t=n;e[t]&&!(r<=t);)++t;if(16<t-n&&e.subarray&&K)return K.decode(e.subarray(n,t));for(r="";n<t;){var o,a,i=e[n++];128&i?(o=63&e[n++],192==(224&i)?r+=String.fromCharCode((31&i)<<6|o):(a=63&e[n++],(i=224==(240&i)?(15&i)<<12|o<<6|a:(7&i)<<18|o<<12|a<<6|63&e[n++])<65536?r+=String.fromCharCode(i):(i-=65536,r+=String.fromCharCode(55296|i>>10,56320|1023&i)))):r+=String.fromCharCode(i)}return r}function z(e){return e?X(y,e,void 0):""}function G(e,n,t,r){if(0<r){r=t+r-1;for(var o=0;o<e.length;++o){var a=e.charCodeAt(o);if((a=55296<=a&&a<=57343?65536+((1023&a)<<10)|1023&e.charCodeAt(++o):a)<=127){if(r<=t)break;n[t++]=a}else{if(a<=2047){if(r<=t+1)break;n[t++]=192|a>>6}else{if(a<=65535){if(r<=t+2)break;n[t++]=224|a>>12}else{if(r<=t+3)break;n[t++]=240|a>>18,n[t++]=128|a>>12&63}n[t++]=128|a>>6&63}n[t++]=128|63&a}}n[t]=0}}function V(e){for(var n=0,t=0;t<e.length;++t){var r=e.charCodeAt(t);(r=55296<=r&&r<=57343?65536+((1023&r)<<10)|1023&e.charCodeAt(++t):r)<=127?++n:n=r<=2047?n+2:r<=65535?n+3:n+4}return n}function J(e){var n=V(e)+1,t=P(n);return G(e,h,t,n),t}function Z(){var e=q.buffer;B=e,f.HEAP8=h=new Int8Array(e),f.HEAP16=new Int16Array(e),f.HEAP32=g=new Int32Array(e),f.HEAPU8=y=new Uint8Array(e),f.HEAPU16=new Uint16Array(e),f.HEAPU32=new Uint32Array(e),f.HEAPF32=new Float32Array(e),f.HEAPF64=N=new Float64Array(e)}var w,$=[],Q=[],ee=[],ne=[],te=!1,_=0,b=0,re=null,S=null;function A(e){throw f.onAbort&&f.onAbort(e),d(e="Aborted("+e+")"),v=!0,e=new WebAssembly.RuntimeError(e+". Build with -s ASSERTIONS=1 for more info."),a(e),e}function oe(){return w.startsWith("data:application/octet-stream;base64,")}function ae(){var e=w;try{if(e==w&&i)return new Uint8Array(i);if(t)return t(e);throw"both async and sync fetching of the wasm failed"}catch(e){A(e)}}f.preloadedImages={},f.preloadedAudios={},w="stockfish.wasm",oe()||(o=w,w=f.locateFile?f.locateFile(o,p):p+o);var ie={6678104:function(){try{f.onDoneSearching()}catch(e){}}};function D(e){for(;0<e.length;){var n,t=e.shift();"function"==typeof t?t(f):"number"==typeof(n=t.S)?void 0===t.P?Te.call(null,n):Oe.apply(null,[n,t.P]):n(void 0===t.P?null:t.P)}}function ue(e){e instanceof Y||"unwind"==e||c(1,e)}var se=[null,[],[]],ce={},le=W?()=>{var e=process.hrtime();return 1e3*e[0]+e[1]/1e6}:()=>performance.now(),fe=[];function pe(e){if(!te&&!v)try{e()}catch(e){ue(e)}}var de,me={};function he(){if(!de){var e,n={USER:"web_user",LOGNAME:"web_user",PATH:"/",PWD:"/",HOME:"/home/web_user",LANG:("object"==typeof navigator&&navigator.languages&&navigator.languages[0]||"C").replace("-","_")+".UTF-8",_:s||"./this.program"};for(e in me)void 0===me[e]?delete n[e]:n[e]=me[e];var t=[];for(e in n)t.push(e+"="+n[e]);de=t}return de}function M(e){return 0==e%4&&(0!=e%100||0==e%400)}function ye(e,n){for(var t=0,r=0;r<=n;t+=e[r++]);return t}var x=[31,29,31,30,31,30,31,31,30,31,30,31],R=[31,28,31,30,31,30,31,31,30,31,30,31];function C(e,n){for(e=new Date(e.getTime());0<n;){var t=e.getMonth(),r=(M(e.getFullYear())?x:R)[t];if(!(n>r-e.getDate())){e.setDate(e.getDate()+n);break}n-=r-e.getDate()+1,e.setDate(1),t<11?e.setMonth(t+1):(e.setMonth(0),e.setFullYear(e.getFullYear()+1))}return e}function ge(e,n,t,r){function o(e,n,t){for(e="number"==typeof e?e.toString():e||"";e.length<n;)e=t[0]+e;return e}function a(e,n){return o(e,n,"0")}function i(e,n){function t(e){return e<0?-1:0<e?1:0}var r;return r=0===(r=t(e.getFullYear()-n.getFullYear()))&&0===(r=t(e.getMonth()-n.getMonth()))?t(e.getDate()-n.getDate()):r}function u(e){switch(e.getDay()){case 0:return new Date(e.getFullYear()-1,11,29);case 1:return e;case 2:return new Date(e.getFullYear(),0,3);case 3:return new Date(e.getFullYear(),0,2);case 4:return new Date(e.getFullYear(),0,1);case 5:return new Date(e.getFullYear()-1,11,31);case 6:return new Date(e.getFullYear()-1,11,30)}}function s(e){e=C(new Date(e.A+1900,0,1),e.O);var n=new Date(e.getFullYear()+1,0,4),t=u(new Date(e.getFullYear(),0,4)),n=u(n);return i(t,e)<=0?i(n,e)<=0?e.getFullYear()+1:e.getFullYear():e.getFullYear()-1}var c,l=g[r+40>>2];for(c in r={V:g[r>>2],U:g[r+4>>2],M:g[r+8>>2],L:g[r+12>>2],K:g[r+16>>2],A:g[r+20>>2],N:g[r+24>>2],O:g[r+28>>2],$:g[r+32>>2],T:g[r+36>>2],W:l?z(l):""},t=z(t),l={"%c":"%a %b %d %H:%M:%S %Y","%D":"%m/%d/%y","%F":"%Y-%m-%d","%h":"%b","%r":"%I:%M:%S %p","%R":"%H:%M","%T":"%H:%M:%S","%x":"%m/%d/%y","%X":"%H:%M:%S","%Ec":"%c","%EC":"%C","%Ex":"%m/%d/%y","%EX":"%H:%M:%S","%Ey":"%y","%EY":"%Y","%Od":"%d","%Oe":"%e","%OH":"%H","%OI":"%I","%Om":"%m","%OM":"%M","%OS":"%S","%Ou":"%u","%OU":"%U","%OV":"%V","%Ow":"%w","%OW":"%W","%Oy":"%y"})t=t.replace(new RegExp(c,"g"),l[c]);var f,p,d="Sunday Monday Tuesday Wednesday Thursday Friday Saturday".split(" "),m="January February March April May June July August September October November December".split(" "),l={"%a":function(e){return d[e.N].substring(0,3)},"%A":function(e){return d[e.N]},"%b":function(e){return m[e.K].substring(0,3)},"%B":function(e){return m[e.K]},"%C":function(e){return a((e.A+1900)/100|0,2)},"%d":function(e){return a(e.L,2)},"%e":function(e){return o(e.L,2," ")},"%g":function(e){return s(e).toString().substring(2)},"%G":s,"%H":function(e){return a(e.M,2)},"%I":function(e){return 0==(e=e.M)?e=12:12<e&&(e-=12),a(e,2)},"%j":function(e){return a(e.L+ye(M(e.A+1900)?x:R,e.K-1),3)},"%m":function(e){return a(e.K+1,2)},"%M":function(e){return a(e.U,2)},"%n":function(){return"\n"},"%p":function(e){return 0<=e.M&&e.M<12?"AM":"PM"},"%S":function(e){return a(e.V,2)},"%t":function(){return"\t"},"%u":function(e){return e.N||7},"%U":function(e){var n=new Date(e.A+1900,0,1),t=0===n.getDay()?n:C(n,7-n.getDay());return i(t,e=new Date(e.A+1900,e.K,e.L))<0?a(Math.ceil((31-t.getDate()+(ye(M(e.getFullYear())?x:R,e.getMonth()-1)-31)+e.getDate())/7),2):0===i(t,n)?"01":"00"},"%V":function(e){var n=new Date(e.A+1901,0,4),t=u(new Date(e.A+1900,0,4)),n=u(n),r=C(new Date(e.A+1900,0,1),e.O);return i(r,t)<0?"53":i(n,r)<=0?"01":a(Math.ceil((t.getFullYear()<e.A+1900?e.O+32-t.getDate():e.O+1-t.getDate())/7),2)},"%w":function(e){return e.N},"%W":function(e){var n=new Date(e.A,0,1),t=1===n.getDay()?n:C(n,0===n.getDay()?1:7-n.getDay()+1);return i(t,e=new Date(e.A+1900,e.K,e.L))<0?a(Math.ceil((31-t.getDate()+(ye(M(e.getFullYear())?x:R,e.getMonth()-1)-31)+e.getDate())/7),2):0===i(t,n)?"01":"00"},"%y":function(e){return(e.A+1900).toString().substring(2)},"%Y":function(e){return e.A+1900},"%z":function(e){var n=0<=(e=e.T);return e=Math.abs(e)/60,(n?"+":"-")+String("0000"+(e/60*100+e%60)).slice(-4)},"%Z":function(e){return e.W},"%%":function(){return"%"}};for(c in t=t.replace(/%%/g,"\0\0"),l)t.includes(c)&&(t=t.replace(new RegExp(c,"g"),l[c](r)));return t=t.replace(/\0\0/g,"%"),f=t,p=Array(V(f)+1),G(f,p,0,p.length),(c=p).length>n?0:(h.set(c,e),c.length-1)}function F(e){try{e()}catch(e){A(e)}}var E=0,O=null,T=[],ve={},we={},_e=0,be=null,Se=[];function Ae(t){var e,r={};for(e in t)!function(e){var n=t[e];r[e]="function"==typeof n?function(){T.push(e);try{return n.apply(null,arguments)}finally{v||(T.pop()!==e&&A(void 0),O&&1===E&&0===T.length&&(E=0,F(f._asyncify_stop_unwind),"undefined"!=typeof Fibers)&&Fibers.aa())}}:n}(e);return r}function De(e){var o,a,n,t;v||(0===E?(a=o=!1,e(()=>{if(!v&&(o=!0,a)){E=2,F(()=>f._asyncify_start_rewind(O)),"undefined"!=typeof Browser&&Browser.R.S&&Browser.R.resume();var n=!1;try{var t=(0,f.asm[we[g[O+8>>2]]])()}catch(e){t=e,n=!0}var e,r=!1;if(O||(e=be)&&(be=null,(n?e.reject:e.resolve)(t),r=!0),n&&!r)throw t}}),a=!0,o||(E=1,e=Ce(10485772),n=e+12,g[e>>2]=n,g[e+4>>2]=n+10485760,n=T[0],void 0===(t=ve[n])&&(t=_e++,ve[n]=t,we[t]=n),g[e+8>>2]=t,O=e,F(()=>f._asyncify_start_unwind(O)),"undefined"!=typeof Browser&&Browser.R.S&&Browser.R.pause())):2===E?(E=0,F(f._asyncify_stop_rewind),xe(O),O=null,Se.forEach(e=>pe(e))):A("invalid state: "+E))}var I,Me={d:function(){return 0},i:function(){},r:function(){return 0},f:function(){},a:function(){A("")},g:function(e,n){if(0===e)e=Date.now();else{if(1!==e&&4!==e)return g[Re()>>2]=28,-1;e=le()}return g[n>>2]=e/1e3|0,g[n+4>>2]=e%1e3*1e6|0,0},j:function(e,n,t){var r;for(fe.length=0,t>>=2;r=y[n++];)(r=r<105)&&1&t&&t++,fe.push(r?N[t++>>1]:g[t]),++t;return ie[e].apply(null,fe)},h:function(e,n,t){y.copyWithin(e,n,n+t)},c:function(e){var n=y.length;if(!(2147483648<(e>>>=0)))for(var t=1;t<=4;t*=2){var r=n*(1+.2/t),r=Math.min(r,e+100663296),o=Math;r=Math.max(e,r),o=o.min.call(o,2147483648,r+(65536-r%65536)%65536);e:{try{q.grow(o-B.byteLength+65535>>>16),Z();var a=1;break e}catch(e){}a=void 0}if(a)return!0}return!1},k:function(t){De(e=>{return n=e,setTimeout(function(){pe(n)},t);var n})},n:function(r,o){var a=0;return he().forEach(function(e,n){var t=o+a;for(n=g[r+4*n>>2]=t,t=0;t<e.length;++t)h[n++>>0]=e.charCodeAt(t);h[n>>0]=0,a+=e.length+1}),0},o:function(e,n){var t=he(),r=(g[e>>2]=t.length,0);return t.forEach(function(e){r+=e.length+1}),g[n>>2]=r,0},b:function(e){Pe(e)},e:function(){return 0},q:function(e,n,t,r){return e=ce.Y(e),n=ce.X(e,n,t),g[r>>2]=n,0},l:function(){},p:function(e,n,t,r){for(var o=0,a=0;a<t;a++){var i=g[n>>2],u=g[n+4>>2];n+=8;for(var s=0;s<u;s++){var c=y[i+s],l=se[e];0===c||10===c?((1===e?L:d)(X(l,0)),l.length=0):l.push(c)}o+=u}return g[r>>2]=o,0},m:ge},xe=(!function(){function n(e){e=Ae(e=e.exports),f.asm=e,q=f.asm.s,Z(),Q.unshift(f.asm.t),b--,f.monitorRunDependencies&&f.monitorRunDependencies(b),0==b&&(null!==re&&(clearInterval(re),re=null),S)&&(e=S,S=null,e())}function t(e){n(e.instance)}function r(e){return(i||!U&&!l||"function"!=typeof fetch?Promise.resolve().then(ae):fetch(w,{credentials:"same-origin"}).then(function(e){if(e.ok)return e.arrayBuffer();throw"failed to load wasm binary file at '"+w+"'"}).catch(ae)).then(function(e){return WebAssembly.instantiate(e,o)}).then(function(e){return e}).then(e,function(e){d("failed to asynchronously prepare wasm: "+e),A(e)})}var o={a:Me};if(b++,f.monitorRunDependencies&&f.monitorRunDependencies(b),f.instantiateWasm)try{var e=f.instantiateWasm(o,n);return Ae(e)}catch(e){return d("Module.instantiateWasm callback failed with error: "+e)}(i||"function"!=typeof WebAssembly.instantiateStreaming||oe()||"function"!=typeof fetch?r(t):fetch(w,{credentials:"same-origin"}).then(function(e){return WebAssembly.instantiateStreaming(e,o).then(t,function(e){return d("wasm streaming compile failed: "+e),d("falling back to ArrayBuffer instantiation"),r(t)})})).catch(a)}(),f.___wasm_call_ctors=function(){return(f.___wasm_call_ctors=f.asm.t).apply(null,arguments)},f._main=function(){return(f._main=f.asm.u).apply(null,arguments)},f._command=function(){return(f._command=f.asm.v).apply(null,arguments)},f._isSearching=function(){return(f._isSearching=f.asm.w).apply(null,arguments)},f._free=function(){return(xe=f._free=f.asm.x).apply(null,arguments)}),Re=f.___errno_location=function(){return(Re=f.___errno_location=f.asm.y).apply(null,arguments)},Ce=f._malloc=function(){return(Ce=f._malloc=f.asm.z).apply(null,arguments)},Fe=f.stackSave=function(){return(Fe=f.stackSave=f.asm.B).apply(null,arguments)},Ee=f.stackRestore=function(){return(Ee=f.stackRestore=f.asm.C).apply(null,arguments)},P=f.stackAlloc=function(){return(P=f.stackAlloc=f.asm.D).apply(null,arguments)},Oe=f.dynCall_vi=function(){return(Oe=f.dynCall_vi=f.asm.E).apply(null,arguments)},Te=f.dynCall_v=function(){return(Te=f.dynCall_v=f.asm.F).apply(null,arguments)};function Y(e){this.name="ExitStatus",this.message="Program terminated with exit("+e+")",this.status=e}function Ie(a){function e(){if(!I&&(I=!0,f.calledRun=!0,!v)){if(D(Q),D(ee),j(f),f.onRuntimeInitialized&&f.onRuntimeInitialized(),Ye){var e=a,n=f._main,t=(e=e||[]).length+1,r=P(4*(t+1));g[r>>2]=J(s);for(var o=1;o<t;o++)g[(r>>2)+o]=J(e[o-1]);g[(r>>2)+t]=0;try{Pe(n(t,r))}catch(e){ue(e)}}if(f.postRun)for("function"==typeof f.postRun&&(f.postRun=[f.postRun]);f.postRun.length;)e=f.postRun.shift(),ne.unshift(e);D(ne)}}if(a=a||u,!(0<b)){if(f.preRun)for("function"==typeof f.preRun&&(f.preRun=[f.preRun]);f.preRun.length;)n=void 0,n=f.preRun.shift(),$.unshift(n);D($),0<b||(f.setStatus?(f.setStatus("Running..."),setTimeout(function(){setTimeout(function(){f.setStatus("")},1),e()},1)):e())}var n}function Pe(e){m||0<_||(te=!0),m||0<_||(f.onExit&&f.onExit(e),v=!0),c(e,new Y(e))}if(f._asyncify_start_unwind=function(){return(f._asyncify_start_unwind=f.asm.G).apply(null,arguments)},f._asyncify_stop_unwind=function(){return(f._asyncify_stop_unwind=f.asm.H).apply(null,arguments)},f._asyncify_start_rewind=function(){return(f._asyncify_start_rewind=f.asm.I).apply(null,arguments)},f._asyncify_stop_rewind=function(){return(f._asyncify_stop_rewind=f.asm.J).apply(null,arguments)},f.ccall=function(e,n,t,r,o){function a(e){return--_,0!==s&&Ee(s),"string"===n?z(e):"boolean"===n?!!e:e}var i={string:function(e){var n,t=0;return null!=e&&0!==e&&(n=1+(e.length<<2),t=P(n),G(e,y,t,n)),t},array:function(e){var n=P(e.length);return h.set(e,n),n}},u=(e=f["_"+e],[]),s=0;if(r)for(var c=0;c<r.length;c++){var l=i[t[c]];l?(0===s&&(s=Fe()),u[c]=l(r[c])):u[c]=r[c]}return t=O,r=e.apply(null,u),_+=1,o=o&&o.async,O!=t?new Promise((e,n)=>{be={resolve:e,reject:n}}).then(a):(r=a(r),o?Promise.resolve(r):r)},S=function e(){I||Ie(),I||(S=e)},f.run=Ie,f.preInit)for("function"==typeof f.preInit&&(f.preInit=[f.preInit]);0<f.preInit.length;)f.preInit.pop()();var Ye=!0;return f.noInitialRun&&(Ye=!1),Ie(),e.ready}var je;je="undefined"!=typeof document&&document.currentScript?document.currentScript.src:void 0,"undefined"!=typeof __filename&&(je=je||__filename);return"object"==typeof exports&&"object"==typeof module?module.exports=e:"function"==typeof define&&define.amd?define([],function(){return e}):"object"==typeof exports&&(exports.Stockfish=e),e}function o(e){if(c.ccall("command",null,["string"],[e],{async:"undefined"!=typeof IS_ASYNCIFY&&/^go\b/.test(e)}),"quit"===e){try{c.terminate()}catch(e){}try{self.close()}catch(e){}try{process.exit()}catch(e){}}}function a(){for(;n.length&&(!c._isSearching||!c._isSearching());)o(n.shift())}function i(e){"go"===(e=e.trim()).substring(0,2)||"setoption"===e.substring(0,9)?n.push(e):o(e),a()}function f(){if(c._isReady&&!c._isReady())return setTimeout(f,10);var t;"undefined"==typeof IS_ASYNCIFY?c.onDoneSearching=a:c.onDoneSearching=function(){setTimeout(a,1)},c.processCommand=i,r.length&&(t=0,function e(){for(var n;t<r.length;){if((n=r[t++]).startsWith("sleep "))return setTimeout(e,n.slice(6));i(n)}}())}function p(e,n,t){var t=e/((Date.now()-t||1)/1e3),r=0<t&&e<n?(n-e)/t:0;return{percent:e/n,loaded:e,total:n,speedBytesPerSec:t,speedText:(e=t)<1024?Math.round(e)+" B/s":e<1048576?(e/1024).toFixed(1)+" KB/s":(e/1048576).toFixed(1)+" MB/s",eta:r,etaText:!(n=r)||n<0?"":n<60?Math.ceil(n)+" sec":Math.round(n/60)+" min"}}function d(n){var r,o;function a(e,u){return fetch(e).then(function(e){var o,a,n,t,r,i=Date.now();if(e.ok)return o=l,a=0,n=e.body.getReader(),t=new ReadableStream({start:function(r){!function t(){n.read().then(function(e){var n=e.done,e=e.value;n?(u(i,o,o),r.close()):(a+=e.byteLength,u(i,a,o),r.enqueue(e),t())}).catch(function e(n){r.error(n),e(n)})}()}}),r=new Headers(e.headers),new Response(t,{status:e.status,statusText:e.statusText,headers:r});throw new Error("HTTP "+e.status+": "+e.statusText)})}function i(){return function(e,n,t){s&&(n=p(n,t,e),o=n,r=r||setTimeout(function(){r=null,s.postMessage(o),1<=o.percent&&(s.close(),s=null)},4))}}c={locateFile:function(e){return-1<e.indexOf(".wasm")?-1<e.indexOf(".wasm.map")?u+".map":n||u:self.location.origin+self.location.pathname+"#"+u+",worker"},listener:function(e){postMessage(e)},instantiateWasm:function(n,t){var e=i();return a(u,e).then(function(e){return WebAssembly.instantiateStreaming(e,n)}).then(function(e){return t(e.instance,e.module),e.instance.exports}).catch(function(e){throw console.error("WASM streaming failed:",e),e})}},t()(c).then(f).catch(function(e){setTimeout(function(){throw e},1)})}"undefined"!=typeof self&&"worker"===self.location.hash.split(",")[1]||"undefined"!=typeof global&&"[object process]"===Object.prototype.toString.call(global.process)&&!require("worker_threads").isMainThread||("undefined"!=typeof onmessage&&("undefined"==typeof window||void 0===window.document)||"undefined"!=typeof global&&"[object process]"===Object.prototype.toString.call(global.process)?(e="undefined"!=typeof global&&"[object process]"===Object.prototype.toString.call(global.process),c={},r=[],n=[],e?require.main===module?(e=require("path"),u=e.join(__dirname,e.basename(__filename,e.extname(__filename))+".wasm"),c={locateFile:function(e){return-1<e.indexOf(".wasm")?-1<e.indexOf(".wasm.map")?u+".map":u:__filename},listener:function(e){process.stdout.write(e+"\n")}},r=process.argv.slice(2),t()(c).then(f),require("readline").createInterface({input:process.stdin,output:process.stdout,completer:function(n){var e=["binc ","btime ","confidence ","depth ","infinite ","mate ","maxdepth ","maxtime ","mindepth ","mintime ","moves ","movestogo ","movetime ","ponder ","searchmoves ","shallow ","winc ","wtime "];function t(e){return 0===e.toLowerCase().indexOf(n.toLowerCase())}var r=["compiler","d","eval","flip","go ","isready","ponderhit","position fen ","position startpos","position startpos moves ","quit","setoption name Clear Hash value true","setoption name Hash value ","setoption name Minimum Thinking Time value ","setoption name Move Overhead value ","setoption name MultiPV value ","setoption name Ponder value ","setoption name Skill Level value ","setoption name Slow Mover value ","setoption name Threads value ","setoption name UCI_Chess960 value false","setoption name UCI_Chess960 value true","setoption name UCI_LimitStrength value true","setoption name UCI_LimitStrength value false","setoption name UCI_Elo value ","setoption name UCI_ShowWDL value true","setoption name UCI_ShowWDL value false","setoption name nodestime value ","stop","uci","ucinewgame"].filter(t);return[r=r.length?r:(n=n.replace(/^.*\s/,""))?e.filter(t):e,n]},historySize:100}).on("line",function(e){e&&(c.processCommand?c.processCommand(e):r.push(e),"quit"===e)&&process.exit()}).on("close",function(){process.exit()}).setPrompt("")):module.exports=t:(e=self.location.hash.substr(1).split(","),u=decodeURIComponent(e[0]||location.origin+location.pathname.replace(/\.js$/i,".wasm")),d(),onmessage=onmessage||function(e){if("setoption name CanOutputEngineDownloadProgress"===e.data)postMessage("info WillOutputEngineDownloadProgress");else if(e.data.progressPort)s=e.data.progressPort;else if(c.processCommand?c.processCommand(e.data):r.push(e.data),"quit"===e.data)try{self.close()}catch(e){}})):"object"==typeof document&&document.currentScript?document.currentScript._exports=t():t())}();
