const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const cors = require('cors');

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

app.use(cors());
app.use(express.json());

// Store user connections
const connectedUsers = new Map();
const userSockets = new Map();

// Basic health check
app.get('/', (req, res) => {
  res.json({ 
    status: 'VoIP Signaling Server Running',
    message: 'WebRTC signaling server for local VoIP calls',
    connected_users: connectedUsers.size,
    timestamp: new Date().toISOString()
  });
});

// Socket.IO connection handling
io.on('connection', (socket) => {
  console.log('New client connected:', socket.id);

  // User registration
  socket.on('register', (userId) => {
    console.log(`User ${userId} registered with socket ${socket.id}`);
    connectedUsers.set(userId, socket.id);
    userSockets.set(socket.id, userId);
    
    // Broadcast updated user list
    io.emit('user-list', Array.from(connectedUsers.keys()));
  });

  // Call initiation
  socket.on('call-user', (data) => {
    const { targetUserId, signalData, from } = data;
    const targetSocketId = connectedUsers.get(targetUserId);
    
    if (targetSocketId) {
      console.log(`Call from ${from} to ${targetUserId}`);
      io.to(targetSocketId).emit('incoming-call', {
        from: from,
        signal: signalData
      });
    } else {
      socket.emit('call-failed', { error: 'User not found or offline' });
    }
  });

  // Call acceptance
  socket.on('accept-call', (data) => {
    const { to, signalData } = data;
    const targetSocketId = connectedUsers.get(to);
    
    if (targetSocketId) {
      console.log(`Call accepted by ${userSockets.get(socket.id)} to ${to}`);
      io.to(targetSocketId).emit('call-accepted', {
        signal: signalData
      });
    }
  });

  // Call rejection
  socket.on('reject-call', (data) => {
    const { to } = data;
    const targetSocketId = connectedUsers.get(to);
    
    if (targetSocketId) {
      console.log(`Call rejected by ${userSockets.get(socket.id)} to ${to}`);
      io.to(targetSocketId).emit('call-rejected');
    }
  });

  // Call termination
  socket.on('end-call', (data) => {
    const { to } = data;
    const targetSocketId = connectedUsers.get(to);
    
    if (targetSocketId) {
      console.log(`Call ended by ${userSockets.get(socket.id)} to ${to}`);
      io.to(targetSocketId).emit('call-ended');
    }
  });

  // WebRTC signaling
  socket.on('signal', (data) => {
    const { targetUserId, signalData } = data;
    const targetSocketId = connectedUsers.get(targetUserId);
    
    if (targetSocketId) {
      io.to(targetSocketId).emit('signal', {
        signal: signalData,
        from: userSockets.get(socket.id)
      });
    }
  });

  // Handle disconnection
  socket.on('disconnect', () => {
    const userId = userSockets.get(socket.id);
    if (userId) {
      console.log(`User ${userId} disconnected`);
      connectedUsers.delete(userId);
      userSockets.delete(socket.id);
      
      // Broadcast updated user list
      io.emit('user-list', Array.from(connectedUsers.keys()));
    }
  });
});

// Get connected users endpoint
app.get('/users', (req, res) => {
  res.json({
    users: Array.from(connectedUsers.keys()),
    count: connectedUsers.size,
    timestamp: new Date().toISOString()
  });
});

// Server status endpoint
app.get('/status', (req, res) => {
  res.json({
    status: 'running',
    uptime: process.uptime(),
    connected_users: connectedUsers.size,
    memory: process.memoryUsage(),
    timestamp: new Date().toISOString()
  });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`🚀 VoIP Signaling Server running on port ${PORT}`);
  console.log(`📡 WebRTC signaling for local network calls`);
  console.log(`💾 Call recordings are stored locally on client devices`);
});
