# SonarQube Configuration

## Tổng quan

SonarQube là công cụ continuous inspection cho code quality và security analysis. Configuration này được tối ưu cho môi trường internal CI/CD.

## 📁 Cấu trúc

```
sonarqube/
├── sonar.properties    # SonarQube configuration
└── README.md          # File này
```

## ⚙️ Configuration

### sonar.properties

File cấu hình chính cho SonarQube server.

**Key Settings:**

```properties
# Web Server
sonar.web.host=0.0.0.0
sonar.web.port=9000

# Database (configured via environment variables)
# SONAR_JDBC_URL
# SONAR_JDBC_USERNAME
# SONAR_JDBC_PASSWORD

# Security
sonar.forceAuthentication=true

# Performance
sonar.web.javaOpts=-Xmx2048m
sonar.ce.javaOpts=-Xmx2048m
sonar.search.javaOpts=-Xmx1024m
```

## 🚀 First Time Setup

### 1. Access SonarQube

```bash
URL: http://localhost:9000
Default credentials:
  Username: admin
  Password: admin (hoặc từ platform.env)
```

### 2. Change Admin Password

**Bắt buộc ngay sau khi login lần đầu!**

```
Administration → Security → Users → Administrator → Change password
```

### 3. Setup Quality Gate

**Default Quality Gate:**
```
Conditions:
- Coverage < 80% → Failed
- Duplicated Lines > 3% → Failed
- Maintainability Rating worse than A → Failed
- Reliability Rating worse than A → Failed
- Security Rating worse than A → Failed
```

**Tạo Custom Quality Gate:**

1. Go to **Quality Gates**
2. Click **Create**
3. Name: `Strict Quality Gate`
4. Add conditions:
   - Coverage on New Code < 90%
   - New Bugs > 0
   - New Vulnerabilities > 0
   - New Security Hotspots > 0
   - New Code Smells > 5

### 4. Configure Quality Profiles

**Languages supported:**
- Java
- JavaScript/TypeScript
- Python
- C#
- PHP
- Go
- Ruby
- Kotlin
- Swift

**Tạo Custom Profile:**

1. **Quality Profiles** → Select language → **Create**
2. Name: `Company Standard - JavaScript`
3. Based on: `Sonar way`
4. Activate additional rules:
   - Security rules: All
   - Bug detection: All
   - Code smell: Selected

## 🔐 Security Configuration

### User Management

**Tạo User:**
```
Administration → Security → Users → Create User

Username: john.doe
Name: John Doe
Email: john.doe@company.com
Password: [generate strong password]
```

**Groups:**

```
developers
├── Permissions:
│   ├── Browse projects
│   ├── Execute Analysis
│   └── Create Projects

team-leads
├── Inherit from: developers
└── Additional:
    ├── Administer Quality Gates
    └── Administer Quality Profiles

admins
└── All permissions
```

### Token Management

**Generate Project Token:**

1. Go to project **Administration → Analysis Method**
2. Choose **With Jenkins**
3. Generate token
4. **Save token securely!**

**Token Types:**

```
User Token:
- Access: All projects user có quyền
- Use case: Personal analysis, scripts

Project Analysis Token:
- Access: Specific project only
- Use case: CI/CD pipelines (recommended)
```

### Permissions

**Project Level:**

```
Private Project:
├── Browse: Developers
├── Execute Analysis: Jenkins service account
├── Administer Issues: Team leads
└── Administer: Project admins

Public Project:
├── Browse: Anyone
└── Rest: Same as private
```

## 📊 Quality Gates

### Default Quality Gates

**Sonar way (Default):**
```yaml
Conditions on New Code:
  - Coverage: < 80%
  - Duplicated Lines: > 3%
  - Maintainability Rating: worse than A
  - Reliability Rating: worse than A
  - Security Rating: worse than A
  - Security Hotspots Reviewed: < 100%
```

### Custom Quality Gates

**Strict Gate:**
```yaml
Conditions on New Code:
  - Coverage: < 90%
  - New Bugs: > 0
  - New Vulnerabilities: > 0
  - New Security Hotspots: > 0
  - New Code Smells: > 5
  - Duplicated Lines: > 1%

Conditions on Overall Code:
  - Coverage: < 80%
  - Technical Debt Ratio: > 5%
```

**Lenient Gate (for legacy projects):**
```yaml
Conditions on New Code:
  - Coverage: < 70%
  - New Bugs: > 3
  - New Vulnerabilities: > 1
  - Security Rating: worse than B
```

### Associate Quality Gate

```bash
# Via UI
Project → Administration → Quality Gate → Select gate

# Via API
curl -u token: -X POST \
  "http://sonarqube:9000/api/qualitygates/select?projectKey=my-project&gateId=1"
```

## 🔍 Analysis Configuration

### JavaScript/TypeScript

**sonar-project.properties:**
```properties
sonar.projectKey=frontend-app
sonar.projectName=Frontend Application
sonar.sources=src
sonar.tests=tests
sonar.exclusions=**/node_modules/**,**/dist/**
sonar.javascript.lcov.reportPaths=coverage/lcov.info
sonar.testExecutionReportPaths=test-results/sonar-report.xml
```

### Python

**sonar-project.properties:**
```properties
sonar.projectKey=backend-api
sonar.projectName=Backend API
sonar.sources=.
sonar.tests=tests
sonar.exclusions=**/__pycache__/**,**/venv/**
sonar.python.coverage.reportPaths=coverage.xml
sonar.python.version=3.11
```

### .NET

**Via dotnet-sonarscanner:**
```bash
dotnet sonarscanner begin \
  /k:"my-dotnet-app" \
  /d:sonar.host.url="http://sonarqube:9000" \
  /d:sonar.login="token" \
  /d:sonar.cs.opencover.reportsPaths="**/coverage.opencover.xml"

dotnet build

dotnet sonarscanner end /d:sonar.login="token"
```

## 📈 Monitoring

### Health Check

```bash
# System status
curl http://sonarqube:9000/api/system/status

# Health
curl http://sonarqube:9000/api/system/health

# System info
curl -u admin:token http://sonarqube:9000/api/system/info
```

### Metrics

**Key Metrics to Monitor:**
```
- CPU usage
- Memory usage (especially Elasticsearch)
- Database connections
- Analysis queue length
- Compute Engine tasks
```

**Grafana Dashboard (optional):**
```
# Install SonarQube Prometheus Exporter plugin
# Configure Prometheus to scrape metrics
# Import SonarQube dashboard in Grafana
```

## 🔧 Performance Tuning

### Java Heap Size

**Trong platform.env:**
```bash
# Web Server
SONAR_WEB_JAVAOPTS=-Xmx2048m -Xms512m

# Compute Engine
SONAR_CE_JAVAOPTS=-Xmx2048m -Xms512m

# Elasticsearch
SONAR_SEARCH_JAVAOPTS=-Xmx1024m -Xms512m
```

### Database Connection Pool

**sonar.properties:**
```properties
sonar.jdbc.maxActive=60
sonar.jdbc.maxIdle=5
sonar.jdbc.minIdle=2
sonar.jdbc.maxWait=5000
```

### Compute Engine

```properties
# Number of workers
sonar.ce.workerCount=2

# Max heap per worker
sonar.ce.javaOpts=-Xmx1024m
```

## 🗑️ Maintenance

### Cleanup Old Analyses

**Manual Cleanup:**
```
Administration → Configuration → Housekeeping
  - Days before deleting inactive projects: 90
  - Days before deleting closed issues: 30
```

**API Cleanup:**
```bash
# Delete project
curl -u admin:token -X POST \
  "http://sonarqube:9000/api/projects/delete?project=old-project"

# Purge old analyses
curl -u admin:token -X POST \
  "http://sonarqube:9000/api/project_analyses/delete?project=my-project&from=2023-01-01"
```

### Database Maintenance

```bash
# Backup
docker exec sonarqube-postgres pg_dump -U sonar sonarqube > backup.sql

# Vacuum
docker exec sonarqube-postgres psql -U sonar -d sonarqube -c "VACUUM ANALYZE;"

# Reindex
docker exec sonarqube-postgres psql -U sonar -d sonarqube -c "REINDEX DATABASE sonarqube;"
```

### Log Rotation

```properties
# sonar.properties
sonar.log.rollingPolicy=time:yyyy-MM-dd
sonar.log.maxFiles=7
```

## 🚨 Troubleshooting

### SonarQube không start

**Problem:** Container keeps restarting

**Check logs:**
```bash
docker logs internal-sonarqube
```

**Common issues:**

1. **Insufficient memory:**
```bash
# Increase in docker-compose.yml
deploy:
  resources:
    limits:
      memory: 4G
```

2. **Database connection failed:**
```bash
# Check database is running
docker exec sonarqube-postgres pg_isready

# Verify credentials
docker exec sonarqube-postgres psql -U sonar -d sonarqube -c "\dt"
```

3. **Elasticsearch errors:**
```properties
# Increase Elasticsearch heap
SONAR_SEARCH_JAVAOPTS=-Xmx2048m -Xms1024m
```

### Analysis Failed

**Problem:** Scanner fails during analysis

**Solutions:**

1. **Check scanner logs:**
```bash
# In build logs
cat .scannerwork/report-task.txt
```

2. **Verify token:**
```bash
curl -u token: http://sonarqube:9000/api/authentication/validate
```

3. **Check project exists:**
```bash
curl -u token: http://sonarqube:9000/api/projects/search?projects=my-project
```

### Quality Gate timeout

**Problem:** Jenkins waiting for Quality Gate times out

**Solutions:**

1. **Check Compute Engine:**
```
Administration → System → Compute Engine
# Check if tasks are stuck
```

2. **Increase timeout:**
```groovy
// In Jenkinsfile
timeout(time: 10, unit: 'MINUTES') {
    waitForQualityGate abortPipeline: false
}
```

3. **Restart Compute Engine:**
```bash
docker-compose restart sonarqube
```

## 📊 Reports & Dashboards

### Custom Measures

**Create custom metric:**
```
Administration → Custom Measures
Name: Technical Debt Days
Formula: technical_debt / 480  # 480 = 8 hours/day * 60 min
```

### Portfolio Management (Enterprise)

```
- Create Portfolio
- Add projects
- View aggregated metrics
- Compare project quality
```

### Export Reports

```bash
# PDF Report (via plugin)
curl -u token: -o report.pdf \
  "http://sonarqube:9000/api/project_reports/export?projectKey=my-project"

# Metrics as JSON
curl -u token: \
  "http://sonarqube:9000/api/measures/component?component=my-project&metricKeys=coverage,bugs,vulnerabilities"
```

## 🔗 Integration

### IDE Integration

**IntelliJ IDEA:**
```
Settings → Plugins → Install "SonarLint"
Settings → Tools → SonarLint → Configure:
  - Connection: http://sonarqube:9000
  - Token: [your-token]
  - Project binding: Select project
```

**VS Code:**
```json
// settings.json
{
  "sonarlint.connectedMode.connections.sonarqube": [
    {
      "serverUrl": "http://sonarqube:9000",
      "token": "your-token"
    }
  ]
}
```

### Webhook Configuration

**For external notifications:**
```
Administration → Configuration → Webhooks → Create
Name: Slack Notification
URL: https://hooks.slack.com/services/YOUR/WEBHOOK/URL
Secret: [optional]
```

## 📚 Best Practices

### 1. Quality First Culture

```markdown
✅ DO:
- Run analysis on every commit
- Fix new issues immediately
- Review Security Hotspots regularly
- Maintain >80% coverage

❌ DON'T:
- Ignore Quality Gate failures
- Disable rules without good reason
- Skip analysis on branches
- Commit code with critical bugs
```

### 2. Rule Configuration

```markdown
- Start with "Sonar way" profile
- Customize gradually based on team feedback
- Document rule changes
- Sync profiles across projects
```

### 3. Project Organization

```markdown
- Use consistent naming: team-projectname
- Set proper permissions
- Configure appropriate Quality Gate
- Add project description and tags
```

## 📞 Support

Questions about SonarQube?
- DevOps Team: devops@company.com
- Slack: #sonarqube-support
- Documentation: http://docs.company.com/sonarqube

## 📖 Resources

- [SonarQube Documentation](https://docs.sonarqube.org/)
- [SonarQube REST API](https://next.sonarqube.com/sonarqube/web_api)
- [SonarLint](https://www.sonarlint.org/)
- [Clean Code](https://www.sonarsource.com/resources/white-papers/clean-code/)