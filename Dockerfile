# VoIP Scam Detection System - Unified Dockerfile
FROM python:3.10-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    ffmpeg \
    sox \
    curl \
    wget \
    git \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 18.x
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y nodejs

# Set working directory
WORKDIR /app

# Copy Python requirements and install
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Copy package.json files and install Node.js dependencies
COPY package.json ./
COPY scam_detection_bridge/package.json ./scam_detection_bridge/
COPY signaling_server/package.json ./signaling_server/

RUN npm install && \
    cd scam_detection_bridge && npm install && \
    cd ../signaling_server && npm install

# Copy application code
COPY . .

# Create necessary directories
RUN mkdir -p python_api/temp_audio \
    python_api/cache \
    python_api/speaker_segments \
    recordings \
    temp_recordings

# Expose ports
EXPOSE 3000 3001 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health && \
        curl -f http://localhost:3001/health && \
        curl -f http://localhost:3000/ || exit 1

# Start all services
CMD ["./start_unified_system.sh"]
