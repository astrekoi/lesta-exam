#!/bin/bash

NGINX_PORT=${1:-8080}
JENKINS_PORT=${2:-9090}
API_PORT=${3:-5000}

echo "🔐 Генерация SSL сертификатов для экзаменационного проекта..."
echo "📋 Параметры:"
echo "  - NGINX_PORT: $NGINX_PORT"
echo "  - JENKINS_PORT: $JENKINS_PORT"
echo "  - API_PORT: $API_PORT"

mkdir -p ./nginx/ssl

cat > ./nginx/ssl/astrekoi.conf << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = RU
ST = Moscow
L = Moscow
O = Astrekoi Development
OU = IT Department
CN = astrekoi.ru

[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = astrekoi.ru
DNS.2 = www.astrekoi.ru
DNS.3 = jenkins.astrekoi.ru
DNS.4 = api.astrekoi.ru
DNS.5 = *.astrekoi.ru
DNS.6 = localhost
IP.1 = 127.0.0.1
IP.2 = ::1
EOF

echo "🗑️ Удаление старых сертификатов..."
rm -f ./nginx/ssl/astrekoi.key ./nginx/ssl/astrekoi.crt ./nginx/ssl/dhparam.pem

echo "🔑 Генерация приватного ключа..."
if openssl genrsa -out ./nginx/ssl/astrekoi.key 2048; then
    echo "✅ Приватный ключ создан успешно"
else
    echo "❌ Ошибка создания приватного ключа"
    exit 1
fi

echo "📄 Генерация сертификата..."
if openssl req -new -x509 -key ./nginx/ssl/astrekoi.key -out ./nginx/ssl/astrekoi.crt -days 365 -config ./nginx/ssl/astrekoi.conf -extensions v3_req; then
    echo "✅ Сертификат создан успешно"
else
    echo "❌ Ошибка создания сертификата"
    echo "🔍 Проверяем конфигурацию..."
    openssl req -new -x509 -key ./nginx/ssl/astrekoi.key -out ./nginx/ssl/astrekoi.crt -days 365 -config ./nginx/ssl/astrekoi.conf -extensions v3_req -verbose
    exit 1
fi

echo "🔐 Генерация DH параметров..."
if openssl dhparam -out ./nginx/ssl/dhparam.pem 2048; then
    echo "✅ DH параметры созданы успешно"
else
    echo "❌ Ошибка создания DH параметров"
    exit 1
fi

echo "🔍 Проверка созданных файлов..."
for file in astrekoi.key astrekoi.crt dhparam.pem; do
    if [ -f "./nginx/ssl/$file" ]; then
        echo "✅ $file создан"
    else
        echo "❌ $file НЕ создан"
        exit 1
    fi
done

echo "🔐 Установка прав доступа..."
chmod 600 ./nginx/ssl/astrekoi.key
chmod 644 ./nginx/ssl/astrekoi.crt
chmod 644 ./nginx/ssl/dhparam.pem

echo "✅ SSL сертификаты созданы в ./nginx/ssl/"
echo "📄 Сертификат: astrekoi.crt"
echo "🔑 Ключ: astrekoi.key"
echo "🔐 DH параметры: dhparam.pem"

echo "🔍 Проверка сертификата:"
if [ -f "./nginx/ssl/astrekoi.crt" ]; then
    echo "📋 Информация о сертификате:"
    openssl x509 -in ./nginx/ssl/astrekoi.crt -text -noout | grep -A10 "Subject Alternative Name" || echo "⚠️ SAN не найден"
    
    echo "📅 Срок действия:"
    openssl x509 -in ./nginx/ssl/astrekoi.crt -noout -dates
    
    echo "🏷️ Subject:"
    openssl x509 -in ./nginx/ssl/astrekoi.crt -noout -subject
else
    echo "❌ Файл сертификата не найден"
    exit 1
fi

echo "📊 Финальная проверка:"
ls -la ./nginx/ssl/

echo "🌐 HTTPS будет доступен на порту $NGINX_PORT"
echo "✅ SSL генерация завершена успешно!"
