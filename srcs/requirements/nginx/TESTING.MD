# Testing NGINX

## 1. Verify TLS Version (Terminal)

The subject requires TLSv1.2 or TLSv1.3 only.

**Command:**
```bash
# Test TLS 1.2 (Should succeed)
openssl s_client -connect pmolzer.42.fr:443 -tls1_2

# Test TLS 1.3 (Should succeed)
openssl s_client -connect pmolzer.42.fr:443 -tls1_3

# Test TLS 1.0 (Should fail)
openssl s_client -connect pmolzer.42.fr:443 -tls1

# Test TLS 1.1 (Should fail)
openssl s_client -connect pmolzer.42.fr:443 -tls1_1
```

**Expected Result:**
- TLS 1.2/1.3 commands should show the certificate chain and handshake details.
- TLS 1.0/1.1 commands should fail with a handshake error or "no protocols available".

## 2. Verify Port 443 Only (Terminal)

Only port 443 should be exposed to the host.

**Command:**
```bash
docker ps
```

**Expected Result:**
Check the `PORTS` column for the `nginx` container. It should only show `0.0.0.0:443->443/tcp`. It should **not** show port 80.

## 3. Verify Certificate (Browser)

1.  Open `https://pmolzer.42.fr` in your browser.
2.  Click the "Not Secure" or lock icon in the address bar.
3.  View the certificate details.
4.  **Expected Result**:
    - Issued to: `pmolzer.42.fr` (or similar).
    - Issued by: `pmolzer.42.fr` (Self-signed).
    - Protocol: TLS 1.2 or 1.3.

## 4. Verify HTTP Redirect (Optional but good practice)

If you try to access `http://pmolzer.42.fr` (port 80), it should either fail (connection refused) or redirect to HTTPS, depending on your implementation. The subject strictly says "accessible only via port 443", so connection refused on port 80 is the most compliant behavior.
