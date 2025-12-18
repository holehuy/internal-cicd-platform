# Deployment Guide - Internal CI/CD Platform

## 🚀 Quick Deployment

### Step 1: Check requirements

```bash
# Docker & Docker Compose
docker --version  # Version 20.10+
docker compose version  # Version 2.0+

# Disk space
df -h  # Minimum 50GB required
```

### Step 2: Configure environment variables

File `env/platform.env` already has default values. **Change passwords for production:**

```bash
# Jenkins
JENKINS_ADMIN_PASSWORD=changeme123!  # ⚠️ CHANGE THIS PASSWORD

# PostgreSQL
POSTGRES_PASSWORD=StrongDBPassword123!  # ⚠️ CHANGE THIS PASSWORD
```

**Note about SonarQube:**
- SonarQube always starts with `admin/admin`
- The `SONAR_ADMIN_PASSWORD` variable is for documentation only
- MUST change password via UI after first login

### Step 3: Deploy

```bash
# Build Jenkins image with plugins
docker compose build jenkins

# Start all services
docker compose up -d

# Check status
docker compose ps
```

Wait 2-3 minutes for all services to be healthy.

### Step 4: Access services

**Jenkins:** http://localhost:8080
- Username: `admin`
- Password: Value in `JENKINS_ADMIN_PASSWORD` (default: `changeme123!`)
- ✅ Must require login

**SonarQube:** http://localhost:9000
- Username: `admin`
- Password: `admin` (change immediately after login)
- ℹ️ SonarQube LTS Community - Latest Long-Term Support

---

## ✅ Verification

### Jenkins
```bash
# Verify login required
curl http://localhost:8080
# Should redirect to /login

# Check folders created
docker exec internal-jenkins ls /var/jenkins_home/jobs/
# Should show: Shared-Pipelines, Team-Projects, Infrastructure
```

### SonarQube
```bash
# Check operational
docker compose logs sonarqube | grep "operational"
# Output: "SonarQube is operational"

# Check API
curl http://localhost:9000/api/system/status
# Output: {"status":"UP"}
```

---

## 🔧 Configuration

### Create SonarQube Token for Jenkins

1. Login SonarQube: http://localhost:9000
2. Change admin password
3. My Account > Security > Generate Token
4. Copy token
5. Edit `env/platform.env`:
   ```bash
   SONAR_TOKEN=<your-token-here>
   ```
6. Restart Jenkins:
   ```bash
   docker compose restart jenkins
   ```

### Verify Jenkins + SonarQube Integration

1. Jenkins > Manage Jenkins > Configure System
2. Scroll to "SonarQube servers"
3. Click "Check connection"
4. Should show "Success"

---

## 🛠️ Management Commands

```bash
# View logs
docker compose logs -f jenkins
docker compose logs -f sonarqube

# Restart a service
docker compose restart jenkins

# Stop all
docker compose down

# Start with fresh data (⚠️ Xóa tất cả data)
docker compose down -v
docker compose build jenkins
docker compose up -d
```

---

## 🆘 Troubleshooting

### Jenkins does not require login

**Fix:**
```bash
docker compose stop jenkins
docker compose rm -f jenkins
docker volume rm internal-cicd-platform_jenkins_home
docker compose build jenkins --no-cache
docker compose up -d jenkins
```

### SonarQube keeps restarting

**Check logs:**
```bash
docker compose logs sonarqube --tail 50
```

**Common issues:**
- Elasticsearch heap size error → Already fixed in config
- Database connection → Check PostgreSQL healthy
- Insufficient memory → Increase Docker memory limit

### Complete Reset

```bash
docker compose down -v
docker compose build jenkins
docker compose up -d
```

---

## 📋 Production Checklist

- [ ] Change all default passwords
- [ ] Setup SonarQube token for Jenkins
- [ ] Test Jenkins + SonarQube integration
- [ ] Configure backup automation (`./scripts/backup.sh`)
- [ ] Setup SSL/TLS via Nginx (optional)
- [ ] Configure firewall rules

---

## 📚 Additional Resources

- [QUICK-START.md](QUICK-START.md) - 5-minute startup guide
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Detailed troubleshooting
- SonarQube Docs: https://docs.sonarqube.org/
- Jenkins Docs: https://www.jenkins.io/doc/
