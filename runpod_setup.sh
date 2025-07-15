#!/bin/bash
# RunPod Setup Script for VoIP Scam Detection System
# Follows best practices with virtual environment

echo "🚀 Setting up VoIP Scam Detection System on RunPod..."
echo "======================================================"

# Update system packages
echo "📦 Updating system packages..."
apt-get update && apt-get upgrade -y

# Install system dependencies
echo "🔧 Installing system dependencies..."
apt-get install -y \
    build-essential \
    python3-dev \
    python3-pip \
    python3-venv \
    git \
    curl \
    ffmpeg \
    nodejs \
    npm \
    supervisor \
    nginx \
    software-properties-common

# Install Ollama for LLM processing
echo "🤖 Installing Ollama for LLM processing..."
curl -fsSL https://ollama.ai/install.sh | sh

# Start Ollama service in background
echo "🚀 Starting Ollama service..."
ollama serve &
sleep 5

# Pull the required model
echo "📥 Downloading LLM model..."
ollama pull hermes3:8b

# Set up Python virtual environment
echo "🐍 Setting up Python virtual environment..."
cd /workspace/voip-app-flutter
python3 -m venv venv
source venv/bin/activate

# Upgrade pip in virtual environment
pip install --upgrade pip

# Install Python dependencies in virtual environment
echo "📚 Installing Python dependencies..."
cd python_api
pip install -r requirements.txt
cd ..

# Install Node.js dependencies
echo "🟢 Installing Node.js dependencies..."
npm install

# Configure environment variables
echo "⚙️ Setting up environment variables..."
cp python_api/.env.example python_api/.env

# Configure Supervisor for process management
echo "🔧 Configuring Supervisor..."
cat > /etc/supervisor/conf.d/voip-system.conf << 'EOF'
[group:voip]
programs=ollama,python-api,node-bridge

[program:ollama]
command=ollama serve
user=root
autostart=true
autorestart=true
stderr_logfile=/var/log/ollama.err.log
stdout_logfile=/var/log/ollama.out.log
environment=OLLAMA_HOST=0.0.0.0:11434

[program:python-api]
command=/workspace/voip-app-flutter/venv/bin/python main.py
directory=/workspace/voip-app-flutter/python_api
user=root
autostart=true
autorestart=true
stderr_logfile=/var/log/python-api.err.log
stdout_logfile=/var/log/python-api.out.log
environment=PATH="/workspace/voip-app-flutter/venv/bin:%(ENV_PATH)s",PYTHONUNBUFFERED=1

[program:node-bridge]
command=node bridge_server.js
directory=/workspace/voip-app-flutter
user=root
autostart=true
autorestart=true
stderr_logfile=/var/log/node-bridge.err.log
stdout_logfile=/var/log/node-bridge.out.log
EOF

# Configure Nginx reverse proxy
echo "🌐 Configuring Nginx..."
cat > /etc/nginx/sites-available/voip-system << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    location /api/ {
        proxy_pass http://localhost:8000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    location /bridge/ {
        proxy_pass http://localhost:3001/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    location /socket.io/ {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    location /health {
        return 200 "VoIP Scam Detection System - Running\n";
        add_header Content-Type text/plain;
    }
}
EOF

# Enable the site
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/voip-system /etc/nginx/sites-enabled/

# Create log directories
mkdir -p /var/log/voip-system

# Start services
echo "🎯 Starting services..."
supervisorctl reread
supervisorctl update
nginx -t && systemctl restart nginx

# Wait for services to start
echo "⏳ Waiting for services to initialize..."
sleep 10

# Final status check
echo "✅ VoIP Scam Detection System deployed successfully!"
echo "📊 Service Status:"
supervisorctl status

echo ""
echo "🌍 System URLs:"
echo "- Health Check: http://localhost/health"
echo "- Python API: http://localhost/api/"
echo "- Node Bridge: http://localhost/bridge/"
echo "- WebSocket: ws://localhost/socket.io/"
echo ""
echo "📋 To check logs:"
echo "- Python API: tail -f /var/log/python-api.out.log"
echo "- Node Bridge: tail -f /var/log/node-bridge.out.log"
echo "- Nginx: tail -f /var/log/nginx/access.log"
echo ""
echo "🔄 To activate virtual environment manually:"
echo "source /workspace/voip-app-flutter/venv/bin/activate"
echo ""
echo "🎉 Deployment complete! Your VoIP Scam Detection System is ready."
