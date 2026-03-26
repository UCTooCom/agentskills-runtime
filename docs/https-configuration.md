# HTTPS/SSL Configuration Guide

This guide provides detailed instructions for configuring HTTPS/SSL in the agentskills-runtime.

## Overview

The agentskills-runtime supports both HTTP and HTTPS modes for secure API communication. HTTPS mode provides:
- Encrypted communication between clients and the server
- Protection against man-in-the-middle attacks
- Compliance with security best practices
- Support for modern web standards requiring HTTPS

## Quick Start

### 1. Enable HTTPS in Configuration

Add the following to your `.env` file:

```env
# Set BACKEND_URL to https:// to enable HTTPS
BACKEND_URL=https://your-domain.com

# Optional: Specify custom port (default: 8080)
PORT=8443

# Optional: Specify bind address (default: 0.0.0.0)
HOST=0.0.0.0

# Optional: Specify SSL certificate and key paths (default: ssl/server.crt and ssl/server.key)
CERT_FILE_NAME=ssl/server.crt
KEY_FILE_NAME=ssl/server.key
```

### 2. Place SSL Certificates

Create the `ssl/` directory and place your certificates:

```bash
ssl/
├── server.crt    # SSL certificate (PEM format)
└── server.key    # Private key (PEM format)
```

Alternatively, you can specify custom certificate paths using `CERT_FILE_NAME` and `KEY_FILE_NAME`:

```env
# Use absolute paths
CERT_FILE_NAME=/etc/ssl/certs/your-domain.com.crt
KEY_FILE_NAME=/etc/ssl/private/your-domain.com.key

# Or use relative paths
CERT_FILE_NAME=certs/server.crt
KEY_FILE_NAME=certs/server.key
```

### 3. Start the Server

```bash
cjpm run --skip-build --name magic.app
```

The server will automatically detect HTTPS mode and load the certificates from the configured paths.

## Certificate Requirements

### Format
- **Certificate Format**: PEM (Privacy Enhanced Mail)
- **Certificate Type**: X.509 certificate chain
- **Private Key**: RSA or ECDSA private key
- **File Encoding**: UTF-8 text format

### Certificate Chain
For production use, the certificate file should include the full certificate chain:
1. Your domain certificate
2. Intermediate CA certificates
3. Root CA certificate (optional)

### File Permissions
Ensure proper security for your private key:

```bash
# Restrict private key access
chmod 600 ssl/server.key
chown your-user:your-group ssl/server.key
```

## Obtaining SSL Certificates

### Option 1: Let's Encrypt (Recommended for Production)

Let's Encrypt provides free, automated SSL certificates:

```bash
# Install certbot
sudo apt-get install certbot

# Obtain certificate
sudo certbot certonly --standalone -d your-domain.com

# Copy certificates to ssl/ directory
cat /etc/letsencrypt/live/your-domain.com/fullchain.pem > ./ssl/server.crt
cat /etc/letsencrypt/live/your-domain.com/privkey.pem > ./ssl/server.key

# Set permissions
chmod 600 ./ssl/server.key
```

### Option 2: Commercial SSL Certificate

1. Purchase SSL certificate from a CA (e.g., DigiCert, Comodo, GeoTrust)
2. Generate CSR (Certificate Signing Request)
3. Submit CSR to CA
4. Download signed certificate
5. Combine certificate chain into `server.crt`
6. Place private key in `server.key`

### Option 3: Self-Signed Certificate (Development Only)

For development and testing:

```bash
# Generate self-signed certificate
openssl req -x509 -newkey rsa:4096 \
  -keyout ./ssl/server.key \
  -out ./ssl/server.crt \
  -days 365 -nodes \
  -subj "/CN=localhost"

# Set permissions
chmod 600 ./ssl/server.key
```

> **Warning**: Self-signed certificates will trigger security warnings in browsers and should only be used for development.

## Configuration Details

### Environment Variables

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `BACKEND_URL` | Backend URL (determines HTTP/HTTPS mode) | - | `https://your-domain.com` |
| `PORT` | Server listening port | `8080` | `443` or `8443` |
| `HOST` | Server bind address | `0.0.0.0` | `127.0.0.1` |
| `CERT_FILE_NAME` | SSL certificate file path | `ssl/server.crt` | `/etc/ssl/server.crt` |
| `KEY_FILE_NAME` | SSL private key file path | `ssl/server.key` | `/etc/ssl/server.key` |

### Auto-Detection Logic

The runtime automatically determines the protocol mode:

1. If `BACKEND_URL` starts with `https://` → HTTPS mode
2. If `BACKEND_URL` starts with `http://` or is not set → HTTP mode

### Certificate Loading

Certificates are loaded at server startup:

1. Check `BACKEND_URL` for HTTPS mode
2. Read `CERT_FILE_NAME` from environment (default: `ssl/server.crt`)
3. Read `KEY_FILE_NAME` from environment (default: `ssl/server.key`)
4. Process paths (add `./` prefix for relative paths)
5. Load certificate and private key files
6. Configure TLS with `TlsServerConfig`
7. Start HTTPS server

If certificate loading fails, the server will not start and will log an error.

### Path Processing

The runtime intelligently handles certificate paths:

- **Relative paths**: Automatically prefixed with `./`
  - `ssl/server.crt` → `./ssl/server.crt`
  - `certs/server.crt` → `./certs/server.crt`
  
- **Absolute paths**: Used as-is
  - `/etc/ssl/server.crt` → `/etc/ssl/server.crt`
  - `D:/ssl/server.crt` → `D:/ssl/server.crt`
  
- **Already prefixed**: Used as-is
  - `./ssl/server.crt` → `./ssl/server.crt`

## TLS Configuration

### Supported TLS Versions
- TLS 1.2
- TLS 1.3 (preferred)

### Cipher Suites
The runtime uses secure default cipher suites. No manual configuration is required.

### Certificate Verification
- Client certificates are not required (single-sided TLS)
- Server certificate is presented to clients
- Clients verify the server certificate against their trust store

## Testing HTTPS

### Using curl

```bash
# Test with certificate verification
curl https://your-domain.com:8443/api/v1/health

# Test without certificate verification (self-signed certs)
curl -k https://localhost:8443/api/v1/health

# Test with specific certificate
curl --cacert /path/to/ca.crt https://your-domain.com:8443/api/v1/health
```

### Using PowerShell

```powershell
# Test HTTPS endpoint
Invoke-RestMethod -Uri https://your-domain.com:8443/api/v1/health

# Skip certificate verification (development)
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
Invoke-RestMethod -Uri https://localhost:8443/api/v1/health
```

### Using Web Browser

Navigate to `https://your-domain.com:8443/api/v1/health` in your browser.

For self-signed certificates, you'll see a security warning. Click "Advanced" → "Proceed to localhost (unsafe)" to continue.

## Troubleshooting

### Certificate Loading Errors

**Error**: `Failed to load SSL certificate`

**Solutions**:
1. Verify certificate files exist in `./ssl/` directory
2. Check certificate format is PEM
3. Verify certificate and key match
4. Check file permissions (read access required)

### Connection Errors

**Error**: `SSL certificate problem: unable to get local issuer certificate`

**Solutions**:
1. Use `-k` flag with curl for self-signed certificates
2. Add CA certificate to system trust store
3. Use `--cacert` to specify CA certificate

### Port Binding Errors

**Error**: `Address already in use`

**Solutions**:
1. Check if another service is using the port
2. Change `PORT` in `.env` file
3. Use `netstat` to identify port usage: `netstat -tulpn | grep 8443`

## Certificate Renewal

### Let's Encrypt Auto-Renewal

Let's Encrypt certificates are valid for 90 days. Set up auto-renewal:

```bash
# Test renewal
sudo certbot renew --dry-run

# Add to crontab for auto-renewal
sudo crontab -e

# Add this line (renew twice daily)
0 0,12 * * * python3 -c 'import random; import time; time.sleep(random.random() * 3600)' && certbot renew -q --post-hook "systemctl restart agentskills-runtime"
```

### Manual Renewal

```bash
# Renew certificate
sudo certbot renew

# Copy new certificates
cat /etc/letsencrypt/live/your-domain.com/fullchain.pem > ./ssl/server.crt
cat /etc/letsencrypt/live/your-domain.com/privkey.pem > ./ssl/server.key

# Restart service
systemctl restart agentskills-runtime
```

## Security Best Practices

### Production Deployment

1. **Use Valid Certificates**: Always use certificates from a trusted CA
2. **Enable HSTS**: Configure HTTP Strict Transport Security
3. **Use Strong Cipher Suites**: Prefer TLS 1.3 with modern cipher suites
4. **Regular Renewal**: Set up automatic certificate renewal
5. **Monitor Expiry**: Set up alerts for certificate expiration
6. **Secure Private Key**: Restrict access to private key file

### Development Environment

1. **Self-Signed Certificates**: Acceptable for local development
2. **Test Mode**: Use `-k` flag with curl to skip verification
3. **Browser Warnings**: Expected and acceptable for development
4. **Never Commit**: Don't commit private keys to version control

## Performance Considerations

### TLS Handshake Overhead
- Initial connection has TLS handshake overhead (~50-100ms)
- Subsequent requests use session resumption (minimal overhead)
- Keep-alive connections reduce handshake frequency

### Certificate Size
- Larger certificate chains increase handshake time
- Use minimal necessary certificate chain
- ECDSA certificates are smaller than RSA

### Connection Pooling
- Enable HTTP keep-alive for better performance
- Reuse connections when possible
- Consider connection pooling in clients

## Migration from HTTP to HTTPS

### Step 1: Obtain Certificate
Follow the instructions above to obtain an SSL certificate.

### Step 2: Update Configuration
Change `BACKEND_URL` from `http://` to `https://`:

```env
# Before
BACKEND_URL=http://your-domain.com

# After
BACKEND_URL=https://your-domain.com
```

### Step 3: Update Clients
Update all client applications to use `https://` URLs.

### Step 4: Test
Thoroughly test all API endpoints with HTTPS.

### Step 5: Redirect HTTP to HTTPS (Optional)
Configure your reverse proxy or load balancer to redirect HTTP traffic to HTTPS.

## FAQ

**Q: Can I use HTTP and HTTPS simultaneously?**
A: No, the runtime runs in either HTTP or HTTPS mode, not both. Use a reverse proxy for dual-mode support.

**Q: How do I use a custom certificate path?**
A: Currently, certificates must be in `./ssl/server.crt` and `./ssl/server.key`. Custom paths are not supported.

**Q: Does HTTPS support WebSocket?**
A: Yes, WebSocket connections are supported over HTTPS (WSS protocol).

**Q: Can I use a PFX/PKCS12 certificate?**
A: No, only PEM format is supported. Convert PFX to PEM using OpenSSL.

**Q: How do I check certificate expiration?**
A: Use `openssl x509 -in ./ssl/server.crt -noout -dates`

## Related Documentation

- [Quickstart Guide](quickstart.md) - Basic setup and usage
- [Architecture Overview](architecture.md) - System architecture
- [API Reference](agentskills-api-reference.md) - API documentation
