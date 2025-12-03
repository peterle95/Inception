# Testing WordPress

## 1. Verify Installation (Browser)

Navigate to `https://pmolzer.42.fr`.

**Expected Result:**
- You should see the WordPress homepage (not the installation wizard).
- The site title should match what you set in `.env` (e.g., "Inception").

## 2. Verify Admin Login (Browser)

Navigate to `https://pmolzer.42.fr/wp-admin`.

**Credentials:**
- Use the admin username and password from your `.env` file.

**Expected Result:**
- Successful login to the WordPress Dashboard.

## 3. Verify Users (Browser/Terminal)

**Browser:**
- Go to "Users" in the dashboard.
- You should see two users: the administrator and the second user (author/editor).

**Terminal:**
```bash
# List users via WP-CLI
docker exec -it wordpress wp user list --allow-root
```
**Expected Result:**
- A table listing the users, their roles, and emails.

## 4. Verify PHP-FPM (Terminal)

Ensure PHP-FPM is running and handling requests.

**Command:**
```bash
docker logs wordpress
```

**Expected Result:**
- You should see logs indicating PHP-FPM started (e.g., `ready to handle connections`).
- You might see access logs if you've visited the site.

## 5. Verify Database Connection (Terminal)

If the site loads, the database connection is working. If you see "Error establishing a database connection", check the logs.

**Command:**
```bash
docker exec -it wordpress wp db check --allow-root
```

**Expected Result:**
- `Success: The database is available.`
