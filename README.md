# Internal CI/CD Platform

> Nền tảng CI/CD nội bộ tích hợp Jenkins và SonarQube cho các team phát triển

## 🎯 Tổng quan

Platform này cung cấp một giải pháp CI/CD hoàn chỉnh và dễ triển khai cho môi trường nội bộ, bao gồm:

- **Jenkins**: Automation server cho CI/CD pipelines
- **SonarQube**: Code quality và security analysis
- **PostgreSQL**: Database cho SonarQube
- **Nginx** (tùy chọn): Reverse proxy cho SSL/TLS

## ✨ Tính năng

- ✅ **Configuration as Code**: Jenkins được cấu hình hoàn toàn bằng YAML
- ✅ **Pre-configured Pipelines**: Templates có sẵn cho Node.js, Python, .NET
- ✅ **Integrated Code Quality**: Tích hợp sẵn SonarQube
- ✅ **Docker Support**: Build và deploy containers
- ✅ **Easy Backup/Restore**: Scripts tự động backup và restore
- ✅ **Multi-team Support**: Folder structure cho nhiều teams
- ✅ **Secure by Default**: Authentication và authorization được cấu hình sẵn

## 📋 Yêu cầu hệ thống

### Minimum Requirements
- CPU: 4 cores
- RAM: 8GB
- Disk: 50GB SSD
- OS: Ubuntu 20.04+, CentOS 8+, hoặc tương đương

### Software Requirements
- Docker 20.10+
- Docker Compose 2.0+
- Git 2.0+

## 🚀 Cài đặt nhanh

### 1. Clone repository

```bash
git clone <repository-url> internal-cicd-platform
cd internal-cicd-platform
```

### 2. Cấu hình environment

```bash
cp env/platform.env.example env/platform.env
nano env/platform.env
```

**Quan trọng**: Thay đổi các giá trị sau:
- `JENKINS_ADMIN_PASSWORD`
- `SONAR_ADMIN_PASSWORD`
- `SONAR_DB_PASSWORD`

### 3. Deploy platform

```bash
chmod +x scripts/*.sh
./scripts/deploy.sh
```

### 4. Truy cập services

- **Jenkins**: http://localhost:8080
- **SonarQube**: http://localhost:9000

## 📚 Tài liệu

- [Architecture Overview](docs/architecture.md)
- [Team Onboarding Guide](docs/onboarding-team.md)
- [Adding New Projects](docs/add-new-project.md)
- [Security Model](docs/security-model.md)

## 🛠️ Quản lý Platform

### Kiểm tra trạng thái

```bash
docker-compose ps
```

### Xem logs

```bash
# Tất cả services
docker-compose logs -f

# Một service cụ thể
docker-compose logs -f jenkins
docker-compose logs -f sonarqube
```

### Dừng platform

```bash
./scripts/stop.sh
```

### Khởi động lại

```bash
docker-compose restart
```

### Backup dữ liệu

```bash
./scripts/backup.sh
```

### Restore dữ liệu

```bash
./scripts/restore.sh <backup-file>
```

## 🏗️ Cấu trúc dự án

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

## 🔐 Bảo mật

### Thay đổi mật khẩu mặc định

1. **Jenkins**: Login và đi tới Manage Jenkins > Configure Global Security
2. **SonarQube**: Login và đi tới Administration > Security > Users

### SSL/TLS Configuration

Để enable HTTPS, cấu hình Nginx reverse proxy:

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
ufw allow 8080/tcp  # Jenkins (nếu không dùng Nginx)
ufw allow 9000/tcp  # SonarQube (nếu không dùng Nginx)
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

Xem thêm tại: [Jenkinsfile-templates](jenkins/Jenkinsfile-templates/)

## 🤝 Onboarding Team mới

1. Tạo folder cho team trong Jenkins
2. Cấp quyền truy cập phù hợp
3. Tạo project trong SonarQube
4. Generate SonarQube token
5. Tạo pipeline từ template

Chi tiết: [Team Onboarding Guide](docs/onboarding-team.md)

## 🐛 Troubleshooting

### Jenkins không start

```bash
# Check logs
docker logs internal-jenkins

# Check permissions
docker exec internal-jenkins ls -la /var/jenkins_home
```

### SonarQube out of memory

```bash
# Tăng memory trong platform.env
SONAR_WEB_JAVAOPTS=-Xmx4096m -Xms1024m

# Restart
docker-compose restart sonarqube
```

### Database connection errors

```bash
# Check database health
docker exec sonarqube-postgres pg_isready

# Restart database
docker-compose restart sonarqube-db
```

## 📊 Monitoring

### Health Checks

```bash
# Jenkins
curl http://localhost:8080/login

# SonarQube
curl http://localhost:9000/api/system/status
```

### Resource Usage

```bash
docker stats
```

## 🔄 Updates

### Cập nhật Jenkins plugins

```bash
# Thêm plugin vào jenkins/plugins.txt
# Restart Jenkins
docker-compose restart jenkins
```

### Cập nhật Docker images

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

Internal use only - [Your Company Name]

## 🙏 Acknowledgments

- Jenkins Configuration as Code Plugin
- SonarQube Community
- Docker Community

---

**Version**: 1.0.0  
**Last Updated**: December 2025