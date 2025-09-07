const express = require('express');
const http = require('http');
const socketIO = require('socket.io');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const morgan = require('morgan');
const path = require('path');
const fs = require('fs');
const Database = require('./database-postgres');

const app = express();
const server = http.createServer(app);
const io = socketIO(server, {
    cors: {
        origin: "*",
        methods: ["GET", "POST"]
    }
});

// Configuración
const PORT = process.env.PORT || 3000;
const DOMAIN = process.env.DOMAIN || 'kiosk.comunsoft.com';

// Base de datos
const db = new Database();

// Middleware
app.use(helmet());
app.use(compression());
app.use(morgan('combined'));
app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// Almacenar conexiones de tablets activas
const activeTablets = new Map();

console.log(`
🚀 SERVIDOR KIOSK CONTROL INICIANDO...
=======================================
📍 Servidor: ${DOMAIN}:${PORT}
🌐 Panel Web: http://${DOMAIN}:${PORT}
📱 API Tablets: ws://${DOMAIN}:${PORT}
=======================================
`);

// WebSocket para tablets Android
io.on('connection', (socket) => {
    console.log(`📱 Nueva conexión: ${socket.id}`);
    
    // Tablet se registra
    socket.on('tablet-register', (data) => {
        const tabletInfo = {
            id: data.tabletId || socket.id,
            name: data.name || `Tablet-${socket.id.substring(0, 8)}`,
            ip: data.ip || socket.handshake.address,
            status: 'online',
            currentUrl: data.currentUrl || '',
            lastSeen: new Date().toISOString(),
            uptime: data.uptime || '00:00:00',
            stats: data.stats || {}
        };
        
        activeTablets.set(socket.id, tabletInfo);
        db.updateTablet(tabletInfo);
        
        console.log(`✅ Tablet registrada: ${tabletInfo.name} (${tabletInfo.ip})`);
        
        // Notificar a todos los clientes web
        socket.broadcast.emit('tablet-online', tabletInfo);
    });
    
    // Tablet envía estado
    socket.on('tablet-status', (data) => {
        if (activeTablets.has(socket.id)) {
            const tablet = activeTablets.get(socket.id);
            tablet.currentUrl = data.currentUrl || tablet.currentUrl;
            tablet.uptime = data.uptime || tablet.uptime;
            tablet.stats = data.stats || tablet.stats;
            tablet.lastSeen = new Date().toISOString();
            
            activeTablets.set(socket.id, tablet);
            db.updateTablet(tablet);
            
            // Retransmitir a clientes web
            socket.broadcast.emit('tablet-status-update', tablet);
        }
    });
    
    // Comandos desde panel web hacia tablets
    socket.on('send-command', (data) => {
        const { tabletId, command, params } = data;
        
        // Buscar la conexión de la tablet objetivo
        const targetSocket = [...io.sockets.sockets.values()]
            .find(s => activeTablets.get(s.id)?.id === tabletId);
        
        if (targetSocket) {
            targetSocket.emit('remote-command', { command, params });
            console.log(`📤 Comando enviado a ${tabletId}: ${command}`);
            
            // Log del comando
            db.logCommand({
                tabletId,
                command,
                params,
                timestamp: new Date().toISOString(),
                sourceIp: socket.handshake.address
            });
        } else {
            socket.emit('command-error', { 
                error: 'Tablet no encontrada o desconectada',
                tabletId 
            });
        }
    });
    
    // Tablet confirma comando ejecutado
    socket.on('command-executed', (data) => {
        const { command, success, message } = data;
        socket.broadcast.emit('command-result', {
            tabletId: activeTablets.get(socket.id)?.id,
            command,
            success,
            message,
            timestamp: new Date().toISOString()
        });
    });
    
    // Desconexión
    socket.on('disconnect', () => {
        if (activeTablets.has(socket.id)) {
            const tablet = activeTablets.get(socket.id);
            console.log(`📱 Tablet desconectada: ${tablet.name}`);
            
            // Marcar como offline
            tablet.status = 'offline';
            tablet.lastSeen = new Date().toISOString();
            db.updateTablet(tablet);
            
            activeTablets.delete(socket.id);
            
            // Notificar a clientes web
            socket.broadcast.emit('tablet-offline', tablet);
        }
    });
});

// API REST para panel web
app.get('/api/tablets', (req, res) => {
    const tablets = Array.from(activeTablets.values());
    res.json({
        success: true,
        count: tablets.length,
        tablets: tablets
    });
});

app.get('/api/tablet/:id', (req, res) => {
    const tabletId = req.params.id;
    const tablet = [...activeTablets.values()].find(t => t.id === tabletId);
    
    if (tablet) {
        res.json({ success: true, tablet });
    } else {
        res.status(404).json({ success: false, error: 'Tablet no encontrada' });
    }
});

app.post('/api/command/:tabletId', (req, res) => {
    const { tabletId } = req.params;
    const { command, params } = req.body;
    
    // Buscar la conexión de la tablet
    const socketId = [...activeTablets.entries()]
        .find(([_, tablet]) => tablet.id === tabletId)?.[0];
    
    if (socketId) {
        const targetSocket = io.sockets.sockets.get(socketId);
        if (targetSocket) {
            targetSocket.emit('remote-command', { command, params });
            
            // Log del comando
            db.logCommand({
                tabletId,
                command,
                params,
                timestamp: new Date().toISOString(),
                sourceIp: req.ip
            });
            
            res.json({ 
                success: true, 
                message: `Comando '${command}' enviado a ${tabletId}` 
            });
        } else {
            res.status(404).json({ success: false, error: 'Socket no encontrado' });
        }
    } else {
        res.status(404).json({ success: false, error: 'Tablet no encontrada' });
    }
});

app.get('/api/logs/:tabletId?', (req, res) => {
    const { tabletId } = req.params;
    const logs = db.getLogs(tabletId);
    res.json({ success: true, logs });
});

app.get('/api/stats', (req, res) => {
    const stats = {
        totalTablets: activeTablets.size,
        onlineTablets: [...activeTablets.values()].filter(t => t.status === 'online').length,
        serverUptime: process.uptime(),
        timestamp: new Date().toISOString()
    };
    res.json({ success: true, stats });
});

// Servir el panel web
app.get('/', (req, res) => {
    res.send(`
    <!DOCTYPE html>
    <html>
    <head>
        <title>Panel Kiosk Control</title>
        <meta charset="utf-8">
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
            h1 { color: #333; }
            .status { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
            .online { color: #28a745; }
            .offline { color: #dc3545; }
        </style>
    </head>
    <body>
        <h1>🖥️ Panel de Control Kiosk</h1>
        <div class="status">
            <h2>Estado del Servidor</h2>
            <p>✅ Servidor activo en puerto ${PORT}</p>
            <p>🌐 Dominio: ${DOMAIN}</p>
            <p>📱 Tablets conectadas: <span id="tablet-count">0</span></p>
            <p>⏰ Iniciado: ${new Date().toLocaleString()}</p>
        </div>
        
        <script src="/socket.io/socket.io.js"></script>
        <script>
            const socket = io();
            let tabletCount = 0;
            
            socket.on('tablet-online', (tablet) => {
                tabletCount++;
                document.getElementById('tablet-count').textContent = tabletCount;
                console.log('Tablet conectada:', tablet);
            });
            
            socket.on('tablet-offline', (tablet) => {
                tabletCount = Math.max(0, tabletCount - 1);
                document.getElementById('tablet-count').textContent = tabletCount;
                console.log('Tablet desconectada:', tablet);
            });
            
            // Obtener estado inicial
            fetch('/api/tablets')
                .then(response => response.json())
                .then(data => {
                    tabletCount = data.count;
                    document.getElementById('tablet-count').textContent = tabletCount;
                });
        </script>
    </body>
    </html>
    `);
});

// Manejo de errores
app.use((err, req, res, next) => {
    console.error('❌ Error del servidor:', err);
    res.status(500).json({ success: false, error: 'Error interno del servidor' });
});

// 404 Handler
app.use((req, res) => {
    res.status(404).json({ success: false, error: 'Endpoint no encontrado' });
});

// Limpiar tablets offline cada 5 minutos
setInterval(() => {
    const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000);
    
    for (const [socketId, tablet] of activeTablets.entries()) {
        if (new Date(tablet.lastSeen) < fiveMinutesAgo) {
            console.log(`🧹 Limpiando tablet inactiva: ${tablet.name}`);
            tablet.status = 'offline';
            db.updateTablet(tablet);
            activeTablets.delete(socketId);
        }
    }
}, 5 * 60 * 1000);

// Iniciar servidor
server.listen(PORT, '0.0.0.0', () => {
    console.log(`
🎉 ¡SERVIDOR ACTIVO!
=======================================
🌐 Panel Web: https://${DOMAIN}
📱 Tablets conecta a: wss://${DOMAIN}
🗄️  Base de datos: PostgreSQL inicializada
⏰ Iniciado: ${new Date().toLocaleString()}
=======================================
    `);
});

// Manejo de señales del sistema
process.on('SIGTERM', () => {
    console.log('🛑 Cerrando servidor...');
    server.close(() => {
        db.close();
        process.exit(0);
    });
});

process.on('SIGINT', () => {
    console.log('🛑 Cerrando servidor...');
    server.close(() => {
        db.close();
        process.exit(0);
    });
});