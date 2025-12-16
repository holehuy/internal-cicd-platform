# Platform Architecture

## Tổng quan Kiến trúc

Internal CI/CD Platform được thiết kế theo mô hình microservices với Docker containers, đảm bảo tính khả dụng cao và dễ bảo trì.

## 🏗️ Kiến trúc Tổng quan

```
┌─────────────────────────────────────────────────────────────┐
│                         Developers                          │
│                    (Push code to Git)                       │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                      Nginx (Optional)                       │
│                   Reverse Proxy + SSL                       │
└───────────────┬─────────────────────┬───────────────────────┘
                │                     │
        ┌───────▼────────┐    ┌──────▼────────┐
        │    Jenkins     │    │   SonarQube   │
        │    :8080       │    │    :9000      │
        └───────┬────────┘    └──────┬────────┘
                │                    │
                │              ┌─────▼─────────┐
                │              │  PostgreSQL   │
                │              │    :5432      │
                │              └───────────────┘
                │
        ┌───────▼────────┐
        │  Docker Engine │
        │  (Build agents)│
        └────────────────┘
```

## 🐳 Components

### 1. Jenkins (jenkins/jenkins:lts-jdk17)

**Vai trò**: CI/CD Automation Server

**Tính năng**:
- Configuration as Code (JCasC)
- Pipeline orchestration
- Plugin ecosystem
- Docker-based agents
- Multi-branch pipeline support

**Ports**:
- `8080`: Web UI
- `50000`: Agent communication

**Volumes**:
- `jenkins_home`: Persistent storage
- `/var/run/docker.sock`: Docker socket (Docker-in-Docker)
- Configuration files (read-only)

**Resources**:
```yaml
CPU: 2 cores (minimum)
Memory: 2GB (minimum), 4GB (recommended)
```

### 2. SonarQube (sonarqube:lts-community)

**Vai trò**: Code Quality & Security Analysis

**Tính năng**:
- Static code analysis
- Security vulnerability detection
- Code coverage tracking
- Quality gates
- Technical debt management

**Port**: `9000`

**Volumes**:
- `sonarqube_data`: Analysis data
- `sonarqube_extensions`: Plugins
- `sonarqube_logs`: Log files

**Resources**:
```yaml
CPU: 2 cores (minimum)
Memory: 3GB (minimum), 4GB (recommended)
Elasticsearch: 1GB heap
```

### 3. PostgreSQL (postgres:15-alpine)

**Vai trò**: Database cho SonarQube

**Port**: `5432` (internal only)

**Volume**: `sonarqube_db`

**Resources**:
```yaml
CPU: 1 core
Memory: 512MB (minimum), 1GB (recommended)
```

### 4. Nginx (nginx:alpine) - Optional

**Vai trò**: Reverse Proxy, SSL Termination

**Ports**:
- `80`: HTTP
- `443`: HTTPS

**Tính năng**:
- SSL/TLS termination
- Load balancing
- Request routing
- Security headers

## 🔄 Data Flow

### CI/CD Pipeline Flow

```
1. Developer Push Code
   ↓
2. Git Webhook → Jenkins
   ↓
3. Jenkins pulls code
   ↓
4. Build & Test (in Docker container)
   ↓
5. Run SonarQube Scanner
   ↓
6. SonarQube Analysis
   ├→ Store results in PostgreSQL
   └→ Return Quality Gate status
   ↓
7. Jenkins receives Quality Gate result
   ↓
8. Continue or Fail based on Quality Gate
   ↓
9. Deploy (if successful)
```

### SonarQube Analysis Flow

```
Jenkins Pipeline
   │
   ├─→ sonar-scanner CLI
   │      │
   │      ├─→ Analyze source code
   │      ├─→ Send to SonarQube Server
   │      └─→ Receive task ID
   │
   └─→ Wait for Quality Gate
          │
          └─→ Poll SonarQube API
                 │
                 ├─→ Quality Gate: PASSED → Continue
                 └─→ Quality Gate: FAILED → Mark unstable
```

## 🗄️ Data Persistence

### Volume Structure

```
Docker Volumes:
├── jenkins_home/
│   ├── config.xml              # Jenkins configuration
│   ├── jobs/                   # Job definitions
│   ├── workspace/              # Build workspaces
│   ├── credentials.xml         # Encrypted credentials
│   └── plugins/                # Installed plugins
│
├── sonarqube_data/
│   ├── es7/                    # Elasticsearch indices
│   └── ce/                     # Compute Engine data
│
├── sonarqube_extensions/
│   ├── plugins/                # SonarQube plugins
│   └── jdbc-driver/            # JDBC drivers
│
└── sonarqube_db/
    └── postgresql/             # PostgreSQL data
        ├── base/               # Database files
        └── pg_wal/             # Write-Ahead Logs
```

### Backup Strategy

**Backup includes**:
1. Jenkins home directory (excluding workspaces, caches)
2. SonarQube data & extensions
3. PostgreSQL database dump
4. Configuration files

**Backup frequency**: Daily (automated via cron)

**Retention**: 30 days (configurable)

## 🔐 Security Architecture

### Network Security

```
External Network (Internet)
   │
   ├─→ Nginx (Port 80/443)
   │      │
   │      └─→ Internal Network (cicd-network)
   │             │
   │             ├─→ Jenkins (Port 8080)
   │             ├─→ SonarQube (Port 9000)
   │             └─→ PostgreSQL (Port 5432)
   │
   └─→ Direct access (if Nginx not used)
          │
          ├─→ Jenkins (Port 8080)
          └─→ SonarQube (Port 9000)
```

### Authentication & Authorization

**Jenkins**:
- Local user database
- Matrix-based security
- Folder-level permissions
- API token authentication

**SonarQube**:
- Built-in authentication
- Project-level permissions
- Token-based API access
- LDAP integration (optional)

### Secrets Management

```
Secrets stored in:
├── Jenkins Credentials Store (encrypted)
│   ├── Git credentials
│   ├── SonarQube tokens
│   ├── Docker registry credentials
│   └── SSH keys
│
├── Environment Variables (platform.env)
│   ├── Admin passwords (encrypted at rest)
│   └── Database passwords
│
└── Docker Secrets (optional, for Swarm)
```

## 📊 Monitoring & Logging

### Health Checks

```yaml
Jenkins:
  endpoint: http://localhost:8080/login
  interval: 30s
  timeout: 10s
  retries: 5

SonarQube:
  endpoint: http://localhost:9000/api/system/status
  interval: 30s
  timeout: 10s
  retries: 5

PostgreSQL:
  command: pg_isready
  interval: 10s
  timeout: 5s
  retries: 5
```

### Log Aggregation

```
Application Logs:
├── Jenkins
│   └── /var/jenkins_home/logs/
│
├── SonarQube
│   ├── /opt/sonarqube/logs/web.log
│   ├── /opt/sonarqube/logs/ce.log
│   └── /opt/sonarqube/logs/es.log
│
└── PostgreSQL
    └── Docker stdout/stderr
```

**Access logs**:
```bash
docker logs -f internal-jenkins
docker logs -f internal-sonarqube
docker logs -f sonarqube-postgres
```

## 🚀 Scalability

### Horizontal Scaling

**Jenkins Agents**:
- Dynamic Docker agents
- Kubernetes agents (future)
- SSH agents

**SonarQube**:
- Multiple Compute Engine workers
- Elasticsearch clustering (Enterprise)

### Vertical Scaling

```bash
# Increase resources in docker-compose.yml
services:
  jenkins:
    deploy:
      resources:
        limits:
          cpus: '4'
          memory: 8G
        reservations:
          cpus: '2'
          memory: 4G
```

## 🔄 High Availability

### Backup & Disaster Recovery

1. **Automated Backups**: Daily via cron
2. **Off-site Storage**: Copy to S3/NFS
3. **Recovery Time**: < 30 minutes
4. **Data Loss**: < 24 hours

### Monitoring & Alerting

```
Prometheus (optional) → Grafana
   ↓
Jenkins Metrics Plugin
SonarQube API
Docker Stats
   ↓
Alert to: Slack, Email, PagerDuty
```

## 📈 Performance Optimization

### Jenkins

```groovy
// jenkins.yaml
systemProperties:
  - hudson.model.LoadStatistics.clock: 60000
  - jenkins.model.Jenkins.slaveAgentPort: 50000
  - jenkins.model.Jenkins.slaveAgentPortEnforce: true

executors: 4  # Based on CPU cores
```

### SonarQube

```properties
# sonar.properties
sonar.web.javaOpts=-Xmx2048m -Xms512m
sonar.ce.javaOpts=-Xmx2048m -Xms512m
sonar.search.javaOpts=-Xmx1024m -Xms512m

# Database connection pool
sonar.jdbc.maxActive=60
sonar.jdbc.maxIdle=5
```

## 🛠️ Technology Stack

| Component | Technology | Version |
|-----------|-----------|---------|
| Container Runtime | Docker | 20.10+ |
| Orchestration | Docker Compose | 2.0+ |
| CI/CD | Jenkins | LTS (JDK17) |
| Code Quality | SonarQube | LTS Community |
| Database | PostgreSQL | 15 |
| Reverse Proxy | Nginx | Alpine |
| Configuration | YAML | JCasC |

## 📚 References

- [Jenkins Documentation](https://www.jenkins.io/doc/)
- [SonarQube Documentation](https://docs.sonarqube.org/)
- [Docker Compose Specification](https://docs.docker.com/compose/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)