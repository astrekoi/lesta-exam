#!/bin/bash
set -e

NGINX_PORT=${1:-8080}
API_PORT=${2:-5000}
POSTGRES_PORT=${3:-5432}

echo "🔧 Запуск development окружения..."
echo "📋 Параметры:"
echo "  - NGINX_PORT: $NGINX_PORT"
echo "  - API_PORT: $API_PORT"
echo "  - POSTGRES_PORT: $POSTGRES_PORT"

echo "📁 Создание директорий..."
mkdir -p volumes/{db/data,jenkins/home,nginx/logs,app/logs}

echo "🔐 Настройка прав..."
sudo chown -R 1000:1000 volumes/jenkins/ 2>/dev/null || true
chmod -R 755 volumes/ 2>/dev/null || true

echo "📊 Запуск PostgreSQL на порту $POSTGRES_PORT..."
export POSTGRES_PORT=$POSTGRES_PORT
docker compose up -d db

echo "✅ PostgreSQL запущен на localhost:$POSTGRES_PORT"
echo "📝 Для запуска Flask:"
echo "  source .venv/bin/activate"
echo "  export POSTGRES_HOST=localhost"
echo "  export POSTGRES_PORT=$POSTGRES_PORT"
echo "  export API_PORT=$API_PORT"
echo "  cd app && python app.py"
echo "📋 API будет доступно на: http://localhost:$API_PORT"
