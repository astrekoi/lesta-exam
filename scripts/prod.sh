#!/bin/bash
set -e

NGINX_PORT=${1:-8080}
JENKINS_PORT=${2:-9090}
API_PORT=${3:-5000}
POSTGRES_PORT=${4:-5432}

echo "🚀 Запуск production окружения..."
echo "📋 Параметры:"
echo "  - NGINX_PORT: $NGINX_PORT"
echo "  - JENKINS_PORT: $JENKINS_PORT"
echo "  - API_PORT: $API_PORT"
echo "  - POSTGRES_PORT: $POSTGRES_PORT"

echo "📁 Создание директорий..."
mkdir -p volumes/{db/data,jenkins/home,nginx/logs,app/logs}
sudo chown -R 1000:1000 volumes/jenkins/ 2>/dev/null || true

echo "🔨 Сборка образов..."
export NGINX_PORT=$NGINX_PORT
export JENKINS_PORT=$JENKINS_PORT
export API_PORT=$API_PORT
export POSTGRES_PORT=$POSTGRES_PORT
docker compose build --no-cache

echo "📊 Запуск всех сервисов..."
docker compose up -d

echo "✅ Production запущен:"
echo "  Flask API:  http://localhost:$NGINX_PORT"
echo "  Jenkins:    http://localhost:$NGINX_PORT/jenkins"  
echo "  PostgreSQL: localhost:$POSTGRES_PORT"
echo "  Прямой API: http://localhost:$API_PORT"
