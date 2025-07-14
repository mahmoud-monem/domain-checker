# Domain Checker Proxy Service

A high-performance domain proxy service built with OpenResty (Nginx + Lua) that validates incoming domain requests against a backend API and proxies traffic to appropriate frontends.

## 🚀 Overview

This service acts as a reverse proxy that:

1. Receives requests for any domain
2. Checks if the domain exists in your database via a backend API
3. If valid, proxies the request to the appropriate frontend
4. If invalid, redirects to a fallback URL
5. Provides caching, rate limiting, and comprehensive monitoring

## 🏗️ Architecture

```
[Client Request] → [Domain Checker Proxy] → [Backend API] → [Database]
                                        ↓
[Frontend/Website] ← [Proxy Pass] ← [Domain Validation]
```

## 🔧 Features

- **Domain Validation**: Real-time domain checking against your backend API
- **Intelligent Caching**: Redis-like in-memory caching with configurable TTL
- **Rate Limiting**: Protection against abuse with configurable limits
- **Health Monitoring**: Built-in health checks and comprehensive logging
- **SSL Support**: Production-ready HTTPS configuration
- **Error Handling**: Graceful error handling with fallback mechanisms
- **Performance**: Optimized for high-throughput domain resolution

## 📁 Project Structure

```
domain-checker/
├── docker-compose.yml          # Docker orchestration
├── config.env.example         # Environment configuration template
├── nginx/
│   ├── nginx.conf             # Main nginx configuration
│   ├── conf.d/
│   │   ├── default.conf       # HTTP server configuration
│   │   └── ssl.conf.example   # HTTPS server configuration template
│   └── lua/
│       └── check-domain.lua   # Domain validation logic
└── README.md                  # This file
```

## 🛠️ Setup & Installation

### Prerequisites

- Docker and Docker Compose
- Backend API with domain validation endpoint
- Frontend service for rendering websites

### Quick Start

1. **Clone and configure:**

   ```bash
   git clone <repository-url>
   cd domain-checker
   cp config.env.example config.env
   ```

2. **Configure environment variables:**

   ```bash
   # Edit config.env with your settings
   BACKEND_API_URL=http://your-backend:3010/api/public/funnels/check-domain
   FRONTEND_PRIVATE_URL=http://your-frontend:3010/api/private/funnels/
   FALLBACK_URL=https://your-fallback-domain.com
   ```

3. **Create Docker network:**

   ```bash
   docker network create proxy
   ```

4. **Start the service:**
   ```bash
   docker-compose up -d
   ```

## 🔧 Configuration

### Environment Variables

| Variable               | Description                                | Default                                                 |
| ---------------------- | ------------------------------------------ | ------------------------------------------------------- |
| `BACKEND_API_URL`      | Backend API endpoint for domain validation | `http://localhost:3010/api/public/funnels/check-domain` |
| `FRONTEND_PRIVATE_URL` | Frontend service base URL                  | `http://localhost:3010/api/private/funnels/`            |
| `FALLBACK_URL`         | Redirect URL for invalid domains           | `https://fallback.yourdomain.com`                       |
| `CACHE_TTL`            | Cache duration in seconds                  | `300` (5 minutes)                                       |
| `REQUEST_TIMEOUT`      | API request timeout in milliseconds        | `3000` (3 seconds)                                      |

### Backend API Contract

Your backend API should respond to GET requests with the following format:

**Request:**

```
GET /api/public/funnels/check-domain?domain=example.com
```

**Response (Domain Found):**

```json
{
  "exists": true,
  "private_url": "http://frontend:3010/api/private/funnels/user123/website456/"
}
```

**Response (Domain Not Found):**

```json
{
  "exists": false
}
```

## 🧪 Testing Locally

### 1. Basic Health Check

```bash
curl http://localhost/health
# Expected: "OK"
```

### 2. Test Domain Validation

```bash
# Test with a valid domain (you need to mock your backend)
curl -H "Host: valid-domain.com" http://localhost/

# Test with an invalid domain
curl -H "Host: invalid-domain.com" http://localhost/
# Expected: Redirect to fallback URL
```

### 3. Mock Backend for Testing

Create a simple mock backend:

```bash
# Create a simple mock server
cat > mock-backend.js << 'EOF'
const express = require('express');
const app = express();

app.get('/api/public/funnels/check-domain', (req, res) => {
  const domain = req.query.domain;

  // Mock valid domains
  const validDomains = ['test.com', 'example.com', 'valid-domain.com'];

  if (validDomains.includes(domain)) {
    res.json({
      exists: true,
      private_url: `http://localhost:3010/api/private/funnels/${domain}/`
    });
  } else {
    res.json({
      exists: false
    });
  }
});

app.listen(3010, () => {
  console.log('Mock backend running on port 3010');
});
EOF

# Run mock backend
node mock-backend.js
```

### 4. Test with Docker

```bash
# Set up test environment
export BACKEND_API_URL=http://host.docker.internal:3010/api/public/funnels/check-domain
export FRONTEND_PRIVATE_URL=http://host.docker.internal:3010/api/private/funnels/
export FALLBACK_URL=https://fallback.example.com

# Start the service
docker-compose up -d

# Test valid domain
curl -H "Host: test.com" http://localhost/

# Test invalid domain
curl -H "Host: nonexistent.com" http://localhost/
```

## 📊 Monitoring & Logging

### Log Files

- **Access Log**: `/var/log/nginx/access.log`
- **Error Log**: `/var/log/nginx/error.log`
- **Domain Check Log**: `/var/log/nginx/domain_check.log`

### Health Endpoints

- **Health Check**: `GET /health`
- **Cache Management**: `GET /admin/cache/clear` (localhost only)

### Monitoring Commands

```bash
# View logs
docker-compose logs -f nginx

# Check cache status
curl http://localhost/admin/cache/clear

# Monitor domain checks
docker-compose exec nginx tail -f /var/log/nginx/domain_check.log
```

## 🔒 Production Deployment

### SSL Configuration

1. **Obtain SSL certificates:**

   ```bash
   # Using Let's Encrypt
   certbot certonly --webroot -w /var/www/html -d yourdomain.com
   ```

2. **Configure SSL:**

   ```bash
   cp nginx/conf.d/ssl.conf.example nginx/conf.d/ssl.conf
   # Edit ssl.conf with your certificate paths
   ```

3. **Update Docker Compose:**
   ```yaml
   volumes:
     - /etc/letsencrypt:/etc/letsencrypt:ro
     - ./nginx/conf.d/ssl.conf:/etc/nginx/conf.d/ssl.conf:ro
   ```

### Security Considerations

- Enable SSL/TLS in production
- Use proper DNS resolvers
- Implement proper access controls for admin endpoints
- Monitor rate limiting effectiveness
- Regular security updates

### Performance Tuning

- Adjust cache TTL based on your domain change frequency
- Configure worker processes based on CPU cores
- Monitor memory usage and adjust shared dictionary sizes
- Use HTTP/2 for better performance

## 🚦 Rate Limiting

The service implements rate limiting to prevent abuse:

- **10 requests per second** per IP address
- **Burst capacity**: 20 requests
- **60 requests per minute** per IP address

Configure in `nginx/nginx.conf`:

```nginx
limit_req_zone $binary_remote_addr zone=domain_check:10m rate=10r/s;
```

## 🔄 Caching Strategy

The service uses intelligent caching:

- **Valid domains**: Cached for `CACHE_TTL` seconds (default: 5 minutes)
- **Invalid domains**: Cached for `CACHE_TTL` seconds
- **API errors**: Cached for 60 seconds to prevent cascading failures
- **Cache key format**: `domain:example.com`

## 🐛 Troubleshooting

### Common Issues

1. **Connection refused errors:**

   - Check if backend API is running
   - Verify `BACKEND_API_URL` configuration

2. **502 Bad Gateway:**

   - Check if frontend service is accessible
   - Verify `FRONTEND_PRIVATE_URL` configuration

3. **Cache not working:**

   - Check shared dictionary size in `nginx.conf`
   - Verify cache TTL configuration

4. **Rate limiting too aggressive:**
   - Adjust rate limit in `nginx.conf`
   - Increase burst capacity

### Debug Mode

Enable debug logging:

```bash
# Edit nginx/nginx.conf
error_log /var/log/nginx/error.log debug;
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙋 Support

For issues and questions:

- Check the troubleshooting section
- Review logs for error messages
- Open an issue in the repository

---

**Built with ❤️ using OpenResty, Lua, and Docker**
