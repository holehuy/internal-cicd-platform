# Quick Start Guide

## ⚡ Quick Start (5 minutes)

### 1. Check Docker is running

```bash
docker --version
docker compose version
```

### 2. Build Jenkins image (required)

```bash
docker compose build jenkins
```

### 3. Start all services

```bash
docker compose up -d
```

### 4. Wait for services to start (2-3 minutes)

```bash
watch docker compose ps
```

Wait until you see:
```
NAME                 STATUS
internal-jenkins     Up (healthy)
internal-sonarqube   Up (healthy)
sonarqube-postgres   Up (healthy)
```

### 5. Access services

**Jenkins:** http://localhost:8080
- Username: `admin`
- Password: `changeme123!`

**SonarQube:** http://localhost:9000
- Username: `admin`
- Password: `admin` (default - MUST change after first login)

**⚠️ Important Notes:**
- SonarQube always has default password `admin/admin`
- The `SONAR_ADMIN_PASSWORD` variable in env file is for documentation only, not used by SonarQube
- SonarQube LTS Community - Latest Long-Term Support, no warnings

---

## ✅ Verify Successful Deployment

### Jenkins MUST REQUIRE LOGIN

❌ **INCORRECT:** Access Jenkins dashboard directly without login
✅ **CORRECT:** Redirects to `/login` page and requires username/password

If Jenkins does not require login:
```bash
# Rebuild Jenkins
docker compose stop jenkins
docker compose rm -f jenkins
docker volume rm internal-cicd-platform_jenkins_home
docker compose build jenkins --no-cache
docker compose up -d jenkins
```

### SonarQube must run without restarts

```bash
docker compose logs sonarqube --tail 20
```

Last line should be:
```
SonarQube is operational
```

If container keeps restarting, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

---

## 📝 Issues Fixed

### 1. ✅ SonarQube Elasticsearch heap size
- **Fixed:** Initial heap = Maximum heap = 1024MB
- **Files:** `docker-compose.yml`, `env/platform.env`, `sonarqube/sonar.properties`

### 2. ✅ PostgreSQL database mismatch
- **Fixed:** Database name from `sonarqube` → `sonar`
- **Files:** `env/platform.env`, `docker-compose.yml`

### 3. ✅ POSTGRES_PASSWORD warning
- **Fixed:** Added explicit environment variables
- **File:** `docker-compose.yml`

### 4. ✅ Jenkins security not working
- **Fixed:**
  - Created custom Dockerfile to install plugins
  - Simplified CasC config
  - Removed deprecated `volumes` config
- **Files:** `jenkins/Dockerfile`, `jenkins/casc/jenkins.yaml`, `docker-compose.yml`

---

## 🔧 Useful Commands

```bash
# Check status
docker compose ps

# View logs
docker compose logs -f jenkins
docker compose logs -f sonarqube

# Restart a service
docker compose restart jenkins

# Stop all services
docker compose down

# Complete reset (delete all data)
docker compose down -v
```

---

## 📚 Further Reading

- **[DEPLOYMENT.md](DEPLOYMENT.md)** - Detailed guide on deployment process and all changes made
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Solutions for common issues

---

## 🆘 When You Encounter Issues

1. **Jenkins does not require login**
   ```bash
   docker compose logs jenkins | grep -i "casc\|error"
   ```
   → See "Verify deployment" section above

2. **SonarQube keeps restarting**
   ```bash
   docker compose logs sonarqube --tail 100
   ```
   → Find error message in [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

3. **Port already in use**
   - Change port in `env/platform.env`:
     ```bash
     JENKINS_PORT=8081
     SONARQUBE_PORT=9001
     ```

4. **Need complete reset**
   ```bash
   docker compose down -v
   docker compose build jenkins
   docker compose up -d
   ```

---

## ⏭️ Next Steps

After successful deployment:

1. **Change default passwords** (important!)
   - Jenkins admin
   - SonarQube admin

2. **Create SonarQube token**
   - SonarQube > My Account > Security > Generate Token
   - Update in `env/platform.env`: `SONAR_TOKEN=<token>`
   - Restart Jenkins: `docker compose restart jenkins`

3. **Test Jenkins + SonarQube integration**
   - Manage Jenkins > Configure System
   - SonarQube servers > Check connection

4. **Create first pipeline**
   - New Item > Pipeline
   - Configure and test

5. **Setup backup automation**
   ```bash
   ./scripts/backup.sh
   ```

---

**Status:** ✅ All issues fixed and documented

**Ready to deploy!** 🚀
