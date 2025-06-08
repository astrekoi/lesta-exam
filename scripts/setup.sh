#!/bin/bash
set -e

echo "🔧 Настройка проекта для экзаменационного задания..."

echo "📦 Создание виртуального окружения..."
python3 -m venv .venv

echo "📦 Установка зависимостей..."
.venv/bin/pip install --upgrade pip
.venv/bin/pip install -r requirements.txt

echo "📁 Создание директорий..."
mkdir -p volumes/{db/data,jenkins/home,nginx/logs,app/logs}
sudo chown -R 1000:1000 volumes/jenkins/ 2>/dev/null || true
chmod -R 755 volumes/ 2>/dev/null || true

echo "✅ Настройка завершена"
echo "📋 Для активации: source .venv/bin/activate"
