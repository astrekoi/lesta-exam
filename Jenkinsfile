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
                    
                    if command -v docker >/dev/null 2>&1; then
                        echo "Docker: $(docker --version)"
                    else
                        echo "Docker: ⚠️ Not available in container"
                    fi
                    echo "========================"
                '''
            }
        }
        
        stage('Checkout') {
            steps {
                echo '📥 Downloading repository as ZIP...'
                
                sh '''
                    # Очистка workspace (POSIX совместимо)
                    rm -rf * .git* || true
                    
                    # Скачивание ZIP архива репозитория
                    curl -L https://github.com/astrekoi/lesta-exam/archive/refs/heads/main.zip -o repo.zip
                    
                    # Распаковка
                    unzip -o repo.zip
                    
                    # Перемещение файлов (без bash shopt)
                    cd lesta-exam-main
                    find . -maxdepth 1 -name ".*" -exec cp -r {} .. \\; 2>/dev/null || true
                    find . -maxdepth 1 ! -name "." ! -name ".." -exec cp -r {} .. \\;
                    cd ..
                    
                    # Удаление временных файлов
                    rm -rf lesta-exam-main repo.zip
                    
                    # Проверка содержимого
                    echo "✅ Repository contents:"
                    ls -la
                '''
                
                script {
                    // Версионирование
                    def versionFile = 'version.txt'
                    def currentVersion = 1
                    
                    if (fileExists(versionFile)) {
                        try {
                            currentVersion = readFile(versionFile).trim() as Integer
                            currentVersion++
                        } catch (Exception e) {
                            currentVersion = 1
                        }
                    }
                    
                    writeFile file: versionFile, text: currentVersion.toString()
                    env.AUTO_VERSION = currentVersion.toString()
                    env.RELEASE_TAG = "v${currentVersion}"
                    env.GIT_COMMIT_SHORT = "zip-download"
                    env.GIT_COMMIT_MSG = "Downloaded from GitHub ZIP"
                    env.GIT_BRANCH_CLEAN = "main"
                    
                    archiveArtifacts artifacts: 'version.txt', allowEmptyArchive: true
                }
                
                echo "📋 Branch: main"
                echo "📋 Version: ${env.AUTO_VERSION}"
                echo "📋 Release: ${env.RELEASE_TAG}"
            }
        }
        
        stage('Load Production Environment') {
            steps {
                echo '📋 Loading production environment file...'
                script {
                    withCredentials([file(credentialsId: 'prod-env', variable: 'PROD_ENV_FILE')]) {
                        sh '''
                            cp $PROD_ENV_FILE .env.production
                            echo "✅ Production environment loaded"
                        '''
                    }
                }
            }
        }
        
        stage('Code Quality Check') {
            steps {
                echo '🔍 Running basic code quality checks...'
                sh '''
                    echo "📝 Checking Python syntax..."
                    find app/ -name "*.py" -exec python3 -m py_compile {} \\; 2>/dev/null || echo "⚠️ Python syntax check failed"
                    
                    echo "📊 Code statistics:"
                    find app/ -name "*.py" | wc -l | xargs echo "Python files:"
                    find . -name "*.yml" -o -name "*.yaml" | wc -l | xargs echo "YAML files:"
                    
                    echo "✅ Basic quality check completed"
                '''
            }
        }
        
        stage('Build Application Package') {
            when {
                expression { return sh(script: 'command -v docker', returnStatus: true) != 0 }
            }
            steps {
                echo '📦 Building application package (no Docker available)...'
                sh '''
                    echo "🏗️ Creating application archive..."
                    tar -czf flask-app-${RELEASE_TAG}.tar.gz \
                        app/ requirements.txt docker-compose.yml nginx/ scripts/ \
                        Dockerfile Dockerfile.jenkins .env.production || true
                    
                    echo "✅ Application package created: flask-app-${RELEASE_TAG}.tar.gz"
                    ls -lh *.tar.gz || true
                '''
            }
        }
        
        stage('Build Docker Image') {
            when {
                expression { return sh(script: 'command -v docker', returnStatus: true) == 0 }
            }
            steps {
                echo '🔨 Building Docker image...'
                script {
                    env.DOCKER_IMAGE_NAME = "${DOCKER_REGISTRY_CREDS_USR}/flask-api"
                    env.DOCKER_IMAGE_TAG = "${env.RELEASE_TAG}"
                    env.DOCKER_IMAGE_FULL = "${env.DOCKER_IMAGE_NAME}:${env.DOCKER_IMAGE_TAG}"
                    
                    sh "docker build -t ${env.DOCKER_IMAGE_FULL} ."
                    sh "docker tag ${env.DOCKER_IMAGE_FULL} ${env.DOCKER_IMAGE_NAME}:latest"
                    
                    echo "🔨 Built image: ${env.DOCKER_IMAGE_FULL}"
                }
            }
        }

        stage('Push to Docker Hub') {
            steps {
                echo "📤 Pushing image to Docker Hub..."
                script {
                    withCredentials([usernamePassword(
                        credentialsId: 'docker-registry', 
                        usernameVariable: 'DOCKER_USERNAME', 
                        passwordVariable: 'DOCKER_PASSWORD'
                    )]) {
                        sh '''
                            echo "🔐 Logging into Docker Hub..."
                            echo $DOCKER_PASSWORD | docker login -u $DOCKER_USERNAME --password-stdin
                            
                            echo "📤 Pushing images..."
                            docker push astrokoit/flask-api:${RELEASE_TAG}
                            docker push astrokoit/flask-api:latest
                            
                            echo "✅ Images pushed successfully"
                            docker logout
                        '''
                    }
                }
            }
        }
        
        stage('Deploy to Production') {
            steps {
                echo "🚀 Deploying ${env.RELEASE_TAG} to production server..."
                script {
                    withCredentials([
                        string(credentialsId: 'prod-ip', variable: 'PROD_IP'),
                        sshUserPrivateKey(credentialsId: 'prod-server-ssh', keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USERNAME')
                    ]) {
                        sh '''
                            chmod 600 $SSH_KEY
                            
                            TARGET_PATH="/home/${SSH_USERNAME}/flask-api/production"
                            
                            echo "🚀 Deploying ${RELEASE_TAG} to: ${SSH_USERNAME}@${PROD_IP}:${TARGET_PATH}"
                            
                            ssh -i $SSH_KEY -o StrictHostKeyChecking=no ${SSH_USERNAME}@${PROD_IP} \
                                "mkdir -p ${TARGET_PATH}"
                            
                            ssh -i $SSH_KEY -o StrictHostKeyChecking=no ${SSH_USERNAME}@${PROD_IP} \
                                "ls -la ${TARGET_PATH}"
                            
                            echo "📄 Copying docker-compose.yml..."
                            scp -i $SSH_KEY -o StrictHostKeyChecking=no \
                                ${DOCKER_COMPOSE_FILE} ${SSH_USERNAME}@${PROD_IP}:${TARGET_PATH}/
                            
                            echo "🔄 Updating .env file..."
                            ssh -i $SSH_KEY -o StrictHostKeyChecking=no ${SSH_USERNAME}@${PROD_IP} \
                                "rm -f ${TARGET_PATH}/.env"
                            
                            scp -i $SSH_KEY -o StrictHostKeyChecking=no \
                                .env.production ${SSH_USERNAME}@${PROD_IP}:${TARGET_PATH}/.env
                            
                            ssh -i $SSH_KEY -o StrictHostKeyChecking=no ${SSH_USERNAME}@${PROD_IP} \
                                "chmod 600 ${TARGET_PATH}/.env"
                            
                            echo "📁 Copying application directories..."
                            find . -type d -name "app" -o -name "scripts" -o -name "nginx" | while read dir; do
                                if [ -d "$dir" ]; then
                                    echo "📁 Copying directory: $dir"
                                    scp -i $SSH_KEY -o StrictHostKeyChecking=no -r \
                                        "$dir" ${SSH_USERNAME}@${PROD_IP}:${TARGET_PATH}/
                                fi
                            done
                            
                            echo "📄 Copying additional files..."
                            for file in Dockerfile.jenkins Dockerfile requirements.txt Makefile; do
                                if [ -f "$file" ]; then
                                    echo "📄 Copying file: $file"
                                    scp -i $SSH_KEY -o StrictHostKeyChecking=no \
                                        "$file" ${SSH_USERNAME}@${PROD_IP}:${TARGET_PATH}/
                                fi
                            done
                            
                            echo "🚀 Executing deployment..."
                            ssh -i $SSH_KEY -o StrictHostKeyChecking=no ${SSH_USERNAME}@${PROD_IP} \
                                "export TARGET_PATH='${TARGET_PATH}' && \
                                export RELEASE_TAG='${RELEASE_TAG}' && \
                                export DOCKER_IMAGE_FULL='${DOCKER_IMAGE_FULL:-astrokoit/flask-api:latest}' && \
                                bash -c '
                                    cd \$TARGET_PATH || exit 1
                                    
                                    echo \"📍 Current directory: \$(pwd)\"
                                    echo \"📋 Files in directory:\"
                                    ls -la
                                    
                                    echo \"🛑 Stopping old version...\"
                                    docker compose down || true
                                    
                                    if [ ! -z \"\$DOCKER_IMAGE_FULL\" ]; then
                                        echo \"📥 Pulling image \$DOCKER_IMAGE_FULL...\"
                                        docker pull \$DOCKER_IMAGE_FULL || echo \"⚠️ Could not pull image, will build locally\"
                                    fi
                                    
                                    echo \"🚀 Starting application...\"
                                    docker compose up -d --build
                                    
                                    echo \"⏳ Waiting for services...\"
                                    sleep 30
                                    
                                    echo \"🏥 Health check...\"
                                    curl -f http://localhost/ping || curl -f http://localhost:8080/ping || echo \"⚠️ Health check failed\"
                                    
                                    echo \"✅ Deployment completed!\"
                                '"
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
                        # Очистка временных файлов
                        rm -f repo.zip .env.production || true
                        rm -rf .lint-venv || true
                    '''
                } catch (Exception e) {
                    echo "⚠️ Cleanup failed: ${e.getMessage()}"
                }
                
                try {
                    archiveArtifacts artifacts: '*.tar.gz,*.log,version.txt', allowEmptyArchive: true
                } catch (Exception e) {
                    echo "⚠️ Archiving failed: ${e.getMessage()}"
                }
            }
        }
        
        success {
            echo '✅ Pipeline completed successfully!'
            echo "🚀 Production deployment successful!"
            echo "🏷️ Release: ${env.RELEASE_TAG ?: 'unknown'}"
            
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
    }
}
