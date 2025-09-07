const { Pool } = require('pg');

class Database {
    constructor() {
        // Configuración de conexión a PostgreSQL existente
        this.pool = new Pool({
            host: 'localhost',
            port: 5432,
            database: 'kiosk',  // Nueva base que crearás en tu PostgreSQL
            user: 'Comunsoft',
            password: 'Cornershop1!',
            max: 20,
            idleTimeoutMillis: 30000,
            connectionTimeoutMillis: 2000,
        });

        this.pool.on('error', (err) => {
            console.error('❌ Error inesperado en cliente PostgreSQL:', err);
        });

        this.initConnection();
    }

    async initConnection() {
        try {
            const client = await this.pool.connect();
            console.log('✅ Conectado a PostgreSQL - Base: kiosk');
            
            // Verificar si las tablas existen y crearlas si no
            await this.initTables(client);
            client.release();
            
        } catch (err) {
            console.error('❌ Error conectando a PostgreSQL:', err.message);
            console.error('💡 Asegúrate de que:');
            console.error('   1. PostgreSQL esté ejecutándose');
            console.error('   2. La base "kiosk" exista');
            console.error('   3. Las credenciales sean correctas');
        }
    }

    async initTables(client) {
        try {
            // Tabla de tablets
            await client.query(`
                CREATE TABLE IF NOT EXISTS tablets (
                    id VARCHAR(255) PRIMARY KEY,
                    name VARCHAR(255) NOT NULL,
                    ip VARCHAR(45),
                    status VARCHAR(20) DEFAULT 'offline',
                    current_url TEXT,
                    last_seen TIMESTAMP WITH TIME ZONE,
                    uptime VARCHAR(50),
                    stats JSONB,
                    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
                )
            `);

            // Tabla de comandos ejecutados
            await client.query(`
                CREATE TABLE IF NOT EXISTS command_logs (
                    id SERIAL PRIMARY KEY,
                    tablet_id VARCHAR(255) NOT NULL,
                    command VARCHAR(100) NOT NULL,
                    params JSONB,
                    timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
                    source_ip VARCHAR(45),
                    success BOOLEAN DEFAULT NULL,
                    response TEXT,
                    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
                )
            `);

            // Tabla de estadísticas diarias
            await client.query(`
                CREATE TABLE IF NOT EXISTS daily_stats (
                    id SERIAL PRIMARY KEY,
                    tablet_id VARCHAR(255) NOT NULL,
                    date DATE NOT NULL,
                    total_uptime_minutes INTEGER DEFAULT 0,
                    url_changes INTEGER DEFAULT 0,
                    restarts INTEGER DEFAULT 0,
                    commands_received INTEGER DEFAULT 0,
                    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                    UNIQUE(tablet_id, date)
                )
            `);

            // Tabla de logs de actividad
            await client.query(`
                CREATE TABLE IF NOT EXISTS activity_logs (
                    id SERIAL PRIMARY KEY,
                    tablet_id VARCHAR(255),
                    level VARCHAR(20) NOT NULL CHECK(level IN ('info', 'warning', 'error')),
                    message TEXT NOT NULL,
                    timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
                    metadata JSONB,
                    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
                )
            `);

            // Crear índices para mejor rendimiento
            await client.query(`CREATE INDEX IF NOT EXISTS idx_tablets_status ON tablets (status)`);
            await client.query(`CREATE INDEX IF NOT EXISTS idx_command_logs_tablet ON command_logs (tablet_id)`);
            await client.query(`CREATE INDEX IF NOT EXISTS idx_command_logs_timestamp ON command_logs (timestamp DESC)`);
            await client.query(`CREATE INDEX IF NOT EXISTS idx_daily_stats_date ON daily_stats (date DESC)`);
            await client.query(`CREATE INDEX IF NOT EXISTS idx_activity_logs_timestamp ON activity_logs (timestamp DESC)`);

            console.log('✅ Tablas PostgreSQL inicializadas correctamente');
        } catch (err) {
            console.error('❌ Error creando tablas:', err.message);
        }
    }

    // Actualizar información de tablet
    async updateTablet(tabletInfo) {
        const { id, name, ip, status, currentUrl, lastSeen, uptime, stats } = tabletInfo;
        
        try {
            await this.pool.query(`
                INSERT INTO tablets 
                (id, name, ip, status, current_url, last_seen, uptime, stats, updated_at)
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8, CURRENT_TIMESTAMP)
                ON CONFLICT (id) DO UPDATE SET
                    name = EXCLUDED.name,
                    ip = EXCLUDED.ip,
                    status = EXCLUDED.status,
                    current_url = EXCLUDED.current_url,
                    last_seen = EXCLUDED.last_seen,
                    uptime = EXCLUDED.uptime,
                    stats = EXCLUDED.stats,
                    updated_at = CURRENT_TIMESTAMP
            `, [id, name, ip, status, currentUrl, lastSeen, uptime, JSON.stringify(stats)]);
        } catch (err) {
            console.error('❌ Error actualizando tablet:', err.message);
        }
    }

    // Registrar comando ejecutado
    async logCommand(commandInfo) {
        const { tabletId, command, params, timestamp, sourceIp } = commandInfo;
        
        try {
            await this.pool.query(`
                INSERT INTO command_logs 
                (tablet_id, command, params, timestamp, source_ip)
                VALUES ($1, $2, $3, $4, $5)
            `, [tabletId, command, JSON.stringify(params), timestamp, sourceIp]);
        } catch (err) {
            console.error('❌ Error logging comando:', err.message);
        }
    }

    // Obtener logs de comandos
    async getLogs(tabletId = null, limit = 100) {
        try {
            let query, params;
            
            if (tabletId) {
                query = `
                    SELECT cl.*, t.name as tablet_name 
                    FROM command_logs cl 
                    LEFT JOIN tablets t ON cl.tablet_id = t.id 
                    WHERE cl.tablet_id = $1 
                    ORDER BY cl.created_at DESC 
                    LIMIT $2
                `;
                params = [tabletId, limit];
            } else {
                query = `
                    SELECT cl.*, t.name as tablet_name 
                    FROM command_logs cl 
                    LEFT JOIN tablets t ON cl.tablet_id = t.id 
                    ORDER BY cl.created_at DESC 
                    LIMIT $1
                `;
                params = [limit];
            }
            
            const result = await this.pool.query(query, params);
            
            return result.rows.map(row => ({
                ...row,
                params: row.params || null
            }));
        } catch (err) {
            console.error('❌ Error obteniendo logs:', err.message);
            return [];
        }
    }

    // Cerrar conexión
    async close() {
        try {
            await this.pool.end();
            console.log('✅ Pool de conexiones PostgreSQL cerrado');
        } catch (err) {
            console.error('❌ Error cerrando conexiones:', err.message);
        }
    }
}

module.exports = Database;