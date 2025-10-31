# Sudoku Arena (Flutter + Node.js, Socket.IO)

Real-time multiplayer Sudoku: fast matchmaking, graceful reconnects, and clean Material 3 UI.  
**Client:** Flutter · **Server:** Node.js + Socket.IO · **Hosting:** Render.com

> Live server (example): `https://sudoku-realtime.onrender.com`

---

## ✨ Features

- **Single Player** — random puzzles, timer, completion dialog  
- **Multiplayer 1v1** — queue → room → ready → start → win → rematch  
- **Robust networking** — Socket.IO with **WebSocket + polling fallback**  
- **Reconnect flow** — 8s grace timer, resume into room  
- **Theming** — light/dark, persisted via `SharedPreferences`  
- **Smooth UX** — subtle animations, keypad, responsive layout

---

## 🧱 Tech Stack

- **Flutter** (`socket_io_client`, `google_fonts`, `shared_preferences`)  
- **Node.js** (Express, Socket.IO)  
- **Deploy**: Render Web Service (auto `PORT`, HTTPS)

---

## 📁 Structure

sudoku-server/
├── sudoku_app/ # Flutter client
│ ├── lib/
│ │ ├── models/
│ │ │ └── sudoku.dart
│ │ ├── net/
│ │ │ └── server_config.dart
│ │ ├── screens/
│ │ │ ├── game_room_screen.dart
│ │ │ ├── home_screen.dart
│ │ │ ├── multiplayer_find_screen.dart
│ │ │ └── single_player_screen.dart
│ │ ├── theme/
│ │ │ ├── app_theme.dart
│ │ │ └── theme_controller.dart
│ │ ├── widgets/
│ │ │ ├── animated_bg.dart
│ │ │ ├── board_entrance.dart
│ │ │ └── sudoku_grid.dart
│ │ └── main.dart
│ └── pubspec.yaml
├── server.js # Node/Socket.IO backend
├── client.html # tiny browser sanity client
├── package.json
├── .gitignore
└── README.md


> Tip: `sudoku_grid.dart` should define the `SudokuGrid` widget used by the screens.

---

## ⚙️ Setup

### 1) Server (local)

```bash
npm install
node server.js
# Health check:
# http://localhost:3000/health  ->  {"ok":true}

Render deploy (prod):

Create Web Service → Start command: node server.js
Server reads PORT. CORS is permissive for dev.
Health route: /health

2) Client (Flutter)

Update your server URL(s) in sudoku_app/lib/net/server_config.dart:

class ServerConfig {
  static const List<String> socketCandidates = [
    'https://sudoku-realtime.onrender.com', // production
    // 'http://10.0.2.2:3000',  // Android emulator -> host
    // 'http://127.0.0.1:3000', // Flutter web (same machine)
    // 'http://<LAN-IP>:3000',  // physical phone over Wi-Fi
  ];
}

Run:
cd sudoku_app
flutter pub get
flutter run

Build APK (release):
flutter build apk --release
# output: sudoku_app/build/app/outputs/flutter-apk/app-release.apk

🔌 Socket Events (contract)

Client → Server

client:hello { name }

match:find { name }

match:cancel

game:ready { roomId }

game:finish { roomId, grid }

game:rematch_request { roomId }

resume:request { roomId, name }

Server → Client

server:welcome { id }

match:status { finding, queueSize }

match:found { roomId, opponentName }

game:start { roomId, puzzle, startAt }

game:finish_rejected

game:win { winnerSocketId, elapsedMs }

game:rematch_status { waiting }

game:rematch_denied { reason }

opponent:disconnected { graceMs }

opponent:reconnected

resume:ok { roomId, startAtMs, puzzle }

🧪 Quick Checks

Browser sanity test (with server running): open client.html.

Polling endpoint (from device):
https://<server>/socket.io/?EIO=4&transport=polling → should return a short payload.

🛠 Troubleshooting

Cannot connect on some networks
Client uses transports ['websocket','polling'] and ~10s initial timeout in MultiplayerFindScreen (so strict/captive networks still work).

Emulator to local server
Use http://10.0.2.2:3000 (not localhost).

Release builds
Use HTTPS server; ensure Android manifest has:

<uses-permission android:name="android.permission.INTERNET"/>

Frequent disconnects (mobile)
You can relax server pings in server.js:

const io = new Server(httpServer, {
  cors: { origin: '*', methods: ['GET','POST'] },
  pingTimeout: 30000,
  pingInterval: 25000,
});
