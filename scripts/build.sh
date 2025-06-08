#!/bin/bash
echo "🔨 Сборка Docker образов..."
docker compose build --no-cache
echo "✅ Сборка завершена"
