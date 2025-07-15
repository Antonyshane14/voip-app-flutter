#!/bin/bash

# VoIP Signaling Server - Heroku Deployment Script
echo "🚀 VoIP Signaling Server - Heroku Deployment"
echo "============================================"

# Check if Heroku CLI is installed
if ! command -v heroku &> /dev/null; then
    echo "❌ Heroku CLI not found. Please install it first:"
    echo "   https://devcenter.heroku.com/articles/heroku-cli"
    exit 1
fi

# Check if user is logged in to Heroku
if ! heroku auth:whoami &> /dev/null; then
    echo "🔐 Please login to Heroku:"
    heroku login
fi

# Navigate to signaling server directory
cd signaling_server

# Check if git is initialized
if [ ! -d ".git" ]; then
    echo "📦 Initializing Git repository..."
    git init
    git add .
    git commit -m "Initial VoIP signaling server for Heroku deployment"
fi

# Ask for app name
echo ""
read -p "Enter your Heroku app name (or press Enter for auto-generated): " APP_NAME

# Create Heroku app
echo ""
echo "🏗️ Creating Heroku app..."
if [ -z "$APP_NAME" ]; then
    heroku create
else
    heroku create $APP_NAME
fi

# Get the app URL
APP_URL=$(heroku info -s | grep web_url | cut -d= -f2)
echo "📡 Your app URL: $APP_URL"

# Deploy to Heroku
echo ""
echo "🚀 Deploying to Heroku..."
git add .
git commit -m "Deploy VoIP signaling server" --allow-empty
git push heroku main

# Check deployment status
echo ""
echo "📊 Checking deployment status..."
heroku ps:scale web=1
heroku ps

echo ""
echo "✅ Deployment completed!"
echo "📡 App URL: $APP_URL"
echo "🔍 Health check: ${APP_URL}health"
echo "👥 Users endpoint: ${APP_URL}users"
echo ""
echo "🔧 Next steps:"
echo "1. Update lib/main.dart with your app URL: $APP_URL"
echo "2. Replace 'https://your-voip-app.herokuapp.com' with: $APP_URL"
echo "3. Rebuild your Flutter APK: flutter build apk --release"
echo ""
echo "📜 View logs: heroku logs --tail"
echo "🔄 Redeploy: git push heroku main"
