#!/bin/sh
set -e

# Create log directory if it doesn't exist
mkdir -p /var/log/nginx

# Set proper permissions (nginx user might not exist in Alpine, so use fallback)
chown -R nobody:nobody /var/log/nginx 2>/dev/null || chmod -R 755 /var/log/nginx

# Test nginx configuration
echo "Testing nginx configuration..."
nginx -t

# Start nginx
echo "Starting nginx..."
exec nginx -g "daemon off;" 