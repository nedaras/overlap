const http = require('http');

// Keep track of connections
const server = http.createServer((req, res) => {
  res.writeHead(200, {
    'Content-Type': 'text/plain',
    'Connection': 'keep-alive', // Enable keep-alive
  });
  res.end('Hello, World!\n');
});

// Log when a new TCP connection is made
server.on('connection', (socket) => {
  console.log('New TCP connection established');

  socket.on('close', () => {
    console.log('TCP connection closed');
  });
});

// Start server
server.listen(3000, () => {
  console.log('Server running on http://localhost:3000');
});
