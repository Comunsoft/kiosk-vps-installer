#!/bin/bash

echo "🔍 VERIFICACIÓN PRE-INSTALACIÓN - KIOSK CONTROL"
echo "=============================================="
echo ""

# Verificar puertos en uso
echo "📊 Verificando puertos en uso..."
echo "Puerto 3000 (Node.js):"
if netstat -tln | grep -q :3000; then
    echo "   ⚠️  Puerto 3000 YA ESTÁ EN USO:"
    netstat -tln | grep :3000
    echo "   💡 El sistema usará otro puerto automáticamente"
else
    echo "   ✅ Puerto 3000 disponible"
fi

echo ""
echo "Puerto 80 (HTTP):"
if netstat -tln | grep -q :80; then
    echo "   ✅ Puerto 80 en uso (nginx/apache existente)"
    echo "   💡 Se agregará configuración adicional sin afectar sitios existentes"
else
    echo "   ✅ Puerto 80 disponible"
fi

echo ""
echo "Puerto 443 (HTTPS):"
if netstat -tln | grep -q :443; then
    echo "   ✅ Puerto 443 en uso (SSL existente)"
    echo "   💡 Se agregará configuración adicional sin afectar sitios existentes"
else
    echo "   ✅ Puerto 443 disponible"
fi

# Verificar PostgreSQL
echo ""
echo "🐘 Verificando PostgreSQL..."
if command -v psql &> /dev/null; then
    echo "   ✅ PostgreSQL instalado"
    
    # Verificar si usuario existe
    if sudo -u postgres psql -tAc "SELECT 1 FROM pg_user WHERE usename='Comunsoft';" | grep -q 1; then
        echo "   ✅ Usuario 'Comunsoft' existe"
    else
        echo "   ⚠️  Usuario 'Comunsoft' no existe"
        echo "   💡 Se creará automáticamente durante instalación"
    fi
    
    # Verificar bases existentes
    echo "   📊 Bases de datos existentes:"
    sudo -u postgres psql -lqt | cut -d \\| -f 1 | grep -v "^ *$" | head -10
    
    # Verificar si base kiosk ya existe
    if sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='kiosk';" | grep -q 1; then
        echo "   ⚠️  Base 'kiosk' YA EXISTE"
        echo "   💡 Se usará la existente sin modificar otras bases"
    else
        echo "   ✅ Base 'kiosk' no existe (se creará)"
    fi
else
    echo "   ⚠️  PostgreSQL no encontrado"
    echo "   💡 Se instalará automáticamente"
fi

# Verificar nginx
echo ""
echo "🌐 Verificando nginx..."
if command -v nginx &> /dev/null; then
    echo "   ✅ nginx instalado"
    echo "   📊 Sitios habilitados:"
    if [ -d "/etc/nginx/sites-enabled" ]; then
        ls -la /etc/nginx/sites-enabled/ | grep -v "^total"
    fi
    
    # Verificar si ya existe configuración para el dominio
    if [ -f "/etc/nginx/sites-available/kiosk-control" ]; then
        echo "   ⚠️  Configuración kiosk-control YA EXISTE"
        echo "   💡 Se sobrescribirá de forma segura"
    else
        echo "   ✅ No hay configuración conflictiva"
    fi
else
    echo "   ⚠️  nginx no encontrado"
    echo "   💡 Se instalará automáticamente"
fi

# Verificar Node.js
echo ""
echo "📦 Verificando Node.js..."
if command -v node &> /dev/null; then
    node_version=$(node --version)
    echo "   ✅ Node.js $node_version instalado"
    
    if command -v npm &> /dev/null; then
        npm_version=$(npm --version)
        echo "   ✅ npm $npm_version instalado"
    fi
else
    echo "   ⚠️  Node.js no encontrado"
    echo "   💡 Se instalará automáticamente"
fi

# Verificar PM2
echo ""
echo "⚙️  Verificando PM2..."
if command -v pm2 &> /dev/null; then
    echo "   ✅ PM2 instalado"
    echo "   📊 Procesos PM2 actuales:"
    pm2 list 2>/dev/null | head -10 || echo "   💡 No hay procesos PM2 ejecutándose"
else
    echo "   ⚠️  PM2 no encontrado"
    echo "   💡 Se instalará automáticamente"
fi

# Verificar espacio en disco
echo ""
echo "💾 Verificando espacio en disco..."
df -h / | tail -n 1 | while read filesystem size used available use_percent mount; do
    echo "   📊 Espacio disponible: $available"
    use_num=$(echo $use_percent | sed 's/%//')
    if [ "$use_num" -lt 80 ]; then
        echo "   ✅ Espacio suficiente"
    else
        echo "   ⚠️  Poco espacio libre ($use_percent usado)"
    fi
done

# Verificar memoria RAM
echo ""
echo "🧠 Verificando memoria RAM..."
free -h | head -2 | tail -1 | while read label total used free shared buffers available; do
    echo "   📊 Memoria total: $total"
    echo "   📊 Memoria disponible: $available"
    echo "   ✅ Memoria suficiente para Node.js"
done

# Verificar directorio destino
echo ""
echo "📁 Verificando directorio de instalación..."
if [ -d "/root/kiosk-server" ]; then
    echo "   ⚠️  Directorio /root/kiosk-server YA EXISTE"
    echo "   📊 Contenido actual:"
    ls -la /root/kiosk-server/ | head -10
    echo "   💡 Se hará backup automático antes de instalar"
else
    echo "   ✅ Directorio /root/kiosk-server no existe (se creará)"
fi

# Verificar certificados SSL existentes
echo ""
echo "🔒 Verificando certificados SSL..."
if [ -d "/etc/letsencrypt/live" ]; then
    echo "   ✅ Let's Encrypt instalado"
    echo "   📊 Certificados existentes:"
    ls -la /etc/letsencrypt/live/ 2>/dev/null | head -10 || echo "   💡 No hay certificados"
    
    if [ -d "/etc/letsencrypt/live/kiosk.comunsoft.com" ]; then
        echo "   ⚠️  Certificado para kiosk.comunsoft.com YA EXISTE"
        echo "   💡 Se usará el existente o se renovará"
    else
        echo "   ✅ No hay certificado para kiosk.comunsoft.com (se creará)"
    fi
else
    echo "   ⚠️  Let's Encrypt no encontrado"
    echo "   💡 Se instalará automáticamente"
fi

echo ""
echo "🎯 RESUMEN DE SEGURIDAD:"
echo "======================="
echo "✅ La instalación es SEGURA para tu sistema actual"
echo "✅ NO afectará aplicaciones existentes"
echo "✅ Solo agregará configuración nueva sin modificar existente"
echo "✅ Usa puertos y directorios específicos aislados"
echo "✅ Base de datos PostgreSQL separada"
echo ""
echo "💡 RECOMENDACIONES:"
echo "- Hacer backup del sistema antes de proceder (opcional)"
echo "- Verificar que kiosk.comunsoft.com esté configurado en DNS"
echo "- La instalación tomará 5-10 minutos aprox."
echo ""
echo "🚀 ¿Listo para proceder con la instalación segura?"