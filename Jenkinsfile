pipeline {
    agent any
    
    environment {
        DOCKER_COMPOSE_FILE = 'docker-compose.yml'
        DOCKER_REGISTRY_CREDS = credentials('docker-registry')
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo '📥 Cloning repository...'
                checkout scm
                script {
                    env.GIT_COMMIT_SHORT = sh(
                        script: 'git rev-parse --short HEAD',
                        returnStdout: true
                    ).trim()
                    env.GIT_COMMIT_MSG = sh(
                        script: 'git log -1 --pretty=%B',
                        returnStdout: true
                    ).trim()
                    env.GIT_BRANCH_CLEAN = env.BRANCH_NAME.replaceAll('/', '-')
                    
                    def versionFile = 'version.txt'
                    def currentVersion = 1
                    
                    if (fileExists(versionFile)) {
                        currentVersion = readFile(versionFile).trim() as Integer
                        currentVersion++
                    }
                    
                    writeFile file: versionFile, text: currentVersion.toString()
                    env.AUTO_VERSION = currentVersion.toString()
                    env.RELEASE_TAG = "v${currentVersion}"
                    
                    archiveArtifacts artifacts: 'version.txt', allowEmptyArchive: false
                }
                echo "📋 Branch: ${env.BRANCH_NAME}"
                echo "📋 Commit: ${env.GIT_COMMIT_SHORT}"
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
                    
                    sh '''
                        source .lint-venv/bin/activate
                        echo "🔍 Running black check..."
                        black --check app/ || true
                        
                        echo "🔍 Running isort check..."
                        isort --check-only app/ || true
                        
                        echo "🔍 Running bandit security check..."
                        bandit -r app/ -f json -o bandit-report.json || true
                        
                        echo "🔍 Running safety check..."
                        safety check --json --output safety-report.json || true
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
                    
                    if (env.BRANCH_NAME == 'main' || env.BRANCH_NAME == 'master') {
                        env.DOCKER_IMAGE_TAG = "${env.RELEASE_TAG}"
                    } else {
                        env.DOCKER_IMAGE_TAG = "${env.GIT_BRANCH_CLEAN}-${env.AUTO_VERSION}"
                    }
                    
                    env.DOCKER_IMAGE_FULL = "${env.DOCKER_IMAGE_NAME}:${env.DOCKER_IMAGE_TAG}"
                    
                    def image = docker.build("${env.DOCKER_IMAGE_FULL}")
                    
                    if (env.BRANCH_NAME == 'main' || env.BRANCH_NAME == 'master') {
                        sh "docker tag ${env.DOCKER_IMAGE_FULL} ${env.DOCKER_IMAGE_NAME}:latest"
                    }
                    sh "docker tag ${env.DOCKER_IMAGE_FULL} ${env.DOCKER_IMAGE_NAME}:${env.GIT_BRANCH_CLEAN}-latest"
                    
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
                        docker push ${DOCKER_IMAGE_NAME}:${GIT_BRANCH_CLEAN}-latest
                        
                        echo "✅ Images pushed successfully!"
                    '''
                    
                    if (env.BRANCH_NAME == 'main' || env.BRANCH_NAME == 'master') {
                        sh '''
                            echo "📤 Pushing as latest for main branch..."
                            docker push ${DOCKER_IMAGE_NAME}:latest
                        '''
                    }
                }
            }
        }
        
        stage('Deploy to Production') {
            when {
                anyOf {
                    branch 'main'
                    branch 'master'
                    branch 'develop'
                    branch 'staging'
                }
            }
            steps {
                echo "🚀 Deploying ${env.RELEASE_TAG} to production server..."
                script {
                    withCredentials([
                        string(credentialsId: 'prod-ip', variable: 'PROD_IP'),
                        string(credentialsId: 'prod-server-user', variable: 'PROD_USER'),
                        sshUserPrivateKey(credentialsId: 'prod-server-ssh', keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USERNAME')
                    ]) {
                        sh '''
                            chmod 600 $SSH_KEY
                            
                            # Определяем целевую директорию на основе ветки
                            if [ "${BRANCH_NAME}" = "main" ] || [ "${BRANCH_NAME}" = "master" ]; then
                                TARGET_PATH="/opt/flask-api/production"
                            else
                                TARGET_PATH="/opt/flask-api/${GIT_BRANCH_CLEAN}"
                            fi
                            
                            echo "🚀 Deploying ${RELEASE_TAG} to: ${PROD_USER}@${PROD_IP}:${TARGET_PATH}"
                            
                            # Создание директории и копирование Makefile/scripts
                            ssh -i $SSH_KEY -o StrictHostKeyChecking=no ${PROD_USER}@${PROD_IP} \
                                "mkdir -p ${TARGET_PATH}"
                            
                            # Копирование всех необходимых файлов
                            scp -i $SSH_KEY -o StrictHostKeyChecking=no \
                                $DOCKER_COMPOSE_FILE ${PROD_USER}@${PROD_IP}:${TARGET_PATH}/
                            
                            scp -i $SSH_KEY -o StrictHostKeyChecking=no \
                                .env.production ${PROD_USER}@${PROD_IP}:${TARGET_PATH}/.env
                            
                            scp -i $SSH_KEY -o StrictHostKeyChecking=no \
                                Makefile ${PROD_USER}@${PROD_IP}:${TARGET_PATH}/
                            
                            scp -i $SSH_KEY -o StrictHostKeyChecking=no -r \
                                scripts/ ${PROD_USER}@${PROD_IP}:${TARGET_PATH}/
                            
                            scp -i $SSH_KEY -o StrictHostKeyChecking=no -r \
                                nginx/ ${PROD_USER}@${PROD_IP}:${TARGET_PATH}/
                            
                            # Развертывание на удаленном сервере
                            ssh -i $SSH_KEY -o StrictHostKeyChecking=no ${PROD_USER}@${PROD_IP} << EOF
                                cd ${TARGET_PATH}
                                
                                echo "🔐 Generating SSL certificates on remote server..."
                                make generate-ssl
                                
                                # Установка переменных окружения
                                export DOCKER_IMAGE=${DOCKER_IMAGE_FULL}
                                export RELEASE_TAG=${RELEASE_TAG}
                                export BRANCH_NAME=${BRANCH_NAME}
                                
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
        
        stage('Create GitHub Release') {
            when {
                anyOf {
                    branch 'main'
                    branch 'master'
                }
            }
            steps {
                echo "🏷️ Creating GitHub release ${env.RELEASE_TAG}..."
                script {
                    withCredentials([string(credentialsId: 'github-token', variable: 'GITHUB_TOKEN')]) {
                        sh '''
                            # Создаем тег
                            git tag ${RELEASE_TAG}
                            
                            # Создаем релиз через GitHub API
                            curl -X POST \
                                -H "Authorization: token ${GITHUB_TOKEN}" \
                                -H "Accept: application/vnd.github.v3+json" \
                                https://api.github.com/repos/astrekoi/lesta-exam/releases \
                                -d \'{
                                    "tag_name": "'"${RELEASE_TAG}"'",
                                    "target_commitish": "'"${BRANCH_NAME}"'",
                                    "name": "Release '"${RELEASE_TAG}"'",
                                    "body": "Автоматический релиз через Jenkins Pipeline\\n\\nCommit: '"${GIT_COMMIT_SHORT}"'\\nBranch: '"${BRANCH_NAME}"'\\nDocker Image: '"${DOCKER_IMAGE_FULL}"'\\n\\nChanges:\\n'"${GIT_COMMIT_MSG}"'",
                                    "draft": false,
                                    "prerelease": false
                                }\'
                            
                            echo "✅ GitHub release ${RELEASE_TAG} created!"
                        '''
                    }
                }
            }
        }
    }
    
    post {
        always {
            echo '🧹 Cleaning up...'
            sh '''
                docker image prune -f || true
                docker system prune -f || true
                rm -f .env.production || true
            '''
            archiveArtifacts artifacts: '*.log,version.txt', allowEmptyArchive: true
        }
        
        success {
            echo '✅ Pipeline completed successfully!'
            script {
                if (env.BRANCH_NAME == 'main' || env.BRANCH_NAME == 'master') {
                    echo "🚀 Production deployment successful!"
                    echo "🏷️ Release: ${env.RELEASE_TAG}"
                    echo "🐳 Docker Image: ${env.DOCKER_IMAGE_FULL}"
                } else {
                    echo "🚀 Branch ${env.BRANCH_NAME} deployment successful!"
                    echo "📦 Version: ${env.AUTO_VERSION}"
                }
            }
        }
        
        failure {
            echo '❌ Pipeline failed!'
            script {
                currentBuild.result = 'FAILURE'
                echo "💥 Build failed at stage: ${env.STAGE_NAME}"
                echo "💥 Failed release: ${env.RELEASE_TAG}"
            }
        }
        
        unstable {
            echo '⚠️ Pipeline unstable!'
        }
    }
}
