#!/bin/bash

echo "🚀 INSTALANDO SERVIDOR KIOSK CONTROL CON POSTGRESQL"
echo "=================================================="
echo ""
echo "⚠️  INSTALACIÓN SEGURA - NO AFECTA APLICACIONES EXISTENTES"
echo ""

# Hacer backup si existe instalación previa
if [ -d "/root/kiosk-server" ]; then
    BACKUP_DIR="/root/kiosk-server-backup-$(date +%Y%m%d_%H%M%S)"
    echo "💾 Haciendo backup de instalación previa..."
    cp -r /root/kiosk-server "$BACKUP_DIR"
    echo "✅ Backup guardado en: $BACKUP_DIR"
fi

# Actualizar sistema
echo "📦 Actualizando paquetes del sistema..."
apt update && apt upgrade -y

# Verificar PostgreSQL existente
echo "🔍 Verificando PostgreSQL existente..."
if ! command -v psql &> /dev/null; then
    echo "❌ PostgreSQL no encontrado. Instalando..."
    apt install -y postgresql postgresql-contrib
else
    echo "✅ PostgreSQL ya está instalado"
fi

# Instalar Node.js
echo "📦 Instalando Node.js..."
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

# Verificar instalación
node_version=$(node --version)
npm_version=$(npm --version)
echo "✅ Node.js $node_version instalado"
echo "✅ npm $npm_version instalado"

# Configurar base de datos PostgreSQL
echo "🗄️  Configurando base de datos kiosk..."
chmod +x setup-database.sh
./setup-database.sh

# Detectar puerto disponible
echo "🔍 Detectando puerto disponible..."
PORT=3000
while netstat -tln | grep -q ":$PORT "; do
    PORT=$((PORT + 1))
    echo "   Puerto $((PORT - 1)) ocupado, probando $PORT..."
done
echo "✅ Puerto $PORT disponible"

# Instalar dependencias del proyecto
echo "📦 Instalando dependencias del proyecto..."
npm install

# Crear directorio para logs
mkdir -p logs

# Instalar PM2 para manejo de procesos
echo "📦 Instalando PM2..."
npm install -g pm2

# Crear archivo de configuración PM2
cat > ecosystem.config.js << EOF
module.exports = {
  apps: [{
    name: 'kiosk-control-server',
    script: 'server.js',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'production',
      PORT: $PORT,
      DOMAIN: 'kiosk.comunsoft.com',
      POSTGRES_HOST: 'localhost',
      POSTGRES_PORT: 5432,
      POSTGRES_DB: 'kiosk',
      POSTGRES_USER: 'Comunsoft',
      POSTGRES_PASSWORD: 'Cornershop1!'
    },
    error_file: 'logs/error.log',
    out_file: 'logs/output.log',
    log_file: 'logs/combined.log',
    time: true
  }]
};
EOF

# Configurar firewall
echo "🔥 Configurando firewall..."
ufw allow 22
ufw allow 80
ufw allow 443
ufw --force enable

# Configurar autostart
echo "⚙️ Configurando autostart..."
pm2 start ecosystem.config.js
pm2 save
pm2 startup

# Crear script de comandos útiles
cat > manage.sh << 'EOF'
#!/bin/bash

case "$1" in
    start)
        echo "▶️  Iniciando servidor..."
        pm2 start kiosk-control-server
        ;;
    stop)
        echo "⏹️  Deteniendo servidor..."
        pm2 stop kiosk-control-server
        ;;
    restart)
        echo "🔄 Reiniciando servidor..."
        pm2 restart kiosk-control-server
        ;;
    status)
        echo "📊 Estado del servidor:"
        pm2 status
        ;;
    logs)
        echo "📋 Logs en tiempo real (Ctrl+C para salir):"
        pm2 logs kiosk-control-server
        ;;
    monitor)
        echo "📈 Monitor en tiempo real:"
        pm2 monit
        ;;
    update)
        echo "🔄 Actualizando servidor..."
        git pull
        npm install
        pm2 restart kiosk-control-server
        ;;
    backup)
        echo "💾 Creando backup de base de datos..."
        pg_dump -h localhost -U Comunsoft -d kiosk > "backup_$(date +%Y%m%d_%H%M%S).sql"
        echo "✅ Backup creado"
        ;;
    *)
        echo "🛠️  Comandos disponibles:"
        echo "  $0 start    - Iniciar servidor"
        echo "  $0 stop     - Detener servidor"
        echo "  $0 restart  - Reiniciar servidor"
        echo "  $0 status   - Ver estado"
        echo "  $0 logs     - Ver logs en tiempo real"
        echo "  $0 monitor  - Monitor de recursos"
        echo "  $0 update   - Actualizar desde git"
        echo "  $0 backup   - Backup de base de datos"
        ;;
esac
EOF

chmod +x manage.sh

# Instalar nginx
echo "🌐 Instalando nginx..."
apt install -y nginx

# Hacer backup de configuración nginx existente
if [ -f "/etc/nginx/sites-enabled/default" ]; then
    echo "💾 Haciendo backup de configuración nginx existente..."
    cp /etc/nginx/sites-enabled/default /etc/nginx/sites-enabled/default.backup
fi

# Configurar nginx para dominio
cat > /etc/nginx/sites-available/kiosk-control << EOF
server {
    listen 80;
    server_name kiosk.comunsoft.com;
    
    location / {
        proxy_pass http://localhost:$PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
    
    location /socket.io/ {
        proxy_pass http://localhost:$PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Activar sitio nginx
ln -sf /etc/nginx/sites-available/kiosk-control /etc/nginx/sites-enabled/
nginx -t && systemctl restart nginx
systemctl enable nginx

# Instalar certbot para SSL
echo "🔒 Instalando certificado SSL..."
apt install -y certbot python3-certbot-nginx

# Obtener certificado SSL automáticamente
certbot --nginx -d kiosk.comunsoft.com --non-interactive --agree-tos --email admin@comunsoft.com

echo ""
echo "🎉 ¡INSTALACIÓN COMPLETADA!"
echo "=========================="
echo ""
echo "📍 URLs disponibles:"
echo "   🌐 Panel Web: https://kiosk.comunsoft.com"
echo "   📱 WebSocket: wss://kiosk.comunsoft.com"
echo ""
echo "⚙️  Comandos útiles:"
echo "   ./manage.sh status   - Ver estado"
echo "   ./manage.sh logs     - Ver logs"
echo "   ./manage.sh restart  - Reiniciar"
echo ""
echo "📁 Archivos importantes:"
echo "   📋 Logs: logs/*.log"
echo "   ⚙️  Config: ecosystem.config.js"
echo ""
echo "🎯 Próximos pasos:"
echo "   1. Configura DNS: kiosk.comunsoft.com → 159.100.14.35"
echo "   2. Verifica HTTPS: curl https://kiosk.comunsoft.com"
echo "   3. Abre el panel: https://kiosk.comunsoft.com"
echo "   4. Instala APK modificado en tablets"
echo ""
echo "✅ Servidor listo para recibir tablets!"
