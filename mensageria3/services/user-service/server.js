const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const path = require('path');

// Importar banco NoSQL e service registry
// Assume-se que a estrutura de pastas é services/user-service/
const JsonDatabase = require('../../shared/JsonDatabase');
const serviceRegistry = require('../../shared/serviceRegistry');
// ALTERAÇÃO 1: Importar MessageBroker
const messageBroker = require('../../shared/MessageBroker');

class UserService {
    constructor() {
        this.app = express();
        this.port = process.env.PORT || 3001;
        this.serviceName = 'user-service';
        // Ajuste para usar o nome do container ou localhost dependendo do ambiente
        this.serviceUrl = process.env.SERVICE_URL || `http://localhost:${this.port}`;
        
        this.setupDatabase();
        this.setupMiddleware();
        this.setupRoutes();
        this.setupErrorHandling();
        this.seedInitialData();
    }

    setupDatabase() {
        const dbPath = path.join(__dirname, 'database');
        this.usersDb = new JsonDatabase(dbPath, 'users');
        console.log('User Service: Banco NoSQL inicializado');
    }

    async seedInitialData() {
        // Aguardar inicialização e criar usuário admin se não existir
        setTimeout(async () => {
            try {
                const existingUsers = await this.usersDb.find();
                
                if (existingUsers.length === 0) {
                    const adminPassword = await bcrypt.hash('admin123', 12);
                    const now = new Date().toISOString();
                    
                    await this.usersDb.create({
                        id: uuidv4(),
                        email: 'admin@microservices.com',
                        username: 'admin',
                        password: adminPassword,
                        firstName: 'Administrador',
                        lastName: 'Sistema',
                        role: 'admin',
                        status: 'active',
                        preferences: {
                            defaultStore: 'Matriz',
                            currency: 'BRL'
                        },
                        createdAt: now,
                        updatedAt: now
                    });

                    console.log('Usuário administrador criado (admin@microservices.com / admin123)');
                }
            } catch (error) {
                console.error('Erro ao criar dados iniciais:', error);
            }
        }, 1000);
    }

    setupMiddleware() {
        this.app.use(helmet());
        this.app.use(cors());
        this.app.use(morgan('combined'));
        this.app.use(express.json());
        this.app.use(express.urlencoded({ extended: true }));

        // Service info headers
        this.app.use((req, res, next) => {
            res.setHeader('X-Service', this.serviceName);
            res.setHeader('X-Service-Version', '1.0.0');
            res.setHeader('X-Database', 'JSON-NoSQL');
            next();
        });
    }

    setupRoutes() {
        // Health check
        this.app.get('/health', async (req, res) => {
            try {
                const userCount = await this.usersDb.count();
                res.json({
                    service: this.serviceName,
                    status: 'healthy',
                    timestamp: new Date().toISOString(),
                    uptime: process.uptime(),
                    version: '1.0.0',
                    database: {
                        type: 'JSON-NoSQL',
                        userCount: userCount
                    }
                });
            } catch (error) {
                res.status(503).json({
                    service: this.serviceName,
                    status: 'unhealthy',
                    error: error.message
                });
            }
        });

        // Service info
        this.app.get('/', (req, res) => {
            res.json({
                service: 'User Service',
                version: '1.0.0',
                description: 'Microsserviço para gerenciamento de usuários com NoSQL',
                database: 'JSON-NoSQL',
                endpoints: [
                    'POST /auth/register',
                    'POST /auth/login', 
                    'POST /auth/validate',
                    'GET /users',
                    'GET /users/:id',
                    'PUT /users/:id',
                    'GET /search'
                ]
            });
        });

        // Auth routes
        this.app.post('/auth/register', this.register.bind(this));
        this.app.post('/auth/login', this.login.bind(this));
        this.app.post('/auth/validate', this.validateToken.bind(this));

        // User routes (protected)
        this.app.get('/users', this.authMiddleware.bind(this), this.getUsers.bind(this));
        this.app.get('/users/:id', this.authMiddleware.bind(this), this.getUser.bind(this));
        this.app.put('/users/:id', this.authMiddleware.bind(this), this.updateUser.bind(this));
        
        // Search route
        this.app.get('/search', this.authMiddleware.bind(this), this.searchUsers.bind(this));
    }

    setupErrorHandling() {
        this.app.use('*', (req, res) => {
            res.status(404).json({
                success: false,
                message: 'Endpoint não encontrado',
                service: this.serviceName
            });
        });

        this.app.use((error, req, res, next) => {
            console.error('User Service Error:', error);
            res.status(500).json({
                success: false,
                message: 'Erro interno do serviço',
                service: this.serviceName
            });
        });
    }

    // Auth middleware
    authMiddleware(req, res, next) {
        const authHeader = req.header('Authorization');
        
        if (!authHeader?.startsWith('Bearer ')) {
            return res.status(401).json({
                success: false,
                message: 'Token obrigatório'
            });
        }

        const token = authHeader.replace('Bearer ', '');
        
        try {
            const decoded = jwt.verify(token, process.env.JWT_SECRET || 'user-secret');
            req.user = decoded;
            next();
        } catch (error) {
            res.status(401).json({
                success: false,
                message: 'Token inválido'
            });
        }
    }

    // Register user
    async register(req, res) {
        try {
            const { email, username, password, firstName, lastName } = req.body;

            // Validações básicas
            if (!email || !username || !password || !firstName || !lastName) {
                return res.status(400).json({
                    success: false,
                    message: 'Todos os campos são obrigatórios'
                });
            }

            // Verificar se usuário já existe
            const existingEmail = await this.usersDb.findOne({ email: email.toLowerCase() });
            const existingUsername = await this.usersDb.findOne({ username: username.toLowerCase() });

            if (existingEmail) {
                return res.status(409).json({
                    success: false,
                    message: 'Email já está em uso'
                });
            }

            if (existingUsername) {
                return res.status(409).json({
                    success: false,
                    message: 'Username já está em uso'
                });
            }

            // Hash password
            const hashedPassword = await bcrypt.hash(password, 12);
            const now = new Date().toISOString();

            // Criar usuário com schema ajustado para os requisitos
            const newUser = await this.usersDb.create({
                id: uuidv4(),
                email: email.toLowerCase(),
                username: username.toLowerCase(),
                password: hashedPassword,
                firstName,
                lastName,
                role: 'user',
                status: 'active',
                preferences: {
                    defaultStore: 'Principal', // Valor padrão
                    currency: 'BRL'            // Valor padrão
                },
                createdAt: now,
                updatedAt: now
            });

            const { password: _, ...userWithoutPassword } = newUser;

            // ALTERAÇÃO 2: Publicar evento de criação de usuário
            // (Útil para envio de email de boas-vindas ou logs de auditoria futuros)
            await messageBroker.publish('user_events', 'user.created', {
                id: newUser.id,
                username: newUser.username,
                email: newUser.email,
                createdAt: newUser.createdAt
            });

            const token = jwt.sign(
                { 
                    id: newUser.id, 
                    email: newUser.email, 
                    username: newUser.username, 
                    role: newUser.role 
                },
                process.env.JWT_SECRET || 'user-secret',
                { expiresIn: '24h' }
            );

            res.status(201).json({
                success: true,
                message: 'Usuário criado com sucesso',
                data: { user: userWithoutPassword, token }
            });
        } catch (error) {
            console.error('Erro no registro:', error);
            res.status(500).json({
                success: false,
                message: 'Erro interno do servidor'
            });
        }
    }

    // Login user
    async login(req, res) {
        try {
            const { identifier, password } = req.body;

            if (!identifier || !password) {
                return res.status(400).json({
                    success: false,
                    message: 'Identificador e senha obrigatórios'
                });
            }

            const user = await this.usersDb.findOne({
                $or: [
                    { email: identifier.toLowerCase() },
                    { username: identifier.toLowerCase() }
                ]
            });

            if (!user || !await bcrypt.compare(password, user.password)) {
                return res.status(401).json({
                    success: false,
                    message: 'Credenciais inválidas'
                });
            }

            // Verificar se usuário está ativo
            if (user.status !== 'active') {
                return res.status(403).json({
                    success: false,
                    message: 'Conta desativada'
                });
            }

            // Atualizar ultimo login (preservando updatedAt original se desejado, ou atualizando)
            await this.usersDb.update(user.id, {
                lastLogin: new Date().toISOString()
            });

            const { password: _, ...userWithoutPassword } = user;
            
            const token = jwt.sign(
                { 
                    id: user.id, 
                    email: user.email, 
                    username: user.username, 
                    role: user.role 
                },
                process.env.JWT_SECRET || 'user-secret',
                { expiresIn: '24h' }
            );

            res.json({
                success: true,
                message: 'Login realizado com sucesso',
                data: { user: userWithoutPassword, token }
            });
        } catch (error) {
            console.error('Erro no login:', error);
            res.status(500).json({
                success: false,
                message: 'Erro interno do servidor'
            });
        }
    }

    // Validate token
    async validateToken(req, res) {
        try {
            const { token } = req.body;

            if (!token) {
                return res.status(400).json({
                    success: false,
                    message: 'Token obrigatório'
                });
            }

            const decoded = jwt.verify(token, process.env.JWT_SECRET || 'user-secret');
            const user = await this.usersDb.findById(decoded.id);

            if (!user || user.status !== 'active') {
                return res.status(401).json({
                    success: false,
                    message: 'Usuário não encontrado ou inativo'
                });
            }

            const { password: _, ...userWithoutPassword } = user;

            res.json({
                success: true,
                message: 'Token válido',
                data: { user: userWithoutPassword }
            });
        } catch (error) {
            res.status(401).json({
                success: false,
                message: 'Token inválido'
            });
        }
    }

    // Get users (com paginação)
    async getUsers(req, res) {
        try {
            const { page = 1, limit = 10, role, status } = req.query;
            const skip = (page - 1) * parseInt(limit);

            // Filtros NoSQL flexíveis
            const filter = {};
            if (role) filter.role = role;
            if (status) filter.status = status;

            const users = await this.usersDb.find(filter, {
                skip: skip,
                limit: parseInt(limit),
                sort: { createdAt: -1 }
            });

            // Remove passwords
            const safeUsers = users.map(user => {
                const { password, ...safeUser } = user;
                return safeUser;
            });

            const total = await this.usersDb.count(filter);

            res.json({
                success: true,
                data: safeUsers,
                pagination: {
                    page: parseInt(page),
                    limit: parseInt(limit),
                    total: total,
                    pages: Math.ceil(total / parseInt(limit))
                }
            });
        } catch (error) {
            console.error('Erro ao buscar usuários:', error);
            res.status(500).json({
                success: false,
                message: 'Erro interno do servidor'
            });
        }
    }

    // Get user by ID
    async getUser(req, res) {
        try {
            const { id } = req.params;
            const user = await this.usersDb.findById(id);

            if (!user) {
                return res.status(404).json({
                    success: false,
                    message: 'Usuário não encontrado'
                });
            }

            // Verificar permissão (usuário só vê próprio perfil ou admin vê tudo)
            if (req.user.id !== id && req.user.role !== 'admin') {
                return res.status(403).json({
                    success: false,
                    message: 'Acesso negado'
                });
            }

            const { password, ...userWithoutPassword } = user;

            res.json({
                success: true,
                data: userWithoutPassword
            });
        } catch (error) {
            console.error('Erro ao buscar usuário:', error);
            res.status(500).json({
                success: false,
                message: 'Erro interno do servidor'
            });
        }
    }

    // Update user
    async updateUser(req, res) {
        try {
            const { id } = req.params;
            const { firstName, lastName, email, defaultStore, currency } = req.body;

            // Verificar permissão
            if (req.user.id !== id && req.user.role !== 'admin') {
                return res.status(403).json({
                    success: false,
                    message: 'Acesso negado'
                });
            }

            const user = await this.usersDb.findById(id);
            if (!user) {
                return res.status(404).json({
                    success: false,
                    message: 'Usuário não encontrado'
                });
            }

            // Updates
            const updates = {};
            if (firstName) updates.firstName = firstName;
            if (lastName) updates.lastName = lastName;
            if (email) updates.email = email.toLowerCase();
            
            // Atualizar preferências se fornecidas
            if (defaultStore) updates['preferences.defaultStore'] = defaultStore;
            if (currency) updates['preferences.currency'] = currency;

            // Atualizar timestamp
            updates.updatedAt = new Date().toISOString();

            const updatedUser = await this.usersDb.update(id, updates);
            const { password, ...userWithoutPassword } = updatedUser;

            // ALTERAÇÃO 3: Publicar evento de atualização
            await messageBroker.publish('user_events', 'user.updated', {
                id: updatedUser.id,
                username: updatedUser.username,
                updatedAt: updatedUser.updatedAt
            });

            res.json({
                success: true,
                message: 'Usuário atualizado com sucesso',
                data: userWithoutPassword
            });
        } catch (error) {
            console.error('Erro ao atualizar usuário:', error);
            res.status(500).json({
                success: false,
                message: 'Erro interno do servidor'
            });
        }
    }

    // Search users
    async searchUsers(req, res) {
        try {
            const { q, limit = 10 } = req.query;

            if (!q) {
                return res.status(400).json({
                    success: false,
                    message: 'Parâmetro de busca "q" é obrigatório'
                });
            }

            // Busca full-text NoSQL
            const users = await this.usersDb.search(q, ['firstName', 'lastName', 'username', 'email']);
            
            // Filtrar apenas usuários ativos e remover passwords
            const safeUsers = users
                .filter(user => user.status === 'active')
                .slice(0, parseInt(limit))
                .map(user => {
                    const { password, ...safeUser } = user;
                    return safeUser;
                });

            res.json({
                success: true,
                data: {
                    query: q,
                    results: safeUsers,
                    total: safeUsers.length
                }
            });
        } catch (error) {
            console.error('Erro na busca de usuários:', error);
            res.status(500).json({
                success: false,
                message: 'Erro interno do servidor'
            });
        }
    }

    // Register with service registry
    registerWithRegistry() {
        serviceRegistry.register(this.serviceName, {
            url: this.serviceUrl,
            version: '1.0.0',
            database: 'JSON-NoSQL',
            endpoints: ['/health', '/auth/register', '/auth/login', '/users', '/search']
        });
    }

    // Start health check reporting
    startHealthReporting() {
        setInterval(() => {
            serviceRegistry.updateHealth(this.serviceName, true);
        }, 30000);
    }

    // ALTERAÇÃO 4: Conectar ao RabbitMQ no start
    async start() {
        // Conexão com RabbitMQ
        await messageBroker.connect();

        this.app.listen(this.port, () => {
            console.log('=====================================');
            console.log(`User Service iniciado na porta ${this.port}`);
            console.log(`URL: ${this.serviceUrl}`);
            console.log(`Modo: Assíncrono (RabbitMQ Publisher)`);
            console.log('=====================================');
            
            // Register with service registry
            this.registerWithRegistry();
            this.startHealthReporting();
        });
    }
}

// Start service
if (require.main === module) {
    const userService = new UserService();
    userService.start();

    // Graceful shutdown
    process.on('SIGTERM', () => {
        serviceRegistry.unregister('user-service');
        process.exit(0);
    });
    process.on('SIGINT', () => {
        serviceRegistry.unregister('user-service');
        process.exit(0);
    });
}

module.exports = UserService;