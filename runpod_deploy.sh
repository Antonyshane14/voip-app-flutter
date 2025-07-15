#!/bin/bash

# VoIP Scam Detection System - RunPod Deployment Script
echo "🚀 VoIP Scam Detection System - RunPod Setup"
echo "============================================="

# Check if we're on RunPod
if [ -z "$RUNPOD_POD_ID" ]; then
    echo "⚠️  Warning: Not running on RunPod. This script is optimized for RunPod environment."
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Install system dependencies
echo "📦 Installing system dependencies..."
apt-get update
apt-get install -y \
    ffmpeg \
    sox \
    nodejs \
    npm \
    python3-pip \
    git \
    curl \
    wget

# Install Python dependencies for scam detection
echo "🐍 Setting up Python environment..."
cd /workspace
pip install -r requirements_scam.txt

# Install Node.js dependencies for bridge service
echo "🌉 Setting up Node.js bridge service..."
cd /workspace/scam_detection_bridge
npm install

# Create systemd services for auto-start
echo "⚙️  Creating system services..."

# Python API service
cat > /etc/systemd/system/scam-api.service << EOF
[Unit]
Description=VoIP Scam Detection API
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/workspace
ExecStart=/usr/bin/python3 main.py
Restart=always
RestartSec=3
Environment=PYTHONPATH=/workspace
Environment=HF_TOKEN=your_huggingface_token_here

[Install]
WantedBy=multi-user.target
EOF

# Node.js Bridge service
cat > /etc/systemd/system/scam-bridge.service << EOF
[Unit]
Description=VoIP Scam Detection Bridge
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/workspace/scam_detection_bridge
ExecStart=/usr/bin/node bridge_server.js
Restart=always
RestartSec=3
Environment=NODE_ENV=production
Environment=PYTHON_API_URL=http://localhost:8000

[Install]
WantedBy=multi-user.target
EOF

# Enable and start services
systemctl daemon-reload
systemctl enable scam-api.service
systemctl enable scam-bridge.service

echo "🔧 Services created. Starting services..."
systemctl start scam-api.service
systemctl start scam-bridge.service

# Wait a moment and check status
sleep 5
echo "📊 Service Status:"
systemctl status scam-api.service --no-pager -l
systemctl status scam-bridge.service --no-pager -l

# Create health check script
cat > /workspace/health_check.sh << 'EOF'
#!/bin/bash
echo "🏥 VoIP Scam Detection Health Check"
echo "=================================="

echo "🐍 Python API (Port 8000):"
curl -s http://localhost:8000/health || echo "❌ Python API not responding"

echo ""
echo "🌉 Bridge Service (Port 3001):"
curl -s http://localhost:3001/health || echo "❌ Bridge service not responding"

echo ""
echo "🔗 Bridge -> Python connectivity:"
curl -s http://localhost:3001/test-python-api || echo "❌ Bridge cannot reach Python API"

echo ""
echo "📊 Service Status:"
systemctl is-active scam-api.service
systemctl is-active scam-bridge.service
EOF

chmod +x /workspace/health_check.sh

# Get external IP for mobile data access
EXTERNAL_IP=$(curl -s ifconfig.me)

echo ""
echo "✅ Deployment Complete!"
echo "======================"
echo "🐍 Python API: http://localhost:8000 (internal)"
echo "🌉 Bridge Service: http://localhost:3001 (internal)"
echo "🌍 External Access: http://$EXTERNAL_IP:3001 (for mobile data)"
echo ""
echo "📱 Update your Flutter app's bridge URL to:"
echo "   - Local network: http://192.168.x.x:3001"
echo "   - Mobile data: http://$EXTERNAL_IP:3001"
echo ""
echo "🔧 Commands:"
echo "   Health check: /workspace/health_check.sh"
echo "   View logs: journalctl -u scam-api.service -f"
echo "   View logs: journalctl -u scam-bridge.service -f"
echo "   Restart: systemctl restart scam-api.service scam-bridge.service"
