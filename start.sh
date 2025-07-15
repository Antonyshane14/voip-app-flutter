#!/bin/bash

echo "🚀 Starting VoIP App with AI Scam Detection"
echo "=========================================="

# Check if required tools are installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed. Please install Node.js first."
    exit 1
fi

if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is not installed. Please install Python 3 first."
    exit 1
fi

if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed. Please install Flutter first."
    exit 1
fi

# Install dependencies if node_modules doesn't exist
if [ ! -d "node_modules" ]; then
    echo "📦 Installing Node.js dependencies..."
    npm install
fi

# Check Python dependencies
if [ ! -d "python_api/venv" ]; then
    echo "🐍 Setting up Python virtual environment..."
    cd python_api
    python3 -m venv venv
    source venv/bin/activate
    pip install -r requirements.txt
    cd ..
fi

echo ""
echo "✅ Setup complete!"
echo ""
echo "To start the services:"
echo "1. Terminal 1: cd python_api && source venv/bin/activate && python main.py"
echo "2. Terminal 2: npm start"
echo "3. Terminal 3: flutter run"
echo ""
echo "📱 The app will automatically discover the server on your local network"
