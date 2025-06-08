pipeline {
    agent any

    tools {
        nodejs 'node-18'
        jdk 'openjdk-11'
        maven 'maven-3.8'
        gradle 'gradle-7'
    }

    environment {
        DOCKER_COMPOSE_FILE = 'docker-compose.yml'
        DOCKER_REGISTRY_CREDS = credentials('docker-registry')
        BRANCH_NAME = 'main'
        GIT_REPO_URL = 'https://github.com/astrekoi/lesta-exam.git'

        JAVA_HOME = tool 'openjdk-11'
        NODE_HOME = tool 'node-18'
    }
    
    stages {
        stage('Environment Check') {
            steps {
                sh '''
                    echo "=== Tool Versions ==="
                    echo "Node: $(node --version)"
                    echo "NPM: $(npm --version)"
                    echo "Java: $(java -version 2>&1 | head -1)"
                    echo "Maven: $(mvn --version | head -1)"
                    echo "Gradle: $(gradle --version | grep Gradle)"
                    echo "Git: $(git --version)"
                    echo "Docker: $(docker --version)"
                    echo "========================"
                '''
            }
        }

        stage('Checkout') {
            steps {
                echo '📥 Downloading repository...'
                
                sh '''
                    # Скачиваем репозиторий как ZIP архив
                    curl -L https://github.com/astrekoi/lesta-exam/archive/main.zip -o repo.zip
                    
                    # Распаковываем
                    unzip -o repo.zip
                    
                    # Переносим содержимое из папки в корень workspace
                    mv lesta-exam-main/* . || true
                    mv lesta-exam-main/.* . 2>/dev/null || true
                    
                    # Убираем временные файлы
                    rm -rf lesta-exam-main repo.zip
                '''
                
                script {
                    def versionFile = 'version.txt'
                    def currentVersion = 1
                    
                    if (fileExists(versionFile)) {
                        try {
                            currentVersion = readFile(versionFile).trim() as Integer
                            currentVersion++
                        } catch (Exception e) {
                            echo "⚠️ Failed to read version file: ${e.getMessage()}"
                            currentVersion = 1
                        }
                    }
                    
                    writeFile file: versionFile, text: currentVersion.toString()
                    env.AUTO_VERSION = currentVersion.toString()
                    env.RELEASE_TAG = "v${currentVersion}"
                    env.GIT_COMMIT_SHORT = "latest"
                    env.GIT_COMMIT_MSG = "Downloaded from GitHub"
                    env.GIT_BRANCH_CLEAN = "main"
                    
                    archiveArtifacts artifacts: 'version.txt', allowEmptyArchive: true
                }
                
                echo "📋 Branch: main"
                echo "📋 Commit: latest" 
                echo "📋 Auto Version: ${env.AUTO_VERSION}"
                echo "📋 Release Tag: ${env.RELEASE_TAG}"
            }
        }
        
        stage('Load Production Environment') {
            steps {
                echo '📋 Loading production environment file...'
                script {
                    withCredentials([file(credentialsId: 'prod-env', variable: 'PROD_ENV_FILE')]) {
                        sh '''
                            echo "📄 Copying production environment file..."
                            cp $PROD_ENV_FILE .env.production
                            echo "✅ Production environment loaded"
                        '''
                    }
                }
            }
        }
        
        stage('Lint & Code Quality') {
            steps {
                echo '🔍 Running code quality checks...'
                script {
                    sh '''
                        python3 -m venv .lint-venv
                        source .lint-venv/bin/activate
                        pip install --upgrade pip
                        pip install flake8 black isort bandit safety
                        pip install -r requirements.txt
                    '''
                    
                    sh '''
                        source .lint-venv/bin/activate
                        echo "🔍 Running flake8..."
                        flake8 app/ --max-line-length=88 --exclude=migrations --format=html --htmldir=flake8-report || true
                        flake8 app/ --max-line-length=88 --exclude=migrations
                    '''
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: '*-report*', allowEmptyArchive: true
                    publishHTML([
                        allowMissing: true,
                        alwaysLinkToLastBuild: false,
                        keepAll: true,
                        reportDir: 'flake8-report',
                        reportFiles: 'index.html',
                        reportName: 'Flake8 Report'
                    ])
                }
            }
        }
        
        stage('Build Docker Image') {
            steps {
                echo '🔨 Building Docker image...'
                script {
                    env.DOCKER_IMAGE_NAME = "${DOCKER_REGISTRY_CREDS_USR}/flask-api"
                    env.DOCKER_IMAGE_TAG = "${env.RELEASE_TAG}"
                    env.DOCKER_IMAGE_FULL = "${env.DOCKER_IMAGE_NAME}:${env.DOCKER_IMAGE_TAG}"
                    
                    def image = docker.build("${env.DOCKER_IMAGE_FULL}")
                    sh "docker tag ${env.DOCKER_IMAGE_FULL} ${env.DOCKER_IMAGE_NAME}:latest"
                    
                    echo "🔨 Built image: ${env.DOCKER_IMAGE_FULL}"
                }
            }
        }
        
        stage('Test Application') {
            steps {
                echo '🧪 Testing application...'
                script {
                    try {
                        sh '''
                            docker network create test-network || true
                            
                            docker run -d --name test-postgres --network test-network \
                                -e POSTGRES_USER=postgres \
                                -e POSTGRES_PASSWORD=postgres \
                                -e POSTGRES_DB=test_db \
                                postgres:15-alpine
                            
                            sleep 15
                        '''
                        
                        sh '''
                            docker run -d --name test-app --network test-network \
                                -e POSTGRES_HOST=test-postgres \
                                -e POSTGRES_USER=postgres \
                                -e POSTGRES_PASSWORD=postgres \
                                -e POSTGRES_DB=test_db \
                                -p 5001:5000 \
                                ${DOCKER_IMAGE_FULL}
                            
                            sleep 20
                        '''
                        
                        sh '''
                            curl -f http://localhost:5001/ping
                            
                            curl -X POST http://localhost:5001/submit \
                                -H "Content-Type: application/json" \
                                -d \'{"name": "Jenkins Test ${RELEASE_TAG}", "score": 95}\'
                            
                            curl -f http://localhost:5001/results
                            
                            echo "✅ All tests passed for ${RELEASE_TAG}!"
                        '''
                        
                    } finally {
                        sh '''
                            docker stop test-app test-postgres || true
                            docker rm test-app test-postgres || true
                            docker network rm test-network || true
                        '''
                    }
                }
            }
        }
        
        stage('Push to Registry') {
            steps {
                echo '📤 Pushing to Docker Registry...'
                script {
                    sh '''
                        echo $DOCKER_REGISTRY_CREDS_PSW | docker login -u $DOCKER_REGISTRY_CREDS_USR --password-stdin
                        
                        echo "📤 Pushing versioned image..."
                        docker push ${DOCKER_IMAGE_FULL}
                        docker push ${DOCKER_IMAGE_NAME}:latest
                        
                        echo "✅ Images pushed successfully!"
                    '''
                }
            }
        }
        
        stage('Deploy to Production') {
            steps {
                echo "🚀 Deploying ${env.RELEASE_TAG} to production server..."
                script {
                    withCredentials([
                        string(credentialsId: 'prod-ip', variable: 'PROD_IP'),
                        // ИСПРАВЛЕНО: Используем SSH credential который содержит username
                        sshUserPrivateKey(credentialsId: 'prod-server-ssh', keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USERNAME')
                    ]) {
                        sh '''
                            chmod 600 $SSH_KEY
                            
                            TARGET_PATH="/opt/flask-api/production"
                            
                            # ИСПРАВЛЕНО: Используем SSH_USERNAME вместо PROD_USER
                            echo "🚀 Deploying ${RELEASE_TAG} to: ${SSH_USERNAME}@${PROD_IP}:${TARGET_PATH}"
                            
                            ssh -i $SSH_KEY -o StrictHostKeyChecking=no ${SSH_USERNAME}@${PROD_IP} \
                                "mkdir -p ${TARGET_PATH}"
                            
                            scp -i $SSH_KEY -o StrictHostKeyChecking=no \
                                $DOCKER_COMPOSE_FILE ${SSH_USERNAME}@${PROD_IP}:${TARGET_PATH}/
                            
                            scp -i $SSH_KEY -o StrictHostKeyChecking=no \
                                .env.production ${SSH_USERNAME}@${PROD_IP}:${TARGET_PATH}/.env
                            
                            scp -i $SSH_KEY -o StrictHostKeyChecking=no \
                                Makefile ${SSH_USERNAME}@${PROD_IP}:${TARGET_PATH}/
                            
                            scp -i $SSH_KEY -o StrictHostKeyChecking=no -r \
                                scripts/ ${SSH_USERNAME}@${PROD_IP}:${TARGET_PATH}/
                            
                            scp -i $SSH_KEY -o StrictHostKeyChecking=no -r \
                                nginx/ ${SSH_USERNAME}@${PROD_IP}:${TARGET_PATH}/
                            
                            ssh -i $SSH_KEY -o StrictHostKeyChecking=no ${SSH_USERNAME}@${PROD_IP} << EOF
                                cd ${TARGET_PATH}
                                
                                echo "🔐 Generating SSL certificates on remote server..."
                                make generate-ssl
                                
                                export DOCKER_IMAGE=${DOCKER_IMAGE_FULL}
                                export RELEASE_TAG=${RELEASE_TAG}
                                
                                echo "🛑 Stopping old version..."
                                docker-compose down || true
                                
                                echo "📥 Pulling new image ${DOCKER_IMAGE_FULL}..."
                                docker pull ${DOCKER_IMAGE_FULL}
                                
                                echo "🚀 Starting new version ${RELEASE_TAG}..."
                                docker-compose up -d
                                
                                echo "⏳ Waiting for services to start..."
                                sleep 30
                                
                                echo "📊 Checking service status..."
                                docker-compose ps
                                
                                echo "🏥 Health check..."
                                curl -f http://localhost/ping || curl -f http://localhost:8080/ping || exit 1
                                
                                echo "✅ Deployment successful!"
                                echo "🌐 Release: ${RELEASE_TAG}"
                                echo "📍 Location: ${TARGET_PATH}"
                                echo "🔗 URL: http://${PROD_IP}"
                            EOF
                        '''
                    }
                }
            }
        }
    }
    
    post {
        always {
            script {
                try {
                    echo '🧹 Cleaning up...'
                    sh '''
                        docker image prune -f || true
                        docker system prune -f || true
                        rm -f .env.production || true
                    '''
                } catch (Exception e) {
                    echo "⚠️ Cleanup failed: ${e.getMessage()}"
                }
                
                try {
                    archiveArtifacts artifacts: '*.log,version.txt', allowEmptyArchive: true
                } catch (Exception e) {
                    echo "⚠️ Archiving failed: ${e.getMessage()}"
                }
            }
        }
        
        success {
            echo '✅ Pipeline completed successfully!'
            echo "🚀 Production deployment successful!"
            echo "🏷️ Release: ${env.RELEASE_TAG ?: 'unknown'}"
            echo "🐳 Docker Image: ${env.DOCKER_IMAGE_FULL ?: 'unknown'}"
            
            script {
                withCredentials([string(credentialsId: 'prod-ip', variable: 'PROD_IP')]) {
                    echo "🌐 Application endpoint: http://${PROD_IP}/results"
                    echo "🔗 Health check: http://${PROD_IP}/ping"
                }
            }
        }
        
        failure {
            echo '❌ Pipeline failed!'
            echo "💥 Build failed at stage: ${env.STAGE_NAME ?: 'unknown'}"
            echo "💥 Failed release: ${env.RELEASE_TAG ?: 'unknown'}"
        }
        
        unstable {
            echo '⚠️ Pipeline unstable!'
        }
    }
}
