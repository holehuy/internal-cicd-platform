# Hướng dẫn Thêm Project Mới

## Tổng quan

Document này hướng dẫn chi tiết cách thêm một project mới vào CI/CD platform.

---

## Option 1: Sử dụng Pipeline Template (Recommended)

### Bước 1: Chuẩn bị Repository

#### 1.1. Tạo Jenkinsfile trong repository

**Cho Node.js project:**

```groovy
@Library('pipeline-templates') _

pipeline {
    agent any
    
    parameters {
        string(name: 'NODE_VERSION', defaultValue: 'NodeJS 18')
        string(name: 'PROJECT_KEY', defaultValue: 'your-project-key')
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
                    sh 'npm run build'
                    sh 'npm run test:coverage'
                }
            }
        }
        
        stage('SonarQube Analysis') {
            steps {
                script {
                    load "${WORKSPACE}/../../../pipeline-templates/nodejs.Jenkinsfile"
                }
            }
        }
    }
}
```

**Cho Python project:**

```groovy
@Library('pipeline-templates') _

pipeline {
    agent any
    
    parameters {
        string(name: 'PYTHON_VERSION', defaultValue: '3.11')
        string(name: 'PROJECT_KEY', defaultValue: 'your-project-key')
    }
    
    stages {
        stage('Setup') {
            steps {
                sh 'python${params.PYTHON_VERSION} -m venv .venv'
                sh '. .venv/bin/activate && pip install -r requirements.txt'
            }
        }
        
        stage('Test & Analysis') {
            steps {
                script {
                    load "${WORKSPACE}/../../../pipeline-templates/python.Jenkinsfile"
                }
            }
        }
    }
}
```

#### 1.2. Tạo SonarQube configuration (sonar-project.properties)

```properties
# Project identification
sonar.projectKey=your-project-key
sonar.projectName=Your Project Name
sonar.projectVersion=1.0

# Source code location
sonar.sources=src
sonar.tests=tests

# Exclude patterns
sonar.exclusions=**/node_modules/**,**/dist/**,**/build/**

# Language-specific settings
# For JavaScript/TypeScript
sonar.javascript.lcov.reportPaths=coverage/lcov.info

# For Python
sonar.python.coverage.reportPaths=coverage.xml

# For .NET
sonar.cs.opencover.reportsPaths=coverage.opencover.xml
```

### Bước 2: Tạo SonarQube Project

#### 2.1. Login SonarQube

```bash
URL: http://your-server:9000
Username: admin
Password: [your-password]
```

#### 2.2. Tạo Project

1. Click **"Create Project"**
2. Choose **"Manually"**
3. Fill in:
   - **Project key**: `your-project-key` (phải match với Jenkinsfile)
   - **Display name**: `Your Project Name`
4. Click **"Set Up"**

#### 2.3. Generate Token

1. Choose **"With Jenkins"**
2. Generate token:
   - Name: `jenkins-your-project`
   - Type: `Project Analysis Token`
   - Expiration: `No expiration` hoặc custom
3. **Copy và lưu token này!**

### Bước 3: Configure Jenkins

#### 3.1. Thêm SonarQube Token vào Jenkins

```bash
Jenkins → Manage Jenkins → Credentials → Global → Add Credentials

Kind: Secret text
Secret: [paste token từ bước 2.3]
ID: sonarqube-your-project
Description: SonarQube token for Your Project
```

#### 3.2. Tạo Pipeline Job

1. Vào folder team phù hợp (hoặc tạo mới)
2. Click **"New Item"**
3. Fill in:
   - Name: `your-project-pipeline`
   - Type: **Pipeline**
4. Click **OK**

#### 3.3. Configure Pipeline

**General:**
```
✓ GitHub project: https://github.com/your-org/your-repo
✓ Discard old builds: 10
```

**Build Triggers:**
```
✓ GitHub hook trigger for GITScm polling
□ Build periodically
✓ Poll SCM: H/5 * * * *
```

**Pipeline:**
```
Definition: Pipeline script from SCM
SCM: Git
  Repository URL: https://github.com/your-org/your-repo
  Credentials: [your-git-credentials]
  Branch: */main
Script Path: Jenkinsfile
```

**Advanced:**
```
✓ Lightweight checkout
```

### Bước 4: Setup Webhook (Optional but recommended)

#### For GitHub:

1. Go to repository **Settings → Webhooks → Add webhook**
2. Fill in:
   ```
   Payload URL: http://your-jenkins-url/github-webhook/
   Content type: application/json
   Events: Just the push event
   ```

#### For GitLab:

1. Go to **Settings → Webhooks**
2. Fill in:
   ```
   URL: http://your-jenkins-url/project/your-project-pipeline
   Trigger: Push events
   ```

### Bước 5: Test Pipeline

1. Click **"Build Now"**
2. Watch **Console Output**
3. Verify:
   - Build success ✅
   - Tests pass ✅
   - SonarQube analysis complete ✅
   - Quality Gate passed ✅

---

## Option 2: Custom Pipeline

Nếu project có requirements đặc biệt, tạo custom Jenkinsfile:

```groovy
pipeline {
    agent any
    
    environment {
        // Custom environment variables
        CUSTOM_VAR = 'value'
    }
    
    stages {
        stage('Custom Stage 1') {
            steps {
                echo 'Custom step...'
                // Your custom logic
            }
        }
        
        stage('Build') {
            steps {
                // Your build steps
            }
        }
        
        stage('Test') {
            steps {
                // Your test steps
            }
        }
        
        stage('Deploy') {
            when {
                branch 'main'
            }
            steps {
                // Your deployment steps
            }
        }
    }
    
    post {
        always {
            cleanWs()
        }
        success {
            // Success notification
        }
        failure {
            // Failure notification
        }
    }
}
```

---

## Configuration Examples

### Node.js/React Project

**Jenkinsfile:**
```groovy
pipeline {
    agent any
    
    parameters {
        string(name: 'NODE_VERSION', defaultValue: 'NodeJS 18')
        string(name: 'PROJECT_KEY', defaultValue: 'frontend-app')
    }
    
    stages {
        stage('Install') {
            steps {
                nodejs(nodeJSInstallationName: params.NODE_VERSION) {
                    sh 'npm ci'
                }
            }
        }
        
        stage('Lint') {
            steps {
                nodejs(nodeJSInstallationName: params.NODE_VERSION) {
                    sh 'npm run lint'
                }
            }
        }
        
        stage('Test') {
            steps {
                nodejs(nodeJSInstallationName: params.NODE_VERSION) {
                    sh 'npm run test:coverage'
                }
            }
        }
        
        stage('Build') {
            steps {
                nodejs(nodeJSInstallationName: params.NODE_VERSION) {
                    sh 'npm run build'
                }
            }
        }
        
        stage('SonarQube') {
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
    }
}
```

**package.json scripts:**
```json
{
  "scripts": {
    "lint": "eslint src/**/*.{js,jsx,ts,tsx}",
    "test": "jest",
    "test:coverage": "jest --coverage",
    "build": "react-scripts build"
  }
}
```

### Python/Django Project

**Jenkinsfile:**
```groovy
pipeline {
    agent any
    
    parameters {
        string(name: 'PYTHON_VERSION', defaultValue: '3.11')
        string(name: 'PROJECT_KEY', defaultValue: 'backend-api')
    }
    
    stages {
        stage('Setup') {
            steps {
                sh """
                    python${params.PYTHON_VERSION} -m venv .venv
                    . .venv/bin/activate
                    pip install -r requirements.txt
                    pip install pytest pytest-cov pylint
                """
            }
        }
        
        stage('Lint') {
            steps {
                sh """
                    . .venv/bin/activate
                    pylint **/*.py || true
                """
            }
        }
        
        stage('Test') {
            steps {
                sh """
                    . .venv/bin/activate
                    pytest --cov=. --cov-report=xml
                """
            }
        }
        
        stage('SonarQube') {
            steps {
                withSonarQubeEnv('Internal SonarQube') {
                    sh """
                        sonar-scanner \
                            -Dsonar.projectKey=${params.PROJECT_KEY} \
                            -Dsonar.sources=. \
                            -Dsonar.python.coverage.reportPaths=coverage.xml
                    """
                }
            }
        }
    }
}
```

---

## Troubleshooting

### Pipeline không trigger tự động

**Problem**: Pipeline không chạy khi push code

**Solutions**:
1. Check webhook configuration
2. Verify Jenkins có thể access repository
3. Check "Poll SCM" schedule
4. Review Jenkins logs: `docker logs internal-jenkins`

### SonarQube token invalid

**Problem**: `SonarQube analysis failed: 401 Unauthorized`

**Solutions**:
1. Regenerate token trong SonarQube
2. Update credentials trong Jenkins
3. Verify token chưa expired

### Build timeout

**Problem**: Pipeline timeout sau 30 phút

**Solutions**:
1. Increase timeout trong Jenkinsfile:
```groovy
options {
    timeout(time: 60, unit: 'MINUTES')
}
```
2. Optimize build steps (use caching, parallel stages)

### Out of memory

**Problem**: Build failed với OutOfMemoryError

**Solutions**:
1. Increase Java heap size:
```groovy
environment {
    JAVA_OPTS = '-Xmx2048m'
}
```
2. Clean workspace before build
3. Reduce parallel executions

---

## Best Practices

### 1. Sử dụng Shared Libraries

```groovy
@Library('shared-library@main') _

pipeline {
    agent any
    stages {
        stage('Build') {
            steps {
                script {
                    commonBuild()  // From shared library
                }
            }
        }
    }
}
```

### 2. Caching Dependencies

```groovy
stage('Install') {
    steps {
        // Use cache plugin or Docker volumes
        nodejs(nodeJSInstallationName: 'NodeJS 18') {
            sh 'npm ci --prefer-offline'
        }
    }
}
```

### 3. Parallel Execution

```groovy
stage('Tests') {
    parallel {
        stage('Unit Tests') {
            steps {
                sh 'npm run test:unit'
            }
        }
        stage('Integration Tests') {
            steps {
                sh 'npm run test:integration'
            }
        }
    }
}
```

### 4. Conditional Deployment

```groovy
stage('Deploy') {
    when {
        allOf {
            branch 'main'
            expression { currentBuild.result == 'SUCCESS' }
        }
    }
    steps {
        // Deploy steps
    }
}
```

---

## Checklist

- [ ] Jenkinsfile tạo trong repository
- [ ] SonarQube project đã tạo
- [ ] Token đã generate và lưu trong Jenkins
- [ ] Pipeline job đã configure
- [ ] Webhook đã setup (optional)
- [ ] Test build thành công
- [ ] Quality Gate configured
- [ ] Team members có quyền truy cập
- [ ] Documentation updated

---

## Support

Questions? Contact DevOps team:
- Email: devops@company.com
- Slack: #cicd-support
- Docs: http://docs.company.com/cicd