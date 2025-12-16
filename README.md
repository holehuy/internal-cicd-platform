# Internal CI/CD Platform

> Internal CI/CD platform integrating Jenkins and SonarQube for development teams

## 🎯 Overview

This platform provides a complete and easy-to-deploy CI/CD solution for internal environments, including:

- **Jenkins**: Automation server for CI/CD pipelines
- **SonarQube**: Code quality and security analysis
- **PostgreSQL**: Database backend for SonarQube
- **Nginx** (optional): Reverse proxy for SSL/TLS

## ✨ Features

- ✅ **Configuration as Code**: Jenkins is fully configured using YAML
- ✅ **Pre-configured Pipelines**: Ready-to-use templates for Node.js, Python, .NET
- ✅ **Integrated Code Quality**: Built-in SonarQube itegration
- ✅ **Docker Support**: Build and deploy containers
- ✅ **Easy Backup/Restore**: Automated backup & restore scripts
- ✅ **Multi-team Support**: Folder-based structure for multiple teams
- ✅ **Secure by Default**: Authentication and authorization preconfigured

## 📋 System Requirements

### Minimum Requirements
- CPU: 4 cores
- RAM: 8GB
- Disk: 50GB SSD
- OS: Ubuntu 20.04+, CentOS 8+, or equivalent

### Software Requirements
- Docker 20.10+
- Docker Compose 2.0+
- Git 2.0+

## 🚀 Quick Installation

### 1. Clone repository

```bash
git clone <repository-url> internal-cicd-platform
cd internal-cicd-platform
```

### 2. Configure environment variables

```bash
cp env/platform.env.example env/platform.env
nano env/platform.env
```

**Important**: Udate the following values:
- `JENKINS_ADMIN_PASSWORD`
- `SONAR_ADMIN_PASSWORD`
- `SONAR_DB_PASSWORD`

### 3. Deploy platform

```bash
chmod +x scripts/*.sh
./scripts/deploy.sh
```

### 4. Access services

- **Jenkins**: http://localhost:8080
- **SonarQube**: http://localhost:9000

## 📚 Documentation

- [Architecture Overview](docs/architecture.md)
- [Team Onboarding Guide](docs/onboarding-team.md)
- [Adding New Projects](docs/add-new-project.md)
- [Security Model](docs/security-model.md)

## 🛠️ Platform Management

### Check Status

```bash
docker-compose ps
```

### View Logs

```bash
# all services
docker-compose logs -f

# specific service
docker-compose logs -f jenkins
docker-compose logs -f sonarqube
```

### Stop the platform

```bash
./scripts/stop.sh
```

### Restart services

```bash
docker-compose restart
```

### Backup data

```bash
./scripts/backup.sh
```

### Restore data

```bash
./scripts/restore.sh <backup-file>
```

## 🏗️ Project Structure

```
internal-cicd-platform/
├── env/                      # Environment configuration
├── jenkins/                  # Jenkins configuration
│   ├── casc/                # Configuration as Code
│   ├── Jenkinsfile-templates/  # Pipeline templates
│   └── plugins.txt          # Jenkins plugins
├── sonarqube/               # SonarQube configuration
├── scripts/                 # Management scripts
├── docs/                    # Documentation
└── docker-compose.yml       # Main compose file
```

## 🔐 Security

### Changes default password

1. **Jenkins**: Login và navigate to Manage Jenkins > Configure Global Security
2. **SonarQube**: Login và navigate to Administration > Security > Users

### SSL/TLS Configuration

To enable HTTPS, configure Nginx reverse proxy:

```bash
# Generate self-signed certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout nginx/ssl/key.pem \
  -out nginx/ssl/cert.pem
```

### Firewall Rules

```bash
# Allow only necessary ports
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 8080/tcp  # Jenkins (if not using Nginx)
ufw allow 9000/tcp  # SonarQube (if not using Nginx)
```

## 📦 Pipeline Templates

### Node.js Pipeline

```groovy
@Library('pipeline-templates') _

pipeline {
    agent any
    parameters {
        string(name: 'NODE_VERSION', defaultValue: 'NodeJS 18')
        string(name: 'PROJECT_KEY', defaultValue: 'my-nodejs-app')
    }
    stages {
        // Pipeline stages...
    }
}
```

See more at: [Jenkinsfile-templates](jenkins/Jenkinsfile-templates/)

## 🤝 Onboarding new Team

1. Create a folder for the team in Jenkins
2. Assign appropriate permission
3. Create a project in Sonarqube
4. Generate a SonarQube token
5. Create a pipeline using a template

Details: [Team Onboarding Guide](docs/onboarding-team.md)

## 🐛 Troubleshooting

### Jenkins does not start

```bash
# check logs
docker logs internal-jenkins

# check permissions
docker exec internal-jenkins ls -la /var/jenkins_home
```

### SonarQube out of memory

```bash
# increase memory in platform.env
SONAR_WEB_JAVAOPTS=-Xmx4096m -Xms1024m

# restart
docker-compose restart sonarqube
```

### Database connection errors

```bash
# check database health
docker exec sonarqube-postgres pg_isready

# restart database
docker-compose restart sonarqube-db
```

## 📊 Monitoring

### Health Checks

```bash
# jenkins
curl http://localhost:8080/login

# sonarqube
curl http://localhost:9000/api/system/status
```

### Resource Usage

```bash
docker stats
```

## 🔄 Updates

### Update Jenkins plugins

```bash
# add plugin to jenkins/plugins.txt
# restart jenkins
docker-compose restart jenkins
```

### Update Docker images

```bash
docker-compose pull
docker-compose up -d
```

## 💾 Backup Strategy

- **Automated daily backups**: Configure cron job
- **Retention**: 30 days (configurable)
- **Includes**:
  - Jenkins home directory
  - SonarQube data
  - PostgreSQL database
  - Configuration files

## 📞 Support

- Technical Issues: Create issue trong repository
- Documentation: Xem folder `docs/`
- Team Chat: [Link to internal chat]

## 📝 License

MIT License

## 🙏 Acknowledgments

- Jenkins Configuration as Code Plugin
- SonarQube Community
- Docker Community

---

**Version**: 1.0.0  
**Last Updated**: December 2025