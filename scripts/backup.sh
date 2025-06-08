#!/bin/bash
echo "💾 Создание backup базы данных..."
BACKUP_FILE="backup_$(date +%Y%m%d_%H%M%S).sql"
docker compose exec db pg_dump -U postgres -d db > "$BACKUP_FILE"
echo "✅ Backup создан: $BACKUP_FILE"
