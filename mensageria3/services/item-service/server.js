const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const { v4: uuidv4 } = require('uuid');
const path = require('path');
const axios = require('axios');

// Importar banco NoSQL e service registry
const JsonDatabase = require('../../shared/JsonDatabase');
const serviceRegistry = require('../../shared/serviceRegistry');
// ALTERAÇÃO 1: Importar o messageBroker (instância singleton)
const messageBroker = require('../../shared/MessageBroker');

class ItemService {
    constructor() {
        this.app = express();
        this.port = process.env.PORT || 3003;
        this.serviceName = 'item-service';
        this.serviceUrl = process.env.SERVICE_URL || `http://localhost:${this.port}`;
        
        this.setupDatabase();
        this.setupMiddleware();
        this.setupRoutes();
        this.setupErrorHandling();
        this.seedInitialData();
    }

    setupDatabase() {
        const dbPath = path.join(__dirname, 'database');
        this.itemsDb = new JsonDatabase(dbPath, 'items');
        console.log('Item Service: Banco NoSQL inicializado');
    }

    async seedInitialData() {
        setTimeout(async () => {
            try {
                const existingItems = await this.itemsDb.find();
                
                if (existingItems.length === 0) {
                    const now = new Date().toISOString();
                    const sampleItems = [
                        {
                            id: uuidv4(),
                            name: 'Arroz Branco Tipo 1',
                            category: 'Grãos',
                            brand: 'Tio João',
                            unit: 'kg',
                            averagePrice: 28.90,
                            barcode: '7891234567890',
                            description: 'Pacote de 5kg',
                            active: true,
                            createdAt: now
                        },
                        {
                            id: uuidv4(),
                            name: 'Leite Integral',
                            category: 'Laticínios',
                            brand: 'Itambé',
                            unit: 'litro',
                            averagePrice: 4.59,
                            barcode: '7899876543210',
                            description: 'Caixa 1L',
                            active: true,
                            createdAt: now
                        },
                        {
                            id: uuidv4(),
                            name: 'Sabão em Pó',
                            category: 'Limpeza',
                            brand: 'Omo',
                            unit: 'kg',
                            averagePrice: 18.50,
                            barcode: '7891112223334',
                            description: 'Caixa 1.6kg Lavagem Perfeita',
                            active: true,
                            createdAt: now
                        },
                        {
                            id: uuidv4(),
                            name: 'Refrigerante Cola',
                            category: 'Bebidas',
                            brand: 'Coca-Cola',
                            unit: 'un',
                            averagePrice: 8.99,
                            barcode: '7895556667778',
                            description: 'Garrafa PET 2L',
                            active: true,
                            createdAt: now
                        }
                    ];

                    for (const item of sampleItems) {
                        await this.itemsDb.create(item);
                    }

                    console.log('Dados de seed verificados.');
                }
            } catch (error) {
                console.error('Erro no seed:', error);
            }
        }, 1000);
    }

    setupMiddleware() {
        this.app.use(helmet());
        this.app.use(cors());
        this.app.use(morgan('combined'));
        this.app.use(express.json());
        this.app.use(express.urlencoded({ extended: true }));

        this.app.use((req, res, next) => {
            res.setHeader('X-Service', this.serviceName);
            next();
        });
    }

    setupRoutes() {
        this.app.get('/health', async (req, res) => {
            try {
                const itemCount = await this.itemsDb.count();
                res.json({
                    service: this.serviceName,
                    status: 'healthy',
                    timestamp: new Date().toISOString(),
                    uptime: process.uptime(),
                    database: {
                        type: 'JSON-NoSQL',
                        itemCount: itemCount
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

        this.app.get('/', (req, res) => {
            res.json({
                service: 'Item Service',
                description: 'Gerenciamento de itens e produtos',
                endpoints: [
                    'GET /items',
                    'GET /items/:id',
                    'POST /items',
                    'PUT /items/:id',
                    'GET /categories',
                    'GET /search'
                ]
            });
        });

        this.app.get('/items', this.getItems.bind(this));
        this.app.get('/items/:id', this.getItem.bind(this));
        this.app.post('/items', this.authMiddleware.bind(this), this.createItem.bind(this));
        this.app.put('/items/:id', this.authMiddleware.bind(this), this.updateItem.bind(this));
        this.app.get('/categories', this.getCategories.bind(this));
        this.app.get('/search', this.searchItems.bind(this));
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
            console.error('Item Service Error:', error);
            res.status(500).json({
                success: false,
                message: 'Erro interno do serviço',
                service: this.serviceName
            });
        });
    }

    async authMiddleware(req, res, next) {
        const authHeader = req.header('Authorization');
        
        if (!authHeader?.startsWith('Bearer ')) {
            return res.status(401).json({
                success: false,
                message: 'Token obrigatório'
            });
        }

        try {
            const userService = serviceRegistry.discover('user-service');
            const response = await axios.post(`${userService.url}/auth/validate`, {
                token: authHeader.replace('Bearer ', '')
            }, { timeout: 5000 });

            if (response.data.success) {
                req.user = response.data.data.user;
                next();
            } else {
                res.status(401).json({
                    success: false,
                    message: 'Token inválido'
                });
            }
        } catch (error) {
            res.status(503).json({
                success: false,
                message: 'Serviço de autenticação indisponível'
            });
        }
    }

    // Métodos de Leitura
    async getItems(req, res) {
        try {
            const { 
                page = 1, 
                limit = 20, 
                category, 
                search,
                active = 'true'
            } = req.query;
            
            const skip = (page - 1) * parseInt(limit);
            const filter = {};
            if (active !== 'all') filter.active = active === 'true';
            if (category) filter.category = category;

            let items;
            
            if (search) {
                items = await this.itemsDb.search(search, ['name', 'brand', 'barcode']);
                items = items.filter(item => {
                    if (category && item.category !== category) return false;
                    if (active !== 'all' && item.active !== (active === 'true')) return false;
                    return true;
                });
                items = items.slice(skip, skip + parseInt(limit));
            } else {
                items = await this.itemsDb.find(filter, {
                    skip: skip,
                    limit: parseInt(limit),
                    sort: { createdAt: -1 }
                });
            }

            const total = search ? items.length : await this.itemsDb.count(filter);

            res.json({
                success: true,
                data: items,
                pagination: {
                    page: parseInt(page),
                    limit: parseInt(limit),
                    total: total,
                    pages: Math.ceil(total / parseInt(limit)) || 1
                }
            });
        } catch (error) {
            console.error('Erro ao buscar itens:', error);
            res.status(500).json({
                success: false,
                message: 'Erro interno do servidor'
            });
        }
    }

    async getItem(req, res) {
        try {
            const { id } = req.params;
            const item = await this.itemsDb.findById(id);

            if (!item) {
                return res.status(404).json({
                    success: false,
                    message: 'Item não encontrado'
                });
            }

            res.json({
                success: true,
                data: item
            });
        } catch (error) {
            console.error('Erro ao buscar item:', error);
            res.status(500).json({
                success: false,
                message: 'Erro interno do servidor'
            });
        }
    }

    async createItem(req, res) {
        try {
            const { 
                name, category, brand, unit, 
                averagePrice, barcode, description, active = true 
            } = req.body;

            if (!name || !category) {
                return res.status(400).json({
                    success: false,
                    message: 'Nome e Categoria são obrigatórios'
                });
            }

            const newItem = await this.itemsDb.create({
                id: uuidv4(),
                name,
                category,
                brand: brand || '',
                unit: unit || 'un',
                averagePrice: parseFloat(averagePrice) || 0,
                barcode: barcode || '',
                description: description || '',
                active: active,
                createdAt: new Date().toISOString()
            });

            res.status(201).json({
                success: true,
                message: 'Item criado com sucesso',
                data: newItem
            });
        } catch (error) {
            console.error('Erro ao criar item:', error);
            res.status(500).json({
                success: false,
                message: 'Erro interno do servidor'
            });
        }
    }

    // ALTERAÇÃO 2: Atualizar item e publicar evento no RabbitMQ
    async updateItem(req, res) {
        try {
            const { id } = req.params;
            const updates = req.body;
            
            // Garantir que campos numéricos sejam convertidos
            if (updates.averagePrice !== undefined) {
                updates.averagePrice = parseFloat(updates.averagePrice);
            }

            const item = await this.itemsDb.findById(id);
            if (!item) {
                return res.status(404).json({
                    success: false,
                    message: 'Item não encontrado'
                });
            }

            // Atualiza no banco
            const updatedItem = await this.itemsDb.update(id, updates);

            // LOGICA ASSÍNCRONA: Publicar evento se houver mudança relevante
            if (updates.name || updates.averagePrice || updates.active !== undefined) {
                console.log(`📢 Publicando evento de atualização para item: ${id}`);
                
                // Publicar na exchange 'item_events' com routing key 'item.updated'
                await messageBroker.publish('item_events', 'item.updated', {
                    itemId: updatedItem.id,
                    name: updatedItem.name,
                    averagePrice: updatedItem.averagePrice,
                    active: updatedItem.active,
                    updatedAt: new Date().toISOString()
                });
            }

            res.json({
                success: true,
                message: 'Item atualizado com sucesso',
                data: updatedItem
            });
        } catch (error) {
            console.error('Erro ao atualizar item:', error);
            res.status(500).json({
                success: false,
                message: 'Erro interno do servidor'
            });
        }
    }

    async getCategories(req, res) {
        try {
            const items = await this.itemsDb.find({ active: true });
            const categoriesSet = new Set();
            items.forEach(item => {
                if (item.category) categoriesSet.add(item.category);
            });
            const categories = Array.from(categoriesSet).sort();
            res.json({ success: true, data: categories });
        } catch (error) {
            console.error('Erro ao buscar categorias:', error);
            res.status(500).json({ success: false, message: 'Erro interno do servidor' });
        }
    }

    async searchItems(req, res) {
        try {
            const { q } = req.query;
            if (!q) {
                return res.status(400).json({ success: false, message: 'Parâmetro de busca "q" é obrigatório' });
            }
            let items = await this.itemsDb.search(q, ['name', 'brand', 'barcode', 'description']);
            items = items.filter(item => item.active);
            res.json({
                success: true,
                data: { query: q, results: items, total: items.length }
            });
        } catch (error) {
            console.error('Erro na busca de itens:', error);
            res.status(500).json({ success: false, message: 'Erro interno do servidor' });
        }
    }

    registerWithRegistry() {
        serviceRegistry.register(this.serviceName, {
            url: this.serviceUrl,
            version: '1.0.0',
            database: 'JSON-NoSQL',
            endpoints: ['/health', '/items', '/categories', '/search']
        });
    }

    startHealthReporting() {
        setInterval(() => {
            serviceRegistry.updateHealth(this.serviceName, true);
        }, 30000);
    }

    // ALTERAÇÃO 3: Conectar ao RabbitMQ ao iniciar
    async start() {
        // Conexão com RabbitMQ antes de ouvir HTTP
        await messageBroker.connect();

        this.app.listen(this.port, () => {
            console.log('=====================================');
            console.log(`Item Service iniciado na porta ${this.port}`);
            console.log(`URL: ${this.serviceUrl}`);
            console.log(`Modo: Assíncrono (RabbitMQ Publisher)`);
            console.log('=====================================');
            
            this.registerWithRegistry();
            this.startHealthReporting();
        });
    }
}

// Start service
if (require.main === module) {
    const itemService = new ItemService();
    itemService.start();

    process.on('SIGTERM', () => {
        serviceRegistry.unregister('item-service');
        process.exit(0);
    });
    process.on('SIGINT', () => {
        serviceRegistry.unregister('item-service');
        process.exit(0);
    });
}

module.exports = ItemService;