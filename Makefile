.PHONY: run dev init-db migrate upgrade downgrade shell clean

# Production запуск с автоматическим применением миграций
run:
	@echo "🚀 Starting Flask application in production mode..."
	@export FLASK_APP=app && \
	 flask db upgrade && \
	 gunicorn --bind 0.0.0.0:5000 --workers 4 --timeout 120 "app:create_app()"

# Development запуск
dev:
	@echo "🔧 Starting Flask application in development mode..."
	@export FLASK_APP=app && \
	 export FLASK_ENV=development && \
	 flask db upgrade && \
	 flask run --host=0.0.0.0 --port=5000

# Инициализация миграций (только первый раз)
init-db:
	@echo "📊 Initializing database migrations..."
	@export FLASK_APP=app && flask db init

# Создание новой миграции
migrate:
	@echo "📝 Creating new migration..."
	@export FLASK_APP=app && flask db migrate -m "$(if $(msg),$(msg),Auto-generated migration)"

# Применение миграций
upgrade:
	@echo "⬆️ Applying database migrations..."
	@export FLASK_APP=app && flask db upgrade

# Откат миграций
downgrade:
	@echo "⬇️ Rolling back database migrations..."
	@export FLASK_APP=app && flask db downgrade

# Показать текущий статус миграций
status:
	@echo "📋 Current migration status..."
	@export FLASK_APP=app && flask db current

# Flask shell для отладки
shell:
	@export FLASK_APP=app && flask shell

# Очистка
clean:
	@echo "🧹 Cleaning up..."
	@find . -type d -name "__pycache__" -exec rm -rf {} +
	@find . -type f -name "*.pyc" -delete
