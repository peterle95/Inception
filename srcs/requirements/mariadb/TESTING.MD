# Testing MariaDB

## 1. Verify Database Connection (Terminal)

The database should be accessible from the WordPress container, but not from the host.

**Command:**
```bash
# Check if mariadb is running
docker ps | grep mariadb

# Try to connect from the host (Should FAIL)
mysql -h 127.0.0.1 -P 3306 -u pmolzer -p
# Expected: Connection refused or timeout (since port 3306 is not mapped to host)
```

## 2. Verify Data Persistence (Terminal)

Data should persist even if the container is removed.

**Command:**
```bash
# 1. Create a test table
docker exec -it mariadb mariadb -u root -p$MYSQL_ROOT_PASSWORD -e "USE $MYSQL_DATABASE; CREATE TABLE test_table (id INT); INSERT INTO test_table VALUES (1);"

# 2. Verify data exists
docker exec -it mariadb mariadb -u root -p$MYSQL_ROOT_PASSWORD -e "USE $MYSQL_DATABASE; SELECT * FROM test_table;"
# Expected Output:
# +------+
# | id   |
# +------+
# |    1 |
# +------+

# 3. Remove containers
make down

# 4. Restart containers
make up

# 5. Verify data still exists
docker exec -it mariadb mariadb -u root -p$MYSQL_ROOT_PASSWORD -e "USE $MYSQL_DATABASE; SELECT * FROM test_table;"
# Expected Output: Same as above (id: 1)
```

## 3. Verify User Creation (Terminal)

The initialization script should have created the specific user and database.

**Command:**
```bash
docker exec -it mariadb mariadb -u root -p$MYSQL_ROOT_PASSWORD -e "SELECT User, Host FROM mysql.user;"
```

**Expected Result:**
You should see your custom user (e.g., `pmolzer`) and `root` in the list.
