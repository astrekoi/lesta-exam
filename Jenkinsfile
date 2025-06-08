pipeline {
    agent any
    
    environment {
        DOCKER_COMPOSE_FILE = 'docker-compose.yml'
        DOCKER_REGISTRY_CREDS = credentials('docker-registry')
        PROD_SERVER_USER = credentials('prod-server-user')
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
                }
                echo "📋 Branch: ${env.BRANCH_NAME}"
                echo "📋 Commit: ${env.GIT_COMMIT_SHORT}"
                echo "📋 Message: ${env.GIT_COMMIT_MSG}"
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
                    env.DOCKER_IMAGE_TAG = "${env.GIT_BRANCH_CLEAN}-${BUILD_NUMBER}"
                    env.DOCKER_IMAGE_FULL = "${env.DOCKER_IMAGE_NAME}:${env.DOCKER_IMAGE_TAG}"
                    
                    def image = docker.build("${env.DOCKER_IMAGE_FULL}")
                    sh "docker tag ${env.DOCKER_IMAGE_FULL} ${env.DOCKER_IMAGE_NAME}:latest"
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
                                -d '{"name": "Jenkins Test Branch ${BRANCH_NAME}", "score": 95}'
                            
                            curl -f http://localhost:5001/results
                            
                            echo "✅ All tests passed for branch ${BRANCH_NAME}!"
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
                        
                        echo "📤 Pushing branch-specific image..."
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
        
        stage('Generate SSL Certificates') {
            when {
                anyOf {
                    branch 'main'
                    branch 'master'
                    branch 'develop'
                    branch 'staging'
                }
            }
            steps {
                echo '🔐 Generating SSL certificates for deployment...'
                script {
                    withCredentials([string(credentialsId: 'prod-server-ssh', variable: 'SSH_HOST')]) {
                        sh '''
                            echo "🔐 Generating SSL certificates before deployment..."
                            chmod +x scripts/generate-ssl.sh
                            bash scripts/generate-ssl.sh
                            echo "✅ SSL certificates generated"
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
                echo "🚀 Deploying branch ${env.BRANCH_NAME} to production server..."
                script {
                    withCredentials([
                        string(credentialsId: 'prod-server-ssh', variable: 'SSH_HOST'),
                        string(credentialsId: 'prod-server-user', variable: 'SSH_USER'),
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
                            
                            echo "🚀 Deploying to: ${SSH_USER}@${SSH_HOST}:${TARGET_PATH}"
                            
                            # Создание директории на удаленном сервере
                            ssh -i $SSH_KEY -o StrictHostKeyChecking=no ${SSH_USER}@${SSH_HOST} \
                                "mkdir -p ${TARGET_PATH}"
                            
                            # Копирование файлов
                            scp -i $SSH_KEY -o StrictHostKeyChecking=no \
                                $DOCKER_COMPOSE_FILE ${SSH_USER}@${SSH_HOST}:${TARGET_PATH}/
                            
                            scp -i $SSH_KEY -o StrictHostKeyChecking=no \
                                .env.production ${SSH_USER}@${SSH_HOST}:${TARGET_PATH}/.env
                            
                            # Копирование SSL сертификатов
                            scp -i $SSH_KEY -o StrictHostKeyChecking=no -r \
                                nginx/ssl/ ${SSH_USER}@${SSH_HOST}:${TARGET_PATH}/nginx/
                            
                            # Развертывание
                            ssh -i $SSH_KEY -o StrictHostKeyChecking=no ${SSH_USER}@${SSH_HOST} << EOF
                                cd ${TARGET_PATH}
                                
                                # Установка переменных окружения
                                export DOCKER_IMAGE=${DOCKER_IMAGE_FULL}
                                export BRANCH_NAME=${BRANCH_NAME}
                                
                                echo "🛑 Stopping old version..."
                                docker-compose down || true
                                
                                echo "📥 Pulling new image..."
                                docker pull ${DOCKER_IMAGE_FULL}
                                
                                echo "🚀 Starting new version..."
                                docker-compose up -d
                                
                                echo "⏳ Waiting for services to start..."
                                sleep 30
                                
                                echo "📊 Checking service status..."
                                docker-compose ps
                                
                                echo "🏥 Health check..."
                                curl -f http://localhost/ping || curl -f http://localhost:8080/ping || exit 1
                                
                                echo "✅ Deployment successful for branch ${BRANCH_NAME}!"
                                echo "🌐 Application deployed at: ${TARGET_PATH}"
EOF
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
            archiveArtifacts artifacts: '*.log', allowEmptyArchive: true
        }
        
        success {
            echo '✅ Pipeline completed successfully!'
            script {
                if (env.BRANCH_NAME == 'main' || env.BRANCH_NAME == 'master') {
                    echo "🚀 Production deployment successful!"
                } else {
                    echo "🚀 Branch ${env.BRANCH_NAME} deployment successful!"
                }
            }
        }
        
        failure {
            echo '❌ Pipeline failed!'
            script {
                currentBuild.result = 'FAILURE'
                echo "💥 Build failed at stage: ${env.STAGE_NAME}"
                echo "💥 Failed branch: ${env.BRANCH_NAME}"
            }
        }
        
        unstable {
            echo '⚠️ Pipeline unstable!'
        }
    }
}
