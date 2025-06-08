#!/bin/bash

# ДОБАВЛЕНО: Принятие параметров
NGINX_PORT=${1:-8080}
API_PORT=${2:-5000}
POSTGRES_PORT=${3:-5432}

echo "📊 Статус сервисов:"
docker compose ps
echo ""
echo "🏥 Проверка здоровья с учетом портов:"
echo "📋 Используемые порты: NGINX=$NGINX_PORT, API=$API_PORT, POSTGRES=$POSTGRES_PORT"

docker compose exec db pg_isready -U postgres -p $POSTGRES_PORT 2>/dev/null && echo "✅ PostgreSQL (порт $POSTGRES_PORT)" || echo "❌ PostgreSQL (порт $POSTGRES_PORT)"
curl -f "http://localhost:$API_PORT/ping" 2>/dev/null && echo "✅ Flask API прямой (порт $API_PORT)" || echo "❌ Flask API прямой (порт $API_PORT)"
curl -f "http://localhost:$NGINX_PORT/ping" 2>/dev/null && echo "✅ Flask API через nginx (порт $NGINX_PORT)" || echo "❌ Flask API через nginx (порт $NGINX_PORT)"
curl -f "http://localhost:$NGINX_PORT/jenkins/login" 2>/dev/null && echo "✅ Jenkins (порт $NGINX_PORT)" || echo "❌ Jenkins (порт $NGINX_PORT)"
