# Dockerfile for Doudou Web Application
# Multi-stage build for optimal image size

# Stage 1: Build the Flutter web app
FROM ubuntu:22.04 AS builder

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Install Flutter
RUN git clone https://github.com/flutter/flutter.git /flutter
ENV PATH="/flutter/bin:${PATH}"

# Enable web support
RUN flutter config --enable-web

# Set working directory
WORKDIR /app

# Copy pubspec files first for better caching
COPY pubspec.yaml pubspec.lock ./

# Get Flutter dependencies
RUN flutter pub get

# Copy the rest of the application
COPY . .

# Build the web application
RUN flutter build web --release

# Stage 2: Serve the web app with nginx
FROM nginx:alpine

# Copy the built web app from the builder stage
COPY --from=builder /app/build/web /usr/share/nginx/html

# Copy nginx configuration
COPY <<EOF /etc/nginx/conf.d/default.conf
server {
    listen 34273;
    server_name localhost;
    
    root /usr/share/nginx/html;
    index index.html;
    
    # Enable gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;
    
    # Handle Flutter web routing
    location / {
        try_files \$uri \$uri/ /index.html;
        
        # Add headers for Flutter web
        add_header 'Cross-Origin-Embedder-Policy' 'require-corp';
        add_header 'Cross-Origin-Opener-Policy' 'same-origin';
        
        # Cache static assets
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }
    
    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF

# Expose the port
EXPOSE 34273

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:34273/health || exit 1

# Labels for metadata
LABEL maintainer="HttpAnimations" \
      description="Doudou - Privacy-focused music player web interface" \
      version="7.0.0"

# Start nginx
CMD ["nginx", "-g", "daemon off;"]