#!/usr/bin/env groovy

/**
 * Standard Pipeline for Python Projects
 * 
 * Required parameters:
 * - PYTHON_VERSION: Python version (e.g., '3.11')
 * - PROJECT_KEY: SonarQube project key
 * - REQUIREMENTS_FILE: Requirements file path (default: requirements.txt)
 */

pipeline {
    agent any
    
    parameters {
        string(name: 'PYTHON_VERSION', defaultValue: '3.11', description: 'Python version to use')
        string(name: 'PROJECT_KEY', defaultValue: '', description: 'SonarQube project key')
        string(name: 'REQUIREMENTS_FILE', defaultValue: 'requirements.txt', description: 'Requirements file path')
        booleanParam(name: 'RUN_TESTS', defaultValue: true, description: 'Run unit tests')
        booleanParam(name: 'RUN_LINT', defaultValue: true, description: 'Run code linting')
        booleanParam(name: 'BUILD_DOCKER', defaultValue: false, description: 'Build Docker image')
    }
    
    environment {
        SONAR_SCANNER_HOME = tool 'SonarScanner'
        PATH = "${SONAR_SCANNER_HOME}/bin:${env.PATH}"
        VENV_PATH = "${WORKSPACE}/.venv"
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
        
        stage('Setup Python Environment') {
            steps {
                script {
                    echo "🐍 Setting up Python ${params.PYTHON_VERSION} virtual environment..."
                    sh """
                        python${params.PYTHON_VERSION} -m venv ${VENV_PATH}
                        . ${VENV_PATH}/bin/activate
                        python --version
                        pip install --upgrade pip setuptools wheel
                    """
                }
            }
        }
        
        stage('Install Dependencies') {
            steps {
                script {
                    echo "📦 Installing dependencies from ${params.REQUIREMENTS_FILE}..."
                    sh """
                        . ${VENV_PATH}/bin/activate
                        
                        if [ -f "${params.REQUIREMENTS_FILE}" ]; then
                            pip install -r ${params.REQUIREMENTS_FILE}
                        fi
                        
                        # Install dev dependencies if exists
                        if [ -f "requirements-dev.txt" ]; then
                            pip install -r requirements-dev.txt
                        fi
                        
                        # Install test dependencies
                        pip install pytest pytest-cov pytest-xdist pylint flake8 black mypy
                        
                        pip list
                    """
                }
            }
        }
        
        stage('Code Formatting Check') {
            when {
                expression { params.RUN_LINT }
            }
            steps {
                script {
                    echo "✨ Checking code formatting with Black..."
                    sh """
                        . ${VENV_PATH}/bin/activate
                        black --check . || true
                    """
                }
            }
        }
        
        stage('Lint') {
            when {
                expression { params.RUN_LINT }
            }
            steps {
                script {
                    echo "🔍 Running linters..."
                    sh """
                        . ${VENV_PATH}/bin/activate
                        
                        # Flake8
                        echo "Running flake8..."
                        flake8 . --count --select=E9,F63,F7,F82 --show-source --statistics || true
                        
                        # Pylint
                        echo "Running pylint..."
                        pylint **/*.py --output-format=parseable --reports=no || true
                        
                        # MyPy (type checking)
                        echo "Running mypy..."
                        mypy . --ignore-missing-imports || true
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
                    echo "🧪 Running unit tests with pytest..."
                    sh """
                        . ${VENV_PATH}/bin/activate
                        
                        pytest \
                            --verbose \
                            --cov=. \
                            --cov-report=xml:coverage.xml \
                            --cov-report=html:htmlcov \
                            --cov-report=term \
                            --junitxml=test-results/junit.xml \
                            -n auto \
                            tests/ || true
                    """
                }
            }
            post {
                always {
                    // Publish test results
                    junit testResults: 'test-results/junit.xml', allowEmptyResults: true
                    
                    // Publish coverage report
                    publishHTML(target: [
                        allowMissing: true,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: 'htmlcov',
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
                        sh """
                            . ${VENV_PATH}/bin/activate
                            
                            sonar-scanner \
                                -Dsonar.projectKey=${params.PROJECT_KEY} \
                                -Dsonar.sources=. \
                                -Dsonar.exclusions=**/tests/**,**/__pycache__/**,**/.venv/** \
                                -Dsonar.python.coverage.reportPaths=coverage.xml \
                                -Dsonar.python.version=${params.PYTHON_VERSION}
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
        
        stage('Build Package') {
            steps {
                script {
                    echo "📦 Building Python package..."
                    sh """
                        . ${VENV_PATH}/bin/activate
                        
                        if [ -f "setup.py" ]; then
                            python setup.py sdist bdist_wheel
                        elif [ -f "pyproject.toml" ]; then
                            pip install build
                            python -m build
                        else
                            echo "No setup.py or pyproject.toml found, skipping package build"
                        fi
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
                            --build-arg PYTHON_VERSION=${params.PYTHON_VERSION} \
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
                        . ${VENV_PATH}/bin/activate
                        
                        # Install safety
                        pip install safety bandit
                        
                        # Check for known vulnerabilities
                        echo "Checking dependencies for vulnerabilities..."
                        safety check --json || true
                        
                        # Run bandit for security issues
                        echo "Running bandit security scanner..."
                        bandit -r . -f json -o bandit-report.json || true
                    """
                }
            }
        }
    }
    
    post {
        always {
            // Archive artifacts
            archiveArtifacts artifacts: 'dist/**,*.whl,*.tar.gz', allowEmptyArchive: true
            
            // Clean workspace
            cleanWs(
                deleteDirs: true,
                patterns: [
                    [pattern: '.venv', type: 'INCLUDE'],
                    [pattern: '__pycache__', type: 'INCLUDE'],
                    [pattern: '*.pyc', type: 'INCLUDE'],
                    [pattern: '.pytest_cache', type: 'INCLUDE']
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