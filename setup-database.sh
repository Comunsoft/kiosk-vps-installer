#!/bin/bash

echo "🗄️  CONFIGURANDO BASE DE DATOS POSTGRESQL PARA KIOSK"
echo "==============================================="

# Datos de conexión
DB_NAME="kiosk"
DB_USER="Comunsoft"
DB_PASSWORD="Cornershop1!"
DB_HOST="localhost"
DB_PORT="5432"

# Verificar si PostgreSQL está ejecutándose
echo "🔍 Verificando estado de PostgreSQL..."
if ! systemctl is-active --quiet postgresql; then
    echo "⚠️  PostgreSQL no está ejecutándose. Iniciando..."
    systemctl start postgresql
    systemctl enable postgresql
fi

# Verificar si la base de datos existe
echo "🔍 Verificando si la base de datos '$DB_NAME' existe..."
DB_EXISTS=$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME';")

if [ "$DB_EXISTS" = "1" ]; then
    echo "✅ La base de datos '$DB_NAME' ya existe"
else
    echo "📦 Creando base de datos '$DB_NAME'..."
    
    # Crear la base de datos
    sudo -u postgres createdb -O "$DB_USER" "$DB_NAME"
    
    if [ $? -eq 0 ]; then
        echo "✅ Base de datos '$DB_NAME' creada exitosamente"
    else
        echo "❌ Error creando base de datos. Intentando método alternativo..."
        sudo -u postgres psql -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;"
    fi
fi

# Verificar si el usuario existe
echo "🔍 Verificando usuario PostgreSQL..."
USER_EXISTS=$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_user WHERE usename='$DB_USER';")
if [ "$USER_EXISTS" != "1" ]; then
    echo "💡 Creando usuario '$DB_USER'..."
    sudo -u postgres psql -c "CREATE USER \"$DB_USER\" WITH PASSWORD '$DB_PASSWORD';"
    sudo -u postgres psql -c "ALTER USER \"$DB_USER\" CREATEDB;"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO \"$DB_USER\";"
fi

# Verificar conexión con las credenciales del proyecto
echo "🔗 Verificando conexión con credenciales del proyecto..."
export PGPASSWORD="$DB_PASSWORD"

# Intentar conectar
if psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT version();" > /dev/null 2>&1; then
    echo "✅ Conexión exitosa a PostgreSQL"
    echo "   Base: $DB_NAME"
    echo "   Usuario: $DB_USER"
    echo "   Host: $DB_HOST:$DB_PORT"
else
    echo "❌ Error de conexión. Verificando configuración..."
    
    # Mostrar información de debugging
    echo "🔍 Información de debugging:"
    echo "   PostgreSQL status: $(systemctl is-active postgresql)"
    echo "   Puerto en uso: $(netstat -tln | grep :$DB_PORT || echo 'No encontrado')"
fi

echo ""
echo "✅ CONFIGURACIÓN DE BASE DE DATOS COMPLETADA"
echo "============================================"
echo "📊 Base de datos: $DB_NAME"
echo "👤 Usuario: $DB_USER" 
echo "🏠 Host: $DB_HOST:$DB_PORT"
echo "🔗 URL conexión: postgresql://$DB_USER:****@$DB_HOST:$DB_PORT/$DB_NAME"
echo ""
echo "📝 Las tablas se crearán automáticamente al iniciar el servidor Node.js"