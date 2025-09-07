# 🚀 Kiosk VPS Installer

Instalador automático para servidor de control de kiosks Android en VPS con PostgreSQL.

## 🎯 Instalación Rápida

### 1. Clonar en el VPS
```bash
# Conectar al VPS
ssh root@159.100.14.35

# Clonar repositorio
git clone https://github.com/Comunsoft/kiosk-vps-installer.git
cd kiosk-vps-installer
```

### 2. Verificar seguridad
```bash
# Ejecutar verificación pre-instalación
chmod +x pre-check.sh
./pre-check.sh
```

### 3. Instalar automáticamente
```bash
# Instalar servidor completo
chmod +x setup.sh
./setup.sh
```

## ✅ Resultado

- **Panel Web:** https://kiosk.comunsoft.com
- **WebSocket:** wss://kiosk.comunsoft.com  
- **SSL:** Certificado automático Let's Encrypt
- **Base de datos:** PostgreSQL con usuario Comunsoft
- **Puerto:** Detección automática (3000+)

## 🛡️ Seguridad

- ✅ NO afecta aplicaciones existentes
- ✅ Backup automático antes de instalar
- ✅ Puerto dinámico sin conflictos
- ✅ Base PostgreSQL aislada
- ✅ Configuración nginx adicional

## ⚙️ Gestión

```bash
# Comandos útiles
./manage.sh status    # Ver estado
./manage.sh logs      # Ver logs
./manage.sh restart   # Reiniciar
./manage.sh backup    # Backup BD
```

## 📱 APK Android

La aplicación Android se conecta automáticamente a `wss://kiosk.comunsoft.com` y aparece en el panel web.

---

**Configurado para:** kiosk.comunsoft.com → 159.100.14.35