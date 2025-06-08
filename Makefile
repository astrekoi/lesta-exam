.PHONY: help dev prod stop clean logs test setup generate-ssl

GREEN = \033[0;32m
YELLOW = \033[1;33m
RED = \033[0;31m
NC = \033[0m

SCRIPTS_DIR = scripts

-include .env

NGINX_PORT ?= $(shell test -f .env && grep -E '^NGINX_PORT=' .env 2>/dev/null | cut -d '=' -f2 | tr -d '\r\n' || echo '8080')
JENKINS_PORT ?= $(shell test -f .env && grep -E '^JENKINS_PORT=' .env 2>/dev/null | cut -d '=' -f2 | tr -d '\r\n' || echo '9090')
API_PORT ?= $(shell test -f .env && grep -E '^API_PORT=' .env 2>/dev/null | cut -d '=' -f2 | tr -d '\r\n' || echo '5000')
POSTGRES_PORT ?= $(shell test -f .env && grep -E '^POSTGRES_PORT=' .env 2>/dev/null | cut -d '=' -f2 | tr -d '\r\n' || echo '5432')

help: ## Показать все доступные команды
	@echo "$(GREEN)Экзаменационный проект Flask API + PostgreSQL + Jenkins$(NC)"
	@echo "$(YELLOW)Доступные команды:$(NC)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)

chmod-scripts: ## Установить права +x на все скрипты в папке scripts
	@echo "$(YELLOW)🔐 Установка прав +x на скрипты...$(NC)"
	@if [ -d scripts ]; then \
		chmod +x scripts/*.sh 2>/dev/null || echo "$(YELLOW)⚠️  Нет .sh файлов в scripts/$(NC)"; \
		echo "$(GREEN)✅ Права установлены$(NC)"; \
	else \
		echo "$(RED)❌ Папка scripts не существует$(NC)"; \
	fi

generate-ssl: ## Генерировать SSL сертификаты для nginx
	@echo "$(GREEN)🔐 Генерация SSL сертификатов...$(NC)"
	@if [ -f scripts/generate-ssl.sh ]; then \
		chmod +x scripts/generate-ssl.sh; \
		bash scripts/generate-ssl.sh; \
		echo "$(GREEN)✅ SSL сертификаты созданы$(NC)"; \
	else \
		echo "$(RED)❌ Скрипт scripts/generate-ssl.sh не найден$(NC)"; \
		exit 1; \
	fi

dev: chmod-scripts ## Запустить development окружение
	@echo "$(GREEN)🔧 Запуск development...$(NC)"
	@echo "$(YELLOW)📋 Используемые порты: NGINX=$(NGINX_PORT), API=$(API_PORT), POSTGRES=$(POSTGRES_PORT)$(NC)"
	@if [ -f $(SCRIPTS_DIR)/dev.sh ]; then \
		bash $(SCRIPTS_DIR)/dev.sh $(NGINX_PORT) $(API_PORT) $(POSTGRES_PORT); \
	else \
		echo "$(RED)❌ Скрипт $(SCRIPTS_DIR)/dev.sh не найден$(NC)"; \
		exit 1; \
	fi

prod: chmod-scripts generate-ssl ## Запустить production окружение с SSL
	@echo "$(GREEN)🚀 Запуск production...$(NC)"
	@echo "$(YELLOW)📋 Используемые порты: NGINX=$(NGINX_PORT), JENKINS=$(JENKINS_PORT), API=$(API_PORT)$(NC)"
	@if [ -f $(SCRIPTS_DIR)/prod.sh ]; then \
		bash $(SCRIPTS_DIR)/prod.sh $(NGINX_PORT) $(JENKINS_PORT) $(API_PORT) $(POSTGRES_PORT); \
	else \
		echo "$(RED)❌ Скрипт $(SCRIPTS_DIR)/prod.sh не найден$(NC)"; \
		exit 1; \
	fi

stop: ## Остановить все сервисы
	@echo "$(YELLOW)🛑 Остановка сервисов...$(NC)"
	@if [ -f $(SCRIPTS_DIR)/stop.sh ]; then \
		bash $(SCRIPTS_DIR)/stop.sh; \
	else \
		echo "$(RED)❌ Скрипт $(SCRIPTS_DIR)/stop.sh не найден$(NC)"; \
	fi

clean: ## Полная очистка
	@echo "$(RED)🧹 Очистка...$(NC)"
	@if [ -f $(SCRIPTS_DIR)/clean.sh ]; then \
		bash $(SCRIPTS_DIR)/clean.sh; \
	else \
		echo "$(RED)❌ Скрипт $(SCRIPTS_DIR)/clean.sh не найден$(NC)"; \
	fi

logs: ## Показать логи
	@if [ -f $(SCRIPTS_DIR)/logs.sh ]; then \
		bash $(SCRIPTS_DIR)/logs.sh; \
	else \
		echo "$(RED)❌ Скрипт $(SCRIPTS_DIR)/logs.sh не найден$(NC)"; \
	fi

test: chmod-scripts ## Тестировать API
	@echo "$(GREEN)🧪 Тестирование...$(NC)"
	@if [ -f $(SCRIPTS_DIR)/test.sh ]; then \
		bash $(SCRIPTS_DIR)/test.sh $(NGINX_PORT) $(API_PORT); \
	else \
		echo "$(RED)❌ Скрипт $(SCRIPTS_DIR)/test.sh не найден$(NC)"; \
		exit 1; \
	fi

setup: chmod-scripts ## Настройка проекта
	@echo "$(GREEN)🔧 Настройка проекта...$(NC)"
	@if [ -f $(SCRIPTS_DIR)/setup.sh ]; then \
		bash $(SCRIPTS_DIR)/setup.sh; \
	else \
		echo "$(RED)❌ Скрипт $(SCRIPTS_DIR)/setup.sh не найден$(NC)"; \
		exit 1; \
	fi

build: ## Собрать образы
	@echo "$(GREEN)🔨 Сборка...$(NC)"
	@if [ -f $(SCRIPTS_DIR)/build.sh ]; then \
		bash $(SCRIPTS_DIR)/build.sh; \
	else \
		echo "$(RED)❌ Скрипт $(SCRIPTS_DIR)/build.sh не найден$(NC)"; \
	fi

status: ## Статус сервисов
	@if [ -f $(SCRIPTS_DIR)/status.sh ]; then \
		bash $(SCRIPTS_DIR)/status.sh $(NGINX_PORT) $(API_PORT) $(POSTGRES_PORT); \
	else \
		echo "$(RED)❌ Скрипт $(SCRIPTS_DIR)/status.sh не найден$(NC)"; \
	fi

backup: ## Backup базы данных
	@if [ -f $(SCRIPTS_DIR)/backup.sh ]; then \
		bash $(SCRIPTS_DIR)/backup.sh; \
	else \
		echo "$(RED)❌ Скрипт $(SCRIPTS_DIR)/backup.sh не найден$(NC)"; \
	fi

show-env: ## Показать переменные из .env
	@echo "$(GREEN)📋 Переменные окружения из .env:$(NC)"
	@echo "  NGINX_PORT: $(NGINX_PORT)"
	@echo "  JENKINS_PORT: $(JENKINS_PORT)"
	@echo "  API_PORT: $(API_PORT)"
	@echo "  POSTGRES_PORT: $(POSTGRES_PORT)"

ssl-info: ## Показать информацию о SSL сертификатах
	@echo "$(GREEN)🔐 Информация о SSL сертификатах:$(NC)"
	@if [ -f nginx/ssl/astrekoi.crt ]; then \
		echo "$(YELLOW)Сертификат найден:$(NC)"; \
		openssl x509 -in nginx/ssl/astrekoi.crt -text -noout | grep -A1 "Subject:"; \
		openssl x509 -in nginx/ssl/astrekoi.crt -text -noout | grep -A1 "Not After"; \
		openssl x509 -in nginx/ssl/astrekoi.crt -text -noout | grep -A3 "Subject Alternative Name"; \
	else \
		echo "$(RED)❌ SSL сертификат не найден. Выполните: make generate-ssl$(NC)"; \
	fi

ssl-clean: ## Удалить SSL сертификаты
	@echo "$(YELLOW)🗑️ Удаление SSL сертификатов...$(NC)"
	@rm -rf nginx/ssl/
	@echo "$(GREEN)✅ SSL сертификаты удалены$(NC)"

%: chmod-scripts
	@# Исключаем системные файлы из обработки
	@if echo "$@" | grep -E "^\.|Makefile|\.env|\.git" >/dev/null; then \
		echo "$(YELLOW)⚠️  Игнорируем системный файл: $@$(NC)"; \
	elif [ -f $(SCRIPTS_DIR)/$@.sh ]; then \
		echo "$(GREEN)🔧 Выполнение $@ с переменными...$(NC)"; \
		bash $(SCRIPTS_DIR)/$@.sh $(NGINX_PORT) $(API_PORT) $(POSTGRES_PORT) $(JENKINS_PORT); \
	else \
		echo "$(RED)❌ Скрипт $(SCRIPTS_DIR)/$@.sh не найден$(NC)"; \
		echo "$(YELLOW)💡 Доступные команды: make help$(NC)"; \
		exit 1; \
	fi
