# Troubleshooting Guide

## Quick Diagnostic Commands

```bash
# Check all services status
docker compose ps

# View logs for all services
docker compose logs --tail=100

# View logs for specific service
docker compose logs -f jenkins
docker compose logs -f sonarqube
docker compose logs -f sonarqube-db

# Check resource usage
docker stats

# Inspect container details
docker inspect internal-jenkins
docker inspect internal-sonarqube
```

## Common Issues

### 1. Jenkins - Does not require login

**Symptoms:**
- Access http://localhost:8080 without username/password
- Direct access to Jenkins dashboard

**Root Causes:**
- CasC plugin not installed
- CasC config has syntax errors
- Environment variables not passed through

**Diagnosis:**

```bash
# 1. Check CasC config file
docker exec internal-jenkins cat /var/jenkins_home/casc_configs/jenkins.yaml

# 2. Check environment variables
docker exec internal-jenkins env | grep -E "JENKINS_ADMIN|CASC"

# 3. Check CasC plugin installed
docker exec internal-jenkins ls /var/jenkins_home/plugins/ | grep configuration-as-code

# 4. Check Jenkins logs for CasC errors
docker compose logs jenkins 2>&1 | grep -i "casc\|configuration"
```

**Solution:**

```bash
# Option 1: Rebuild Jenkins image with plugins
docker compose stop jenkins
docker compose rm -f jenkins
docker volume rm internal-cicd-platform_jenkins_home
docker compose build jenkins --no-cache
docker compose up -d jenkins

# Option 2: Check and fix CasC config
# Edit jenkins/casc/jenkins.yaml if there are errors
docker compose restart jenkins
```

---

### 2. SonarQube - Container keeps restarting

**Symptoms:**
- Container `internal-sonarqube` in "Restarting" state
- `docker compose ps` shows unhealthy status

**Common Root Causes:**

#### 2.1. Elasticsearch heap size mismatch

**Error in logs:**
```
bootstrap check failure: initial heap size [512m] not equal to maximum heap size [2048m]
```

**Diagnosis:**
```bash
docker compose logs sonarqube 2>&1 | grep "heap size"
```

**Solution:**
```bash
# Edit env/platform.env
# Ensure -Xms = -Xmx
SONAR_SEARCH_JAVAOPTS="-Xms1024m -Xmx1024m"

# Edit docker-compose.yml
SONAR_SEARCH_JAVAOPTS: "-Xms1024m -Xmx1024m"

# Restart
docker compose restart sonarqube
```

#### 2.2. Database connection failed

**Error in logs:**
```
Fail to connect to database
FATAL: database "sonar" does not exist
```

**Diagnosis:**
```bash
# Check database name mismatch
docker compose logs sonarqube-db | grep FATAL

# Check PostgreSQL is healthy
docker compose ps sonarqube-db

# Check database created
docker exec sonarqube-postgres psql -U sonar -l
```

**Solution:**
```bash
# Stop and remove volumes
docker compose down -v

# Check env/platform.env
# Ensure:
POSTGRES_DB=sonar
POSTGRES_USER=sonar
POSTGRES_PASSWORD=StrongDBPassword123!

# Check docker-compose.yml
# Service sonarqube environment:
SONAR_JDBC_URL: jdbc:postgresql://sonarqube-db:5432/${POSTGRES_DB:-sonar}

# Start again
docker compose up -d
```

#### 2.3. Insufficient resources

**Error in logs:**
```
OutOfMemoryError
ElasticSearch failed to start
```

**Diagnosis:**
```bash
# Check system resources
docker stats

# Check Docker allocated resources
docker info | grep -i memory
```

**Solution:**
```bash
# Increase Docker memory limit (Docker Desktop)
# Settings > Resources > Memory: Set to at least 6GB

# Or reduce heap size in env/platform.env
SONAR_WEB_JAVAOPTS="-Xmx1024m -Xms512m"
SONAR_CE_JAVAOPTS="-Xmx1024m -Xms512m"
SONAR_SEARCH_JAVAOPTS="-Xms512m -Xmx512m"
```

---

### 3. PostgreSQL - Database initialization failed

**Symptoms:**
- SonarQube cannot connect to database
- Warning about POSTGRES_PASSWORD

**Error in logs:**
```
The "POSTGRES_PASSWORD" variable is not set. Defaulting to a blank string.
```

**Diagnosis:**
```bash
# Check PostgreSQL logs
docker compose logs sonarqube-db

# Check environment in container
docker exec sonarqube-postgres env | grep POSTGRES
```

**Solution:**

Ensure `docker-compose.yml` has explicit environment variables:

```yaml
sonarqube-db:
  environment:
    POSTGRES_USER: ${POSTGRES_USER:-sonar}
    POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-changeme}
    POSTGRES_DB: ${POSTGRES_DB:-sonar}
  env_file:
    - ./env/platform.env
```

```bash
# Restart PostgreSQL
docker compose restart sonarqube-db
```

---

### 4. Port already in use

**Error:**
```
Error starting userland proxy: listen tcp4 0.0.0.0:8080: bind: address already in use
```

**Diagnosis:**
```bash
# Check what's using the port
lsof -i :8080
netstat -an | grep 8080

# On macOS
sudo lsof -i :8080
```

**Solution:**

Option 1: Kill process using the port
```bash
# Kill process
kill -9 <PID>
```

Option 2: Change port in `env/platform.env`
```bash
JENKINS_PORT=8081
SONARQUBE_PORT=9001
NGINX_HTTP_PORT=8082
```

```bash
docker compose down
docker compose up -d
```

---

### 5. Docker Compose command not found

**Error:**
```
docker-compose: command not found
```

**Root Cause:**
- Docker Compose V1 (docker-compose) vs V2 (docker compose)

**Solution:**

```bash
# Check Docker Compose version
docker compose version

# If using V1, change command:
docker-compose ps
docker-compose up -d
docker-compose logs -f

# If you want to upgrade to V2
# Follow: https://docs.docker.com/compose/install/
```

---

### 6. Permission denied errors

**Error:**
```
Permission denied: '/var/jenkins_home/...'
mkdir: cannot create directory: Permission denied
```

**Root Causes:**
- Volume permissions
- SELinux/AppArmor restrictions

**Solution:**

```bash
# For Linux with SELinux
# Add :z flag to volumes in docker-compose.yml
volumes:
  - jenkins_home:/var/jenkins_home:z

# Or disable SELinux temporarily
sudo setenforce 0

# Check folder permissions
ls -la /var/lib/docker/volumes/

# Reset permissions
docker compose down
sudo chown -R 1000:1000 /var/lib/docker/volumes/internal-cicd-platform_*
docker compose up -d
```

---

### 7. Jenkins plugins not installed

**Symptoms:**
- CasC config fails with "No configurator found"
- Some features not working

**Diagnosis:**
```bash
# List installed plugins
docker exec internal-jenkins ls /var/jenkins_home/plugins/

# Check specific plugin
docker exec internal-jenkins ls /var/jenkins_home/plugins/ | grep configuration-as-code
```

**Solution:**

```bash
# Rebuild Jenkins image
docker compose stop jenkins
docker compose build jenkins --no-cache
docker compose up -d jenkins

# Wait for Jenkins to start
docker compose logs -f jenkins
```

---

### 8. Network connectivity issues

**Symptoms:**
- Services cannot communicate with each other
- SonarQube cannot reach PostgreSQL

**Diagnosis:**
```bash
# Check networks
docker network ls
docker network inspect internal-cicd-network

# Test connectivity
docker exec internal-sonarqube ping sonarqube-db
docker exec internal-sonarqube curl http://sonarqube-db:5432
```

**Solution:**

```bash
# Recreate network
docker compose down
docker network rm internal-cicd-network
docker compose up -d
```

---

### 9. Disk space issues

**Error:**
```
no space left on device
Error response from daemon: write /var/lib/docker/...: no space left on device
```

**Diagnosis:**
```bash
# Check disk usage
df -h

# Check Docker disk usage
docker system df

# Check volume sizes
docker volume ls
du -sh /var/lib/docker/volumes/*
```

**Solution:**

```bash
# Clean up unused resources
docker system prune -a --volumes

# Remove specific volumes
docker volume rm <volume-name>

# Backup before cleaning
./scripts/backup.sh
```

---

### 10. Configuration changes not applied

**Symptoms:**
- Changed env variables but no effect
- Modified config files but not updated

**Solution:**

```bash
# For environment variable changes
docker compose down
docker compose up -d

# For mounted config files (automatically updated)
docker compose restart <service>

# For Dockerfile changes (need rebuild)
docker compose build <service> --no-cache
docker compose up -d <service>

# For Jenkins plugins.txt changes
docker compose build jenkins --no-cache
docker compose up -d jenkins
```

---

## Complete Reset (Nuclear Option)

⚠️ **Warning:** Delete all data and start from scratch

```bash
# Stop and remove everything
docker compose down -v

# Remove images
docker rmi internal-jenkins:latest

# Remove networks
docker network rm internal-cicd-network

# Clear build cache
docker builder prune -a

# Start fresh
docker compose build jenkins
docker compose up -d

# Monitor startup
docker compose logs -f
```

---

## Health Check Commands

```bash
# 1. Check all containers running
docker compose ps | grep "Up\|healthy"

# 2. Check Jenkins is accessible
curl -I http://localhost:8080/login

# 3. Check SonarQube is up
curl http://localhost:9000/api/system/status

# 4. Check PostgreSQL is accepting connections
docker exec sonarqube-postgres pg_isready -U sonar

# 5. Check disk space
df -h

# 6. Check memory usage
free -h
docker stats --no-stream
```

---

## Getting Help

If you still encounter issues after trying the solutions above:

1. **Gather diagnostic info:**
   ```bash
   docker compose ps > issue-report.txt
   docker compose logs >> issue-report.txt
   docker info >> issue-report.txt
   ```

2. **Check documentation:**
   - [DEPLOYMENT.md](DEPLOYMENT.md) - Details about deployment process
   - [docs/](docs/) - Other documentation

3. **Review configurations:**
   - `env/platform.env` - Environment variables
   - `docker-compose.yml` - Service definitions
   - `jenkins/casc/jenkins.yaml` - Jenkins configuration

4. **Search for similar issues:**
   - Jenkins: https://issues.jenkins.io/
   - SonarQube: https://community.sonarsource.com/
   - Docker: https://forums.docker.com/
