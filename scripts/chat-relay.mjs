import { WebSocketServer } from 'ws';
import { createServer } from 'http';

const PORT = Number(process.env.PORT || process.argv[2] || 8787);

const server = createServer();
const wss = new WebSocketServer({ server });

function broadcast(room, data, sender) {
  const payload = JSON.stringify(data);
  wss.clients.forEach((client) => {
    if (client.readyState === client.OPEN && client.room === room && client !== sender) {
      client.send(payload);
    }
  });
}

wss.on('connection', (ws, req) => {
  const { searchParams } = new URL(req.url, `http://${req.headers.host}`);
  const room = searchParams.get('room') || 'default';
  ws.room = room;

  ws.on('message', (msg) => {
    try {
      const parsed = JSON.parse(msg.toString());
      if (parsed.type === 'chat-message' && parsed.room === room) {
        broadcast(room, parsed, ws);
      }
    } catch (err) {
      console.error('Invalid payload', err);
    }
  });
});

server.listen(PORT, () => {
  console.log(`Chat relay listening on ws://localhost:${PORT}`);
});
