#!/usr/bin/env groovy

/**
 * Standard Pipeline for .NET Projects
 * 
 * Required parameters:
 * - DOTNET_VERSION: .NET SDK version (e.g., '8.0')
 * - PROJECT_KEY: SonarQube project key
 * - SOLUTION_FILE: Solution file path
 */

pipeline {
    agent any
    
    parameters {
        string(name: 'DOTNET_VERSION', defaultValue: '8.0', description: '.NET SDK version')
        string(name: 'PROJECT_KEY', defaultValue: '', description: 'SonarQube project key')
        string(name: 'SOLUTION_FILE', defaultValue: '*.sln', description: 'Solution file path')
        choice(name: 'BUILD_CONFIGURATION', choices: ['Release', 'Debug'], description: 'Build configuration')
        booleanParam(name: 'RUN_TESTS', defaultValue: true, description: 'Run unit tests')
        booleanParam(name: 'BUILD_DOCKER', defaultValue: false, description: 'Build Docker image')
    }
    
    environment {
        DOTNET_CLI_TELEMETRY_OPTOUT = '1'
        DOTNET_SKIP_FIRST_TIME_EXPERIENCE = '1'
        DOTNET_NOLOGO = 'true'
    }
    
    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 30, unit: 'MINUTES')
        timestamps()
        ansiColor('xterm')
    }
    
    stages {
        stage('Checkout') {
            steps {
                script {
                    echo "🔄 Checking out source code..."
                    checkout scm
                    
                    env.GIT_COMMIT_SHORT = sh(
                        script: "git rev-parse --short HEAD",
                        returnStdout: true
                    ).trim()
                    env.GIT_BRANCH_NAME = env.BRANCH_NAME ?: sh(
                        script: "git rev-parse --abbrev-ref HEAD",
                        returnStdout: true
                    ).trim()
                }
            }
        }
        
        stage('Setup .NET') {
            steps {
                script {
                    echo "⚙️ Setting up .NET ${params.DOTNET_VERSION}..."
                    sh """
                        # Install .NET SDK if not present
                        if ! command -v dotnet &> /dev/null; then
                            curl -sSL https://dot.net/v1/dotnet-install.sh | bash /dev/stdin --version ${params.DOTNET_VERSION}
                        fi
                        
                        dotnet --version
                        dotnet --list-sdks
                    """
                }
            }
        }
        
        stage('Restore Dependencies') {
            steps {
                script {
                    echo "📦 Restoring NuGet packages..."
                    sh """
                        dotnet restore ${params.SOLUTION_FILE} \
                            --verbosity minimal
                    """
                }
            }
        }
        
        stage('SonarQube - Begin') {
            when {
                expression { params.PROJECT_KEY != '' }
            }
            steps {
                script {
                    echo "📊 Starting SonarQube analysis..."
                    withSonarQubeEnv('Internal SonarQube') {
                        sh """
                            dotnet tool install --global dotnet-sonarscanner || true
                            export PATH="\$PATH:\$HOME/.dotnet/tools"
                            
                            dotnet sonarscanner begin \
                                /k:"${params.PROJECT_KEY}" \
                                /d:sonar.host.url="\${SONAR_HOST_URL}" \
                                /d:sonar.login="\${SONAR_AUTH_TOKEN}" \
                                /d:sonar.cs.opencover.reportsPaths="**/coverage.opencover.xml" \
                                /d:sonar.cs.vstest.reportsPaths="**/*.trx"
                        """
                    }
                }
            }
        }
        
        stage('Build') {
            steps {
                script {
                    echo "🔨 Building solution..."
                    sh """
                        dotnet build ${params.SOLUTION_FILE} \
                            --configuration ${params.BUILD_CONFIGURATION} \
                            --no-restore \
                            --verbosity minimal
                    """
                }
            }
        }
        
        stage('Unit Tests') {
            when {
                expression { params.RUN_TESTS }
            }
            steps {
                script {
                    echo "🧪 Running unit tests..."
                    sh """
                        dotnet test ${params.SOLUTION_FILE} \
                            --configuration ${params.BUILD_CONFIGURATION} \
                            --no-build \
                            --no-restore \
                            --logger "trx;LogFileName=test-results.trx" \
                            --collect:"XPlat Code Coverage" \
                            -- DataCollectionRunSettings.DataCollectors.DataCollector.Configuration.Format=opencover
                    """
                }
            }
            post {
                always {
                    // Publish test results
                    script {
                        def testResults = findFiles(glob: '**/test-results.trx')
                        if (testResults) {
                            mstest testResultsFile: '**/test-results.trx'
                        }
                    }
                    
                    // Publish coverage report
                    publishHTML(target: [
                        allowMissing: true,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: 'TestResults',
                        reportFiles: '*/coverage.cobertura.xml',
                        reportName: 'Coverage Report'
                    ])
                }
            }
        }
        
        stage('SonarQube - End') {
            when {
                expression { params.PROJECT_KEY != '' }
            }
            steps {
                script {
                    echo "📊 Completing SonarQube analysis..."
                    withSonarQubeEnv('Internal SonarQube') {
                        sh """
                            export PATH="\$PATH:\$HOME/.dotnet/tools"
                            dotnet sonarscanner end /d:sonar.login="\${SONAR_AUTH_TOKEN}"
                        """
                    }
                }
            }
        }
        
        stage('Quality Gate') {
            when {
                expression { params.PROJECT_KEY != '' }
            }
            steps {
                script {
                    echo "⏳ Waiting for Quality Gate..."
                    timeout(time: 5, unit: 'MINUTES') {
                        def qg = waitForQualityGate()
                        if (qg.status != 'OK') {
                            echo "⚠️ Quality Gate failed: ${qg.status}"
                            unstable("Quality Gate failed")
                        } else {
                            echo "✅ Quality Gate passed!"
                        }
                    }
                }
            }
        }
        
        stage('Publish Artifacts') {
            steps {
                script {
                    echo "📦 Publishing artifacts..."
                    sh """
                        dotnet publish ${params.SOLUTION_FILE} \
                            --configuration ${params.BUILD_CONFIGURATION} \
                            --no-build \
                            --no-restore \
                            --output ./publish
                    """
                }
            }
        }
        
        stage('Docker Build') {
            when {
                expression { params.BUILD_DOCKER }
            }
            steps {
                script {
                    echo "🐳 Building Docker image..."
                    def dockerImage = params.DOCKER_IMAGE ?: "app:${env.GIT_COMMIT_SHORT}"
                    
                    sh """
                        docker build \
                            -t ${dockerImage} \
                            --build-arg DOTNET_VERSION=${params.DOTNET_VERSION} \
                            --build-arg BUILD_CONFIGURATION=${params.BUILD_CONFIGURATION} \
                            --build-arg BUILD_DATE=\$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
                            --build-arg VCS_REF=${env.GIT_COMMIT_SHORT} \
                            .
                    """
                    
                    echo "✅ Docker image built: ${dockerImage}"
                }
            }
        }
        
        stage('Security Scan') {
            steps {
                script {
                    echo "🔒 Running security scan..."
                    sh """
                        # Install OWASP Dependency Check CLI
                        dotnet tool install --global dotnet-outdated-tool || true
                        export PATH="\$PATH:\$HOME/.dotnet/tools"
                        
                        # Check for outdated packages
                        dotnet outdated ${params.SOLUTION_FILE} || true
                        
                        # TODO: Add more security scans if needed
                    """
                }
            }
        }
    }
    
    post {
        always {
            // Archive artifacts
            archiveArtifacts artifacts: 'publish/**/*', allowEmptyArchive: true
            
            // Clean workspace
            cleanWs(
                deleteDirs: true,
                patterns: [
                    [pattern: 'bin', type: 'INCLUDE'],
                    [pattern: 'obj', type: 'INCLUDE'],
                    [pattern: 'TestResults', type: 'INCLUDE'],
                    [pattern: 'publish', type: 'INCLUDE']
                ]
            )
        }
        
        success {
            echo "✅ Build completed successfully!"
        }
        
        failure {
            echo "❌ Build failed!"
        }
        
        unstable {
            echo "⚠️ Build is unstable!"
        }
    }
}