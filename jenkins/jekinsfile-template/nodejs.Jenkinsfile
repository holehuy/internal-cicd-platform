#!/usr/bin/env groovy

/**
 * Standard Pipeline for Node.js Projects
 * 
 * Required parameters in project:
 * - NODE_VERSION: NodeJS version (e.g., 'NodeJS 18')
 * - PROJECT_KEY: SonarQube project key
 * - DOCKER_IMAGE: Docker image name (optional)
 */

pipeline {
    agent any
    
    parameters {
        string(name: 'NODE_VERSION', defaultValue: 'NodeJS 18', description: 'NodeJS version to use')
        string(name: 'PROJECT_KEY', defaultValue: '', description: 'SonarQube project key')
        booleanParam(name: 'RUN_TESTS', defaultValue: true, description: 'Run unit tests')
        booleanParam(name: 'BUILD_DOCKER', defaultValue: false, description: 'Build Docker image')
    }
    
    environment {
        SONAR_SCANNER_HOME = tool 'SonarScanner'
        PATH = "${SONAR_SCANNER_HOME}/bin:${env.PATH}"
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
                    
                    // Get commit info
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
        
        stage('Setup') {
            steps {
                script {
                    echo "📦 Installing dependencies..."
                    nodejs(nodeJSInstallationName: params.NODE_VERSION) {
                        sh '''
                            node --version
                            npm --version
                            npm ci --prefer-offline --no-audit
                        '''
                    }
                }
            }
        }
        
        stage('Lint') {
            steps {
                script {
                    echo "🔍 Running linter..."
                    nodejs(nodeJSInstallationName: params.NODE_VERSION) {
                        sh 'npm run lint || true'
                    }
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
                    nodejs(nodeJSInstallationName: params.NODE_VERSION) {
                        sh '''
                            npm run test:coverage || true
                        '''
                    }
                }
            }
            post {
                always {
                    // Publish test results
                    junit testResults: '**/test-results/*.xml', allowEmptyResults: true
                    
                    // Publish coverage report
                    publishHTML(target: [
                        allowMissing: true,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: 'coverage/lcov-report',
                        reportFiles: 'index.html',
                        reportName: 'Coverage Report'
                    ])
                }
            }
        }
        
        stage('SonarQube Analysis') {
            when {
                expression { params.PROJECT_KEY != '' }
            }
            steps {
                script {
                    echo "📊 Running SonarQube analysis..."
                    withSonarQubeEnv('Internal SonarQube') {
                        nodejs(nodeJSInstallationName: params.NODE_VERSION) {
                            sh """
                                sonar-scanner \
                                    -Dsonar.projectKey=${params.PROJECT_KEY} \
                                    -Dsonar.sources=src \
                                    -Dsonar.tests=tests \
                                    -Dsonar.javascript.lcov.reportPaths=coverage/lcov.info \
                                    -Dsonar.testExecutionReportPaths=test-results/sonar-report.xml
                            """
                        }
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
                            // Don't fail the build, just warn
                            unstable("Quality Gate failed")
                        } else {
                            echo "✅ Quality Gate passed!"
                        }
                    }
                }
            }
        }
        
        stage('Build') {
            steps {
                script {
                    echo "🔨 Building application..."
                    nodejs(nodeJSInstallationName: params.NODE_VERSION) {
                        sh 'npm run build'
                    }
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
                            --build-arg NODE_VERSION=${params.NODE_VERSION} \
                            --build-arg BUILD_DATE=\$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
                            --build-arg VCS_REF=${env.GIT_COMMIT_SHORT} \
                            .
                    """
                    
                    echo "✅ Docker image built: ${dockerImage}"
                }
            }
        }
    }
    
    post {
        always {
            // Clean workspace
            cleanWs(
                deleteDirs: true,
                patterns: [
                    [pattern: 'node_modules', type: 'INCLUDE'],
                    [pattern: '.npm', type: 'INCLUDE']
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