#!/bin/bash

NGINX_PORT=${1:-8080}
API_PORT=${2:-5000}

echo "🧪 Тестирование API согласно экзаменационному заданию..."
echo "📋 Тестируемые порты: NGINX=$NGINX_PORT, API=$API_PORT"

test_endpoint() {
    local url=$1
    local name=$2
    echo "📝 Тест $name: $url"
    if curl -f "$url" 2>/dev/null; then
        echo "✅ $name работает"
        return 0
    else
        echo "❌ $name недоступен"
        return 1
    fi
}

test_endpoint "http://localhost:$API_PORT/ping" "Flask API (прямой)" || \
test_endpoint "http://localhost:$NGINX_PORT/ping" "Flask API (через nginx)"

echo "📝 Тест /submit"
curl -X POST "http://localhost:$API_PORT/submit" \
  -H "Content-Type: application/json" \
  -d '{"name": "Kirill", "score": 88}' 2>/dev/null || \
curl -X POST "http://localhost:$NGINX_PORT/submit" \
  -H "Content-Type: application/json" \
  -d '{"name": "Artem", "score": 88}' 2>/dev/null

test_endpoint "http://localhost:$API_PORT/results" "Results API (прямой)" || \
test_endpoint "http://localhost:$NGINX_PORT/results" "Results API (через nginx)"

echo "✅ Тестирование завершено"
