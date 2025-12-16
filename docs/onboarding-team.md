# Team Onboarding Guide

## Hướng dẫn Onboard Team mới vào CI/CD Platform

### 📋 Prerequisites

Trước khi bắt đầu, đảm bảo bạn có:
- [ ] Quyền admin trên Jenkins
- [ ] Quyền admin trên SonarQube
- [ ] Thông tin về team (tên team, members, repositories)

---

## Bước 1: Tạo Folder cho Team trong Jenkins

### 1.1. Tạo Folder

1. Đăng nhập Jenkins với quyền admin
2. Vào **Dashboard** → Click **New Item**
3. Nhập tên: `Team-[TenTeam]` (ví dụ: `Team-Frontend`)
4. Chọn **Folder** → Click **OK**

### 1.2. Cấu hình Folder

```groovy
// Trong folder configuration, thêm description
displayName: 'Frontend Team'
description: 'CI/CD pipelines cho Frontend Team'
```

### 1.3. Cấp quyền cho Team

1. Trong folder vừa tạo → **Configure**
2. Enable **Folder-level security**
3. Thêm team members:

```
Matrix-based security:
- [username]: Build, Read, Configure
- [team-lead]: All permissions
```

---

## Bước 2: Setup SonarQube Projects

### 2.1. Tạo Project trong SonarQube

1. Login SonarQube: `http://your-server:9000`
2. Click **Create Project**
3. Điền thông tin:
   - **Project key**: `team-frontend-webapp`
   - **Display name**: `Frontend Web Application`
   - **Main branch**: `main` hoặc `master`

### 2.2. Generate Token

1. Trong project → **Administration** → **Security**
2. Generate token cho Jenkins:
   - Name: `jenkins-integration`
   - Type: `Project Analysis Token`
   - Click **Generate**
3. **Lưu token này** - bạn sẽ cần nó cho bước tiếp theo!

### 2.3. Cấu hình Quality Gate (Optional)

1. **Administration** → **Quality Gates**
2. Tạo custom gate hoặc dùng default
3. Set conditions:
   ```
   Coverage < 80% → Failed
   Bugs > 0 → Failed
   Code Smells > 10 → Warning
   ```

---

## Bước 3: Integrate SonarQube với Jenkins

### 3.1. Thêm SonarQube Token vào Jenkins

1. Jenkins → **Manage Jenkins** → **Credentials**
2. Domain: **Global**
3. Click **Add Credentials**
4. Chọn **Secret text**
   - ID: `sonarqube-team-frontend`
   - Secret: [paste token từ bước 2.2]
   - Description: `SonarQube token for Frontend Team`

### 3.2. Cập nhật Jenkins Pipeline

Tạo file `Jenkinsfile` trong repository:

```groovy
@Library('pipeline-templates') _

pipeline {
    agent any
    
    parameters {
        string(name: 'PROJECT_KEY', defaultValue: 'team-frontend-webapp')
        string(name: 'NODE_VERSION', defaultValue: 'NodeJS 18')
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Build & Test') {
            steps {
                nodejs(nodeJSInstallationName: params.NODE_VERSION) {
                    sh 'npm ci'
                    sh 'npm run test:coverage'
                }
            }
        }
        
        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('Internal SonarQube') {
                    sh """
                        sonar-scanner \
                            -Dsonar.projectKey=${params.PROJECT_KEY} \
                            -Dsonar.sources=src \
                            -Dsonar.javascript.lcov.reportPaths=coverage/lcov.info
                    """
                }
            }
        }
        
        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: false
                }
            }
        }
    }
}
```

---

## Bước 4: Tạo Pipeline Job

### 4.1. Tạo Pipeline từ SCM

1. Vào folder team: **Team-Frontend**
2. Click **New Item**
3. Tên: `webapp-pipeline`
4. Chọn **Pipeline** → **OK**

### 4.2. Cấu hình Pipeline

**General:**
```
Description: CI/CD pipeline cho Frontend Web App
Discard old builds: Keep last 10 builds
```

**Build Triggers:**
```
☑ GitHub hook trigger for GITScm polling
☑ Poll SCM: H/5 * * * *  (mỗi 5 phút)
```

**Pipeline:**
```
Definition: Pipeline script from SCM
SCM: Git
Repository URL: https://github.com/your-org/frontend-webapp
Credentials: [select your git credentials]
Branch: */main
Script Path: Jenkinsfile
```

### 4.3. Test Pipeline

1. Click **Build Now**
2. Xem logs: **Console Output**
3. Verify kết quả trên SonarQube

---

## Bước 5: Thông báo cho Team

### 5.1. Tạo Documentation cho Team

Tạo file `CI-CD-GUIDE.md` trong repository:

```markdown
# CI/CD Setup Guide

## Truy cập
- Jenkins: http://jenkins.company.com/job/Team-Frontend/
- SonarQube: http://sonarqube.company.com/dashboard?id=team-frontend-webapp

## Credentials
- Jenkins username: [team-member-username]
- SonarQube: Sử dụng SSO

## Pipeline Flow
1. Push code → auto trigger build
2. Run tests
3. SonarQube analysis
4. Quality Gate check
5. Deploy (nếu pass)

## Useful Commands
```bash
# Local SonarQube scan
npm run sonar

# Manual Jenkins build
curl -X POST http://jenkins.company.com/job/Team-Frontend/job/webapp-pipeline/build \
     --user username:token
```
```

### 5.2. Send Onboarding Email

```
Subject: CI/CD Platform Access - Frontend Team

Hi team,

Your CI/CD environment is ready!

🔗 Access:
- Jenkins: http://jenkins.company.com/job/Team-Frontend/
- SonarQube: http://sonarqube.company.com

📚 Resources:
- Setup Guide: [link to CI-CD-GUIDE.md]
- Pipeline Template: [link to Jenkinsfile]
- Documentation: http://docs.company.com/cicd

👤 Your Credentials:
- Username: [username]
- Password: [send separately via secure channel]

⚡ Next Steps:
1. Login to both platforms
2. Change your password
3. Review the setup guide
4. Test the pipeline

Questions? Contact: devops@company.com
```

---

## Bước 6: Monitoring & Maintenance

### 6.1. Dashboard Setup

Tạo view trong Jenkins:

1. **Dashboard** → **New View**
2. Name: `Frontend Team Dashboard`
3. Type: **Build Pipeline View**
4. Thêm jobs của team

### 6.2. Notification Setup

Configure Slack/Email notifications:

```groovy
// Thêm vào Jenkinsfile
post {
    success {
        slackSend(
            channel: '#frontend-builds',
            color: 'good',
            message: "Build SUCCESS: ${env.JOB_NAME} #${env.BUILD_NUMBER}"
        )
    }
    failure {
        slackSend(
            channel: '#frontend-builds',
            color: 'danger',
            message: "Build FAILED: ${env.JOB_NAME} #${env.BUILD_NUMBER}"
        )
    }
}
```

---

## 📝 Checklist Hoàn thành Onboarding

- [ ] Jenkins folder đã tạo
- [ ] Team members có quyền truy cập
- [ ] SonarQube project đã setup
- [ ] Token đã generate và lưu trong Jenkins
- [ ] Pipeline job đã tạo và test thành công
- [ ] Documentation đã gửi cho team
- [ ] Team members đã login thành công
- [ ] Dashboard/View đã setup
- [ ] Notifications đã configure

---

## 🆘 Troubleshooting

### Pipeline không chạy tự động

**Giải pháp:**
1. Check webhook configuration trong GitHub/GitLab
2. Verify Jenkins có thể reach được repository
3. Check credentials

### SonarQube analysis failed

**Giải pháp:**
1. Verify token còn valid
2. Check project key trong Jenkinsfile
3. Review SonarQube logs: `docker logs internal-sonarqube`

### Permission denied

**Giải pháp:**
1. Check user permissions trong Jenkins matrix
2. Verify folder-level security settings
3. Re-login để refresh permissions

---

## 📞 Support

Gặp vấn đề? Liên hệ:
- DevOps Team: devops@company.com
- Slack: #cicd-support
- Documentation: http://docs.company.com/cicd