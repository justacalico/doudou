# Doudou Docker Deployment

This directory contains Docker configuration files for deploying Doudou as a web application.

## Quick Start

### Option 1: Using Docker Run
```bash
# Pull and run the latest image
docker run -d -p 34273:34273 --name doudou-web httpanimations/doudou:latest

# Access at http://localhost:34273
```

### Option 2: Using Docker Compose
```bash
# Start the service
docker-compose up -d

# View logs
docker-compose logs -f

# Stop the service
docker-compose down
```

### Option 3: Build from Source
```bash
# Clone the repository and build
git clone <repository-url>
cd doudou
./docker-build.sh
```

## Configuration

The web application runs on port **34273** by default.

### Environment Variables
Currently, Doudou doesn't require environment variables as it connects directly to your media server through the web interface.

### Volumes
No persistent volumes are required for the web application itself, as all data is stored on your media server.

## Networking

Make sure your media server (Jellyfin/Plex/Navidrome) is accessible from where you're running the Docker container:

- **Same host**: Use `localhost` or `127.0.0.1`
- **Different host**: Use the server's IP address
- **Docker network**: Consider using Docker's networking features

## Health Check

The container includes a health check endpoint at `/health` that returns a 200 status when the service is running properly.

## Troubleshooting

### Container won't start
```bash
# Check logs
docker logs doudou-web

# Check if port is already in use
netstat -tlnp | grep 34273
```

### Can't connect to media server
- Ensure your media server is running and accessible
- Check firewall settings
- For Jellyfin, ensure CORS is configured if needed
- For Plex, ensure you have Plex Pass for streaming

### Audio playback fails with CORS errors
The web version includes automatic fallback handling for CORS issues:
- First tries direct stream URL from media server
- Falls back to alternative URLs if CORS blocks the request
- Uses relaxed CORS headers in nginx configuration
- If issues persist, try accessing Jellyfin/Plex directly in browser first to verify connectivity

### Performance issues
- The web version uses browser-based audio, which may have different performance characteristics than native apps
- Consider using the desktop or mobile versions for better performance

## Building Custom Images

To build with custom modifications:

```bash
# Edit the source code as needed
# Then build:
./docker-build.sh
```

## Security Considerations

- The web application itself doesn't store sensitive data
- All authentication is handled through your media server
- Consider using HTTPS if exposing to the internet
- Use a reverse proxy (nginx, Traefik) for production deployments

## Updates

To update to the latest version:

```bash
# Pull latest image
docker pull httpanimations/doudou:latest

# Restart container
docker-compose down && docker-compose up -d
```

## Support

For issues related to the Docker deployment, please check:
1. Container logs: `docker logs doudou-web`
2. Media server accessibility
3. Network configuration
4. Browser console for web-specific issues