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

class ListService {
    constructor() {
        this.app = express();
        this.port = process.env.PORT || 3002;
        this.serviceName = 'list-service';
        this.serviceUrl = process.env.SERVICE_URL || `http://localhost:${this.port}`;
        
        this.setupDatabase();
        this.setupMiddleware();
        this.setupRoutes();
        this.setupErrorHandling();
        this.seedInitialData();
    }

    setupDatabase() {
        const dbPath = path.join(__dirname, 'database');
        this.listsDb = new JsonDatabase(dbPath, 'lists');
        console.log('List Service: Banco NoSQL inicializado');
    }

    async seedInitialData() {
        // Aguardar inicialização
        setTimeout(async () => {
            try {
                const existingLists = await this.listsDb.find();
                
                if (existingLists.length === 0) {
                    console.log('List Service: Nenhum dado inicial, aguardando criação via API.');
                }
            } catch (error) {
                console.error('Erro ao verificar dados iniciais:', error);
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
                const listCount = await this.listsDb.count();
                res.json({
                    service: this.serviceName,
                    status: 'healthy',
                    timestamp: new Date().toISOString(),
                    database: {
                        type: 'JSON-NoSQL',
                        listCount: listCount
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
                service: 'List Service',
                description: 'Gerenciamento de listas de compras',
                endpoints: [
                    'GET /lists',
                    'POST /lists',
                    'GET /lists/:id',
                    'PUT /lists/:id',
                    'DELETE /lists/:id',
                    'POST /lists/:id/items',
                    'PUT /lists/:id/items/:itemId',
                    'DELETE /lists/:id/items/:itemId',
                    'GET /lists/:id/summary'
                ]
            });
        });

        // Rotas Principais (Protegidas)
        // Middleware de autenticação aplicado a todas as rotas de negócio
        this.app.use('/lists', this.authMiddleware.bind(this));

        // Listas
        this.app.post('/lists', this.createList.bind(this));
        this.app.get('/lists', this.getLists.bind(this));
        this.app.get('/lists/:id', this.getList.bind(this));
        this.app.put('/lists/:id', this.updateList.bind(this));
        this.app.delete('/lists/:id', this.deleteList.bind(this));
        this.app.get('/lists/:id/summary', this.getListSummary.bind(this));

        // Itens da Lista
        this.app.post('/lists/:id/items', this.addListItem.bind(this));
        this.app.put('/lists/:id/items/:itemId', this.updateListItem.bind(this));
        this.app.delete('/lists/:id/items/:itemId', this.removeListItem.bind(this));

        // Search route (global search uses generic search endpoint)
        this.app.get('/search', this.authMiddleware.bind(this), this.searchLists.bind(this));
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
            console.error('List Service Error:', error);
            res.status(500).json({
                success: false,
                message: 'Erro interno do serviço',
                service: this.serviceName
            });
        });
    }

    // Auth middleware
    async authMiddleware(req, res, next) {
        const authHeader = req.header('Authorization');
        
        if (!authHeader?.startsWith('Bearer ')) {
            return res.status(401).json({ success: false, message: 'Token obrigatório' });
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
                res.status(401).json({ success: false, message: 'Token inválido' });
            }
        } catch (error) {
            res.status(503).json({ success: false, message: 'Serviço de autenticação indisponível' });
        }
    }

    // --- Lógica de Negócio de Listas ---

    // POST /lists
    async createList(req, res) {
        try {
            const { name, description, status = 'active' } = req.body;

            if (!name) {
                return res.status(400).json({ success: false, message: 'Nome da lista é obrigatório' });
            }

            const now = new Date().toISOString();
            const newList = await this.listsDb.create({
                id: uuidv4(),
                userId: req.user.id, // Regra: Vincular ao usuário logado
                name,
                description: description || '',
                status, // active, completed, archived
                items: [], // Array de itens vazio
                summary: {
                    totalItems: 0,
                    purchasedItems: 0,
                    estimatedTotal: 0
                },
                createdAt: now,
                updatedAt: now
            });

            res.status(201).json({ success: true, message: 'Lista criada', data: newList });
        } catch (error) {
            console.error('Erro ao criar lista:', error);
            res.status(500).json({ success: false, message: 'Erro interno' });
        }
    }

    // GET /lists (Listar apenas listas do usuário)
    async getLists(req, res) {
        try {
            const { status } = req.query;
            
            // Regra: Filtrar por userId
            const filter = { userId: req.user.id };
            if (status) filter.status = status;

            const lists = await this.listsDb.find(filter, { sort: { updatedAt: -1 } });

            res.json({ success: true, data: lists });
        } catch (error) {
            res.status(500).json({ success: false, message: 'Erro ao buscar listas' });
        }
    }

    // GET /lists/:id
    async getList(req, res) {
        try {
            const { id } = req.params;
            const list = await this.listsDb.findById(id);

            // Validação de acesso (apenas dono)
            if (!list || list.userId !== req.user.id) {
                return res.status(404).json({ success: false, message: 'Lista não encontrada' });
            }

            res.json({ success: true, data: list });
        } catch (error) {
            res.status(500).json({ success: false, message: 'Erro ao buscar lista' });
        }
    }

    // PUT /lists/:id (Atualizar metadados)
    async updateList(req, res) {
        try {
            const { id } = req.params;
            const { name, description, status } = req.body;

            const list = await this.listsDb.findById(id);
            if (!list || list.userId !== req.user.id) {
                return res.status(404).json({ success: false, message: 'Lista não encontrada' });
            }

            const updates = { updatedAt: new Date().toISOString() };
            if (name) updates.name = name;
            if (description !== undefined) updates.description = description;
            if (status) updates.status = status;

            const updatedList = await this.listsDb.update(id, updates);
            res.json({ success: true, message: 'Lista atualizada', data: updatedList });
        } catch (error) {
            res.status(500).json({ success: false, message: 'Erro ao atualizar lista' });
        }
    }

    // DELETE /lists/:id
    async deleteList(req, res) {
        try {
            const { id } = req.params;
            const list = await this.listsDb.findById(id);

            if (!list || list.userId !== req.user.id) {
                return res.status(404).json({ success: false, message: 'Lista não encontrada' });
            }

            await this.listsDb.delete(id);
            res.json({ success: true, message: 'Lista removida com sucesso' });
        } catch (error) {
            res.status(500).json({ success: false, message: 'Erro ao deletar lista' });
        }
    }

    // --- Lógica de Negócio de Itens na Lista ---

    // POST /lists/:id/items
    async addListItem(req, res) {
        try {
            const { id } = req.params;
            const { itemId, quantity = 1, notes } = req.body;

            const list = await this.listsDb.findById(id);
            if (!list || list.userId !== req.user.id) {
                return res.status(404).json({ success: false, message: 'Lista não encontrada' });
            }

            // Buscar dados no Item Service para preencher defaults
            let itemData = { 
                name: 'Item Desconhecido', 
                averagePrice: 0, 
                unit: 'un' 
            };

            if (itemId) {
                try {
                    const itemService = serviceRegistry.discover('item-service');
                    const response = await axios.get(`${itemService.url}/items/${itemId}`, { timeout: 3000 });
                    if (response.data.success) {
                        const originalItem = response.data.data;
                        itemData = {
                            name: originalItem.name,
                            averagePrice: originalItem.averagePrice || 0,
                            unit: originalItem.unit || 'un'
                        };
                    }
                } catch (e) {
                    console.warn(`Não foi possível buscar detalhes do item ${itemId}: ${e.message}`);
                }
            } else {
                 // Permitir item avulso sem ID (texto livre)
                 itemData.name = req.body.itemName || 'Item Avulso';
                 itemData.averagePrice = req.body.estimatedPrice || 0;
            }

            const newItem = {
                itemId: itemId || uuidv4(), // Se não vier do catálogo, gera ID temporário
                itemName: itemData.name,
                quantity: parseFloat(quantity),
                unit: itemData.unit,
                estimatedPrice: parseFloat(itemData.averagePrice),
                purchased: false,
                notes: notes || '',
                addedAt: new Date().toISOString()
            };

            // Adicionar ao array
            const updatedItems = [...list.items, newItem];
            
            // Recalcular resumo
            const summary = this.calculateSummary(updatedItems);

            const updatedList = await this.listsDb.update(id, {
                items: updatedItems,
                summary,
                updatedAt: new Date().toISOString()
            });

            res.status(201).json({ success: true, message: 'Item adicionado', data: updatedList });

        } catch (error) {
            console.error('Erro ao adicionar item:', error);
            res.status(500).json({ success: false, message: 'Erro ao adicionar item' });
        }
    }

    // PUT /lists/:id/items/:itemId (Atualizar item ou marcar como comprado)
    async updateListItem(req, res) {
        try {
            const { id, itemId } = req.params;
            const { quantity, purchased, estimatedPrice, notes } = req.body;

            const list = await this.listsDb.findById(id);
            if (!list || list.userId !== req.user.id) return res.status(404).json({ message: 'Lista não encontrada' });

            const itemIndex = list.items.findIndex(i => i.itemId === itemId);
            if (itemIndex === -1) return res.status(404).json({ message: 'Item não encontrado na lista' });

            // Atualizar campos
            const item = list.items[itemIndex];
            if (quantity !== undefined) item.quantity = parseFloat(quantity);
            if (purchased !== undefined) item.purchased = purchased;
            if (estimatedPrice !== undefined) item.estimatedPrice = parseFloat(estimatedPrice);
            if (notes !== undefined) item.notes = notes;

            list.items[itemIndex] = item;
            
            // Recalcular
            const summary = this.calculateSummary(list.items);

            const updatedList = await this.listsDb.update(id, {
                items: list.items,
                summary,
                updatedAt: new Date().toISOString()
            });

            res.json({ success: true, message: 'Item atualizado', data: updatedList });

        } catch (error) {
            res.status(500).json({ success: false, message: 'Erro ao atualizar item' });
        }
    }

    // DELETE /lists/:id/items/:itemId
    async removeListItem(req, res) {
        try {
            const { id, itemId } = req.params;

            const list = await this.listsDb.findById(id);
            if (!list || list.userId !== req.user.id) return res.status(404).json({ message: 'Lista não encontrada' });

            const updatedItems = list.items.filter(i => i.itemId !== itemId);
            const summary = this.calculateSummary(updatedItems);

            const updatedList = await this.listsDb.update(id, {
                items: updatedItems,
                summary,
                updatedAt: new Date().toISOString()
            });

            res.json({ success: true, message: 'Item removido', data: updatedList });

        } catch (error) {
            res.status(500).json({ success: false, message: 'Erro ao remover item' });
        }
    }

    // GET /lists/:id/summary
    async getListSummary(req, res) {
        try {
            const { id } = req.params;
            const list = await this.listsDb.findById(id);

            if (!list || list.userId !== req.user.id) return res.status(404).json({ message: 'Lista não encontrada' });

            res.json({ success: true, data: list.summary });
        } catch (error) {
            res.status(500).json({ success: false, message: 'Erro ao buscar resumo' });
        }
    }

    // --- Helpers ---

    calculateSummary(items) {
        return items.reduce((acc, item) => {
            acc.totalItems += 1; // Ou += item.quantity se preferir contar unidades
            if (item.purchased) acc.purchasedItems += 1;
            acc.estimatedTotal += (item.estimatedPrice * item.quantity);
            return acc;
        }, { totalItems: 0, purchasedItems: 0, estimatedTotal: 0 });
    }

    // Search Lists (Busca global de listas do usuário)
    async searchLists(req, res) {
        try {
            const { q } = req.query;
            if (!q) return res.status(400).json({ message: 'Query obrigatória' });

            // Busca full text mas filtra manualmente pelo usuário depois
            let lists = await this.listsDb.search(q, ['name', 'description']);
            
            // Filtro de segurança: usuário só vê suas listas
            lists = lists.filter(l => l.userId === req.user.id);

            res.json({
                success: true,
                data: { query: q, results: lists, total: lists.length }
            });
        } catch (error) {
            res.status(500).json({ message: 'Erro na busca' });
        }
    }

    // Registro no Service Registry
    registerWithRegistry() {
        serviceRegistry.register(this.serviceName, {
            url: this.serviceUrl,
            version: '1.0.0',
            database: 'JSON-NoSQL',
            endpoints: ['/health', '/lists']
        });
    }

    startHealthReporting() {
        setInterval(() => {
            serviceRegistry.updateHealth(this.serviceName, true);
        }, 30000);
    }

    start() {
        this.app.listen(this.port, () => {
            console.log('=====================================');
            console.log(`List Service iniciado na porta ${this.port}`);
            console.log(`URL: ${this.serviceUrl}`);
            console.log('=====================================');
            
            this.registerWithRegistry();
            this.startHealthReporting();
        });
    }
}

// Start service
if (require.main === module) {
    const listService = new ListService();
    listService.start();

    // Graceful shutdown
    const cleanup = () => {
        serviceRegistry.unregister('list-service');
        process.exit(0);
    };
    process.on('SIGTERM', cleanup);
    process.on('SIGINT', cleanup);
}

module.exports = ListService;