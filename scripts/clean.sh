#!/bin/bash
echo "🧹 Полная очистка проекта..."
docker compose down -v --remove-orphans
docker system prune -f
sudo rm -rf volumes/ 2>/dev/null || rm -rf volumes/ 2>/dev/null || true
echo "✅ Очистка завершена"
