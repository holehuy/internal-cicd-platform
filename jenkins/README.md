# Jenkins Configuration

## Tổng quan

Thư mục này chứa toàn bộ configuration cho Jenkins server, bao gồm:
- Configuration as Code (JCasC)
- Plugin definitions
- Pipeline templates
- Shared libraries (optional)

## 📁 Cấu trúc Thư mục

```
jenkins/
├── casc/
│   └── jenkins.yaml          # Jenkins Configuration as Code
├── plugins.txt               # Danh sách plugins
├── Jenkinsfile-templates/    # Pipeline templates
│   ├── nodejs.Jenkinsfile
│   ├── python.Jenkinsfile
│   └── dotnet.Jenkinsfile
└── README.md                 # File này
```

## ⚙️ Configuration as Code (JCasC)

### jenkins.yaml

File này định nghĩa toàn bộ cấu hình Jenkins:

**Sections:**
1. **jenkins**: Core Jenkins settings
   - System message
   - Number of executors
   - Security realm
   - Authorization strategy

2. **credentials**: Credentials configuration
   - Git credentials
   - SonarQube tokens
   - Docker registry credentials

3. **tool**: Tool installations
   - Git
   - Node.js
   - Maven
   - Docker

4. **unclassified**: Plugin-specific configs
   - SonarQube integration
   - Global libraries
   - Email settings

5. **jobs**: Seed jobs (Job DSL)
   - Folder structure
   - Initial job creation

### Cập nhật Configuration

Khi thay đổi `jenkins.yaml`:

```bash
# 1. Edit file
nano jenkins/casc/jenkins.yaml

# 2. Validate syntax (optional)
# Install jenkins-cli tool first

# 3. Reload configuration
# Option A: Restart Jenkins
docker-compose restart jenkins

# Option B: Reload config via UI
# Manage Jenkins → Configuration as Code → Reload existing configuration
```

## 🔌 Plugins

### plugins.txt

Định nghĩa tất cả plugins cần cài đặt.

**Format:**
```
plugin-name:version
plugin-name:latest
```

### Categories:

**Core Plugins:**
- `configuration-as-code` - JCasC support
- `workflow-aggregator` - Pipeline support
- `git` - Git integration

**Build Tools:**
- `maven-plugin` - Maven builds
- `nodejs` - Node.js builds
- `docker-workflow` - Docker builds

**Code Quality:**
- `sonar` - SonarQube integration
- `warnings-ng` - Static analysis
- `jacoco` - Code coverage

**Notifications:**
- `slack` - Slack notifications
- `email-ext` - Email notifications

### Thêm Plugin Mới

```bash
# 1. Thêm vào plugins.txt
echo "new-plugin:latest" >> jenkins/plugins.txt

# 2. Restart Jenkins
docker-compose restart jenkins

# Or install via UI:
# Manage Jenkins → Manage Plugins → Available
```

## 📝 Pipeline Templates

### Node.js Template

**Sử dụng:**
```groovy
@Library('pipeline-templates') _

pipeline {
    agent any
    parameters {
        string(name: 'NODE_VERSION', defaultValue: 'NodeJS 18')
        string(name: 'PROJECT_KEY', defaultValue: 'my-project')
    }
    stages {
        // Your stages here
    }
}
```

**Features:**
- ✅ Dependency installation (npm ci)
- ✅ Linting
- ✅ Unit tests với coverage
- ✅ SonarQube analysis
- ✅ Docker build support

### Python Template

**Sử dụng:**
```groovy
pipeline {
    agent any
    parameters {
        string(name: 'PYTHON_VERSION', defaultValue: '3.11')
        string(name: 'PROJECT_KEY', defaultValue: 'my-project')
    }
    stages {
        // Your stages here
    }
}
```

**Features:**
- ✅ Virtual environment setup
- ✅ Dependency installation
- ✅ Linting (pylint, flake8, black)
- ✅ Unit tests với pytest
- ✅ Code coverage
- ✅ SonarQube analysis

### .NET Template

**Sử dụng:**
```groovy
pipeline {
    agent any
    parameters {
        string(name: 'DOTNET_VERSION', defaultValue: '8.0')
        string(name: 'PROJECT_KEY', defaultValue: 'my-project')
        choice(name: 'BUILD_CONFIGURATION', choices: ['Release', 'Debug'])
    }
    stages {
        // Your stages here
    }
}
```

**Features:**
- ✅ NuGet restore
- ✅ Build solution
- ✅ Unit tests
- ✅ SonarQube scanner integration
- ✅ Artifact publishing

## 🔧 Customization

### Tạo Custom Template

1. **Tạo file template mới:**
```bash
nano jenkins/Jenkinsfile-templates/custom.Jenkinsfile
```

2. **Template structure:**
```groovy
#!/usr/bin/env groovy

/**
 * Custom Pipeline Template
 * Description: Your description here
 */

pipeline {
    agent any
    
    parameters {
        // Your parameters
    }
    
    environment {
        // Your environment variables
    }
    
    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 30, unit: 'MINUTES')
        timestamps()
    }
    
    stages {
        stage('Stage 1') {
            steps {
                // Your steps
            }
        }
    }
    
    post {
        always {
            cleanWs()
        }
    }
}
```

3. **Mount vào container:**
```yaml
# Already configured in docker-compose.yml
volumes:
  - ./jenkins/Jenkinsfile-templates:/var/jenkins_home/pipeline-templates:ro
```

### Extend Existing Template

```groovy
// Sử dụng template có sẵn và extend
@Library('pipeline-templates') _

// Load base template
def nodeTemplate = load 'pipeline-templates/nodejs.Jenkinsfile'

pipeline {
    agent any
    
    stages {
        // Use base stages
        stage('Build') {
            steps {
                script {
                    nodeTemplate.build()
                }
            }
        }
        
        // Add custom stage
        stage('Custom Deploy') {
            steps {
                echo 'Custom deployment logic...'
            }
        }
    }
}
```

## 🚀 Advanced Configuration

### Shared Libraries

Create shared library structure:

```
shared-library/
├── vars/
│   ├── commonBuild.groovy
│   ├── deployToK8s.groovy
│   └── notifySlack.groovy
├── src/
│   └── com/
│       └── company/
│           └── jenkins/
│               └── Utils.groovy
└── resources/
    └── templates/
        └── deployment.yaml
```

**Example (vars/commonBuild.groovy):**
```groovy
def call(Map config = [:]) {
    pipeline {
        agent any
        stages {
            stage('Build') {
                steps {
                    echo "Building ${config.projectName}"
                    sh "${config.buildCommand}"
                }
            }
        }
    }
}
```

**Usage:**
```groovy
@Library('shared-library@main') _

commonBuild(
    projectName: 'My App',
    buildCommand: 'npm run build'
)
```

### Global Pipeline Libraries

Configure trong `jenkins.yaml`:

```yaml
unclassified:
  globalLibraries:
    libraries:
      - name: "shared-library"
        defaultVersion: "main"
        retriever:
          modernSCM:
            scm:
              git:
                remote: "https://github.com/your-org/shared-library.git"
                credentialsId: "github-credentials"
```

### Docker Agents

Configure dynamic Docker agents:

```yaml
jenkins:
  clouds:
    - docker:
        name: "docker-agents"
        dockerApi:
          dockerHost:
            uri: "unix:///var/run/docker.sock"
        templates:
          - labelString: "docker-agent"
            dockerTemplateBase:
              image: "jenkins/inbound-agent:latest"
            remoteFs: "/home/jenkins/agent"
            connector:
              attach:
                user: "jenkins"
```

**Usage trong Pipeline:**
```groovy
pipeline {
    agent {
        docker {
            image 'node:18-alpine'
            label 'docker-agent'
        }
    }
    stages {
        // Your stages
    }
}
```

## 📊 Monitoring

### Jenkins Metrics

**Enable Prometheus Plugin:**
```bash
echo "prometheus:latest" >> plugins.txt
docker-compose restart jenkins
```

**Configure:**
```yaml
# jenkins.yaml
unclassified:
  metricsaccesskey:
    accessKeys:
      - key: "prometheus"
        description: "Prometheus metrics"
```

**Access metrics:**
```
http://jenkins:8080/prometheus/
```

### Health Checks

```bash
# Jenkins health
curl http://jenkins:8080/login

# API health
curl http://jenkins:8080/api/json

# System info
curl -u admin:token http://jenkins:8080/systemInfo
```

## 🔍 Troubleshooting

### Configuration không load

**Problem:** JCasC configuration không được apply

**Solutions:**
1. Check logs:
```bash
docker logs jenkins | grep -i "configuration as code"
```

2. Validate YAML syntax:
```bash
yamllint jenkins/casc/jenkins.yaml
```

3. Reload config:
```
Manage Jenkins → Configuration as Code → Reload
```

### Plugin installation failed

**Problem:** Plugin không install được

**Solutions:**
1. Check plugin dependencies
2. Update plugin version trong `plugins.txt`
3. Manual install:
```
Manage Jenkins → Manage Plugins → Advanced → Upload Plugin
```

### Build agent không connect

**Problem:** Docker agents không kết nối được

**Solutions:**
1. Check Docker socket permission:
```bash
docker exec jenkins ls -la /var/run/docker.sock
```

2. Verify Docker API:
```bash
docker exec jenkins docker ps
```

3. Check agent configuration trong JCasC

## 📚 Resources

- [Jenkins Configuration as Code](https://github.com/jenkinsci/configuration-as-code-plugin)
- [Jenkins Pipeline Syntax](https://www.jenkins.io/doc/book/pipeline/syntax/)
- [Plugin Index](https://plugins.jenkins.io/)
- [Shared Libraries](https://www.jenkins.io/doc/book/pipeline/shared-libraries/)

## 🤝 Contributing

Để contribute templates hoặc configurations:

1. Test changes locally
2. Update documentation
3. Submit pull request
4. Get review từ DevOps team

## 📞 Support

Questions? Contact:
- DevOps Team: devops@company.com
- Slack: #jenkins-support
- Documentation: http://docs.company.com/jenkins