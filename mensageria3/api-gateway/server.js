const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const axios = require('axios');

// Importar registro de serviços
const serviceRegistry = require('../shared/serviceRegistry');

class APIGateway {
    constructor() {
        this.app = express();
        this.port = process.env.PORT || 3000;

        // Circuit breaker simples
        this.circuitBreakers = new Map();

        this.setupMiddleware();
        this.setupRoutes();
        this.setupErrorHandling();
        
        // Aguardar 3 segundos antes de iniciar verificações de saúde para permitir que os serviços iniciem
        setTimeout(() => {
            this.startHealthChecks();
        }, 3000); 
    }

    setupMiddleware() {
        this.app.use(helmet());
        this.app.use(cors());
        this.app.use(morgan('combined'));
        this.app.use(express.json());
        this.app.use(express.urlencoded({ extended: true }));

        // Cabeçalhos do Gateway
        this.app.use((req, res, next) => {
            res.setHeader('X-Gateway', 'api-gateway');
            res.setHeader('X-Gateway-Version', '1.0.0');
            res.setHeader('X-Architecture', 'Microsservicos-NoSQL');
            next();
        });

        // Log de requisições
        this.app.use((req, res, next) => {
            console.log(`${req.method} ${req.originalUrl} - ${req.ip}`);
            next();
        });
    }

    setupRoutes() {
        // Verificação de saúde do Gateway
        this.app.get('/health', (req, res) => {
            const services = serviceRegistry.listServices();
            res.json({
                service: 'api-gateway',
                status: 'saudavel',
                timestamp: new Date().toISOString(),
                architecture: 'Microsserviços com NoSQL',
                services: services,
                serviceCount: Object.keys(services).length
            });
        });

        // Informações do Gateway
        this.app.get('/', (req, res) => {
            res.json({
                service: 'API Gateway',
                version: '1.0.0',
                description: 'Gateway para microsserviços com NoSQL',
                architecture: 'Microsserviços com bancos de dados NoSQL',
                database_approach: 'Banco de dados por Serviço (JSON-NoSQL)',
                endpoints: {
                    auth: '/api/auth/*',
                    users: '/api/users/*',
                    lists: '/api/lists/*',
                    items: '/api/items/*',
                    health: '/health',
                    registry: '/registry',
                    dashboard: '/api/dashboard',
                    search: '/api/search'
                },
                services: serviceRegistry.listServices()
            });
        });

        // Endpoint de registro de serviços
        this.app.get('/registry', (req, res) => {
            const services = serviceRegistry.listServices();
            res.json({
                success: true,
                services: services,
                count: Object.keys(services).length,
                timestamp: new Date().toISOString()
            });
        });

        // Endpoint de depuração para solução de problemas
        this.app.get('/debug/services', (req, res) => {
            if (serviceRegistry.debugListServices) serviceRegistry.debugListServices();
            
            res.json({
                success: true,
                services: serviceRegistry.listServices(),
                stats: serviceRegistry.getStats ? serviceRegistry.getStats() : 'Indisponível'
            });
        });

        // --- Rotas de Serviços (Roteamento) ---
        
        // 1. Rota de Autenticação -> User Service
        this.app.use('/api/auth', (req, res, next) => {
            // Ex: /api/auth/login -> User Service recebe /login
            this.proxyRequest('user-service', '/api/auth', req, res, next);
        });

        // 2. Rota de Usuários -> User Service
        this.app.use('/api/users', (req, res, next) => {
            this.proxyRequest('user-service', '/api/users', req, res, next);
        });

        // 3. Rota de Listas -> List Service
        this.app.use('/api/lists', (req, res, next) => {
            this.proxyRequest('list-service', '/api/lists', req, res, next);
        });

        // 4. Rota de Itens -> Item Service
        this.app.use('/api/items', (req, res, next) => {
            this.proxyRequest('item-service', '/api/items', req, res, next);
        });

        // --- Endpoints Agregados ---
        this.app.get('/api/dashboard', this.getDashboard.bind(this));
        this.app.get('/api/search', this.globalSearch.bind(this));
    }

    setupErrorHandling() {
        // Manipulador 404
        this.app.use('*', (req, res) => {
            res.status(404).json({
                success: false,
                message: 'Endpoint não encontrado',
                service: 'api-gateway',
                availableEndpoints: {
                    auth: '/api/auth',
                    users: '/api/users',
                    items: '/api/items',
                    lists: '/api/lists',
                    dashboard: '/api/dashboard',
                    search: '/api/search'
                }
            });
        });

        // Manipulador de Erros Global
        this.app.use((error, req, res, next) => {
            console.error('Erro no Gateway:', error);
            res.status(500).json({
                success: false,
                message: 'Erro Interno do Gateway',
                service: 'api-gateway'
            });
        });
    }

    // Proxy de requisição para serviço
    async proxyRequest(serviceName, prefix, req, res, next) {
        try {
            console.log(`🔄 Proxy request: ${req.method} ${req.originalUrl} -> ${serviceName}`);

            // Verificar circuit breaker (Recurso Obrigatório)
            if (this.isCircuitOpen(serviceName)) {
                console.log(`⚡ Circuit breaker aberto para ${serviceName}`);
                return res.status(503).json({
                    success: false,
                    message: `Serviço ${serviceName} temporariamente indisponível`,
                    service: serviceName
                });
            }

            // Descobrir serviço (Service Discovery)
            let service;
            try {
                service = serviceRegistry.discover(serviceName);
            } catch (error) {
                console.error(`❌ Erro na descoberta do serviço ${serviceName}:`, error.message);
                return res.status(503).json({
                    success: false,
                    message: `Serviço ${serviceName} não encontrado`,
                    service: serviceName
                });
            }

            // Construir URL de destino dinamicamente
            const originalPath = req.originalUrl;
            
            // Remove o prefixo (ex: /api/auth) para obter o caminho relativo (ex: /login)
            let targetPath = originalPath;
            if (originalPath.startsWith(prefix)) {
                targetPath = originalPath.substring(prefix.length);
            }

            // Garante que o caminho comece com /
            if (!targetPath.startsWith('/')) {
                targetPath = '/' + targetPath;
            }
            
            // Se o caminho ficar vazio ou for apenas "/", alguns serviços podem precisar de ajuste
            if (targetPath === '') targetPath = '/';

            // Ajuste específico: Se a chamada for para a raiz do serviço, e o serviço esperar o recurso na raiz
            // Ex: GET /api/users -> User Service GET /users
            // Ex: GET /api/items -> Item Service GET /items
            // O código abaixo garante que a raiz não seja perdida se o serviço não responder em '/'
            if (targetPath === '/' && serviceName === 'user-service' && prefix === '/api/users') targetPath = '/users';
            if (targetPath === '/' && serviceName === 'item-service' && prefix === '/api/items') targetPath = '/items';
            if (targetPath === '/' && serviceName === 'list-service' && prefix === '/api/lists') targetPath = '/lists';
            
            // Nota para Auth: /api/auth/login vira /login no User Service (que é o padrão geralmente)

            const targetUrl = `${service.url}${targetPath}`;
            console.log(`🎯 URL de Destino: ${targetUrl}`);

            // Configurar requisição
            const config = {
                method: req.method,
                url: targetUrl,
                headers: { ...req.headers },
                timeout: 10000,
                validateStatus: function (status) {
                    return status < 500; // Aceitar todos os status < 500
                }
            };

            // Adicionar corpo para requisições POST/PUT/PATCH
            if (['POST', 'PUT', 'PATCH'].includes(req.method)) {
                config.data = req.body;
            }

            // Adicionar parâmetros de consulta
            if (Object.keys(req.query).length > 0) {
                config.params = req.query;
            }

            // Remover cabeçalhos problemáticos
            delete config.headers.host;
            delete config.headers['content-length'];

            // Fazer requisição
            const response = await axios(config);

            // Resetar circuit breaker em caso de sucesso
            this.resetCircuitBreaker(serviceName);

            // Retornar resposta
            res.status(response.status).json(response.data);

        } catch (error) {
            // Registrar falha (Circuit Breaker)
            this.recordFailure(serviceName);

            console.error(`❌ Erro de proxy para ${serviceName}:`, error.message);

            if (error.code === 'ECONNREFUSED' || error.code === 'ETIMEDOUT') {
                res.status(503).json({
                    success: false,
                    message: `Serviço ${serviceName} indisponível`,
                    service: serviceName,
                    error: error.code
                });
            } else if (error.response) {
                res.status(error.response.status).json(error.response.data);
            } else {
                res.status(500).json({
                    success: false,
                    message: 'Erro interno do gateway',
                    service: 'api-gateway',
                    error: error.message
                });
            }
        }
    }

    // Circuit Breaker (Recurso Obrigatório)
    isCircuitOpen(serviceName) {
        const breaker = this.circuitBreakers.get(serviceName);
        if (!breaker) return false;

        const now = Date.now();

        // Verificar se o circuito deve ser meio-aberto
        if (breaker.isOpen && (now - breaker.lastFailure) > 30000) { // 30 segundos
            breaker.isOpen = false;
            breaker.isHalfOpen = true;
            console.log(`Circuit breaker meio-aberto para ${serviceName}`);
            return false;
        }

        return breaker.isOpen;
    }

    recordFailure(serviceName) {
        let breaker = this.circuitBreakers.get(serviceName) || {
            failures: 0,
            isOpen: false,
            isHalfOpen: false,
            lastFailure: null
        };

        breaker.failures++;
        breaker.lastFailure = Date.now();

        // Abrir circuito após 3 falhas (Recurso Obrigatório)
        if (breaker.failures >= 3) {
            breaker.isOpen = true;
            breaker.isHalfOpen = false;
            console.log(`Circuit breaker aberto para ${serviceName}`);
        }

        this.circuitBreakers.set(serviceName, breaker);
    }

    resetCircuitBreaker(serviceName) {
        const breaker = this.circuitBreakers.get(serviceName);
        if (breaker) {
            breaker.failures = 0;
            breaker.isOpen = false;
            breaker.isHalfOpen = false;
        }
    }

    // Dashboard agregado (Endpoint Obrigatório)
    async getDashboard(req, res) {
        try {
            const authHeader = req.header('Authorization');

            if (!authHeader) {
                return res.status(401).json({
                    success: false,
                    message: 'Token de autenticação obrigatório'
                });
            }

            // Buscar dados de múltiplos serviços em paralelo
            const [userResponse, listsResponse, itemsResponse] = await Promise.allSettled([
                this.callService('user-service', '/users', 'GET', authHeader, { limit: 5 }),
                this.callService('list-service', '/lists', 'GET', null, { limit: 5 }),
                this.callService('item-service', '/items', 'GET', null, {})
            ]);

            const dashboard = {
                timestamp: new Date().toISOString(),
                architecture: 'Microsserviços com NoSQL',
                services_status: serviceRegistry.listServices(),
                data: {
                    users: {
                        available: userResponse.status === 'fulfilled',
                        data: userResponse.status === 'fulfilled' ? userResponse.value.data : null
                    },
                    list: {
                        available: listsResponse.status === 'fulfilled',
                        data: listsResponse.status === 'fulfilled' ? listsResponse.value.data : null
                    },
                    items: {
                        available: itemsResponse.status === 'fulfilled',
                        data: itemsResponse.status === 'fulfilled' ? itemsResponse.value.data : null
                    }
                }
            };

            res.json({
                success: true,
                data: dashboard
            });

        } catch (error) {
            console.error('Erro no dashboard:', error);
            res.status(500).json({
                success: false,
                message: 'Erro ao agregar dados do dashboard'
            });
        }
    }

    // Busca global entre serviços (Endpoint Obrigatório)
    async globalSearch(req, res) {
        try {
            const { q } = req.query;

            if (!q) {
                return res.status(400).json({
                    success: false,
                    message: 'Parâmetro de busca "q" é obrigatório'
                });
            }

            const authHeader = req.header('Authorization');
            
            // Busca em múltiplos serviços
            const searches = [
                this.callService('list-service', '/search', 'GET', null, { q }),
                this.callService('item-service', '/search', 'GET', null, { q })
            ];

            if (authHeader) {
                searches.push(
                    this.callService('user-service', '/search', 'GET', authHeader, { q, limit: 5 })
                );
            }

            const results = await Promise.allSettled(searches);
            
            const listResults = results[0];
            const itemResults = results[1];
            const userResults = authHeader ? results[2] : null;

            const responseData = {
                query: q,
                lists: {
                    available: listResults.status === 'fulfilled',
                    results: listResults.status === 'fulfilled' ? (listResults.value.data?.results || []) : []
                },
                items: {
                    available: itemResults.status === 'fulfilled',
                    results: itemResults.status === 'fulfilled' ? (itemResults.value.data?.results || []) : []
                }
            };

            if (userResults) {
                responseData.users = {
                    available: userResults.status === 'fulfilled',
                    results: userResults.status === 'fulfilled' ? (userResults.value.data?.results || []) : []
                };
            }

            res.json({
                success: true,
                data: responseData
            });

        } catch (error) {
            console.error('Erro na busca global:', error);
            res.status(500).json({
                success: false,
                message: 'Erro na busca'
            });
        }
    }

    // Auxiliar para chamar serviços internamente
    async callService(serviceName, path, method = 'GET', authHeader = null, params = {}) {
        try {
            const service = serviceRegistry.discover(serviceName);

            const config = {
                method,
                url: `${service.url}${path}`,
                timeout: 5000
            };

            if (authHeader) {
                config.headers = { Authorization: authHeader };
            }

            if (method === 'GET' && Object.keys(params).length > 0) {
                config.params = params;
            }

            const response = await axios(config);
            return response.data;
        } catch (error) {
            throw new Error(`Falha ao chamar ${serviceName}: ${error.message}`);
        }
    }

    // Health checks automáticos (Recurso Obrigatório)
    startHealthChecks() {
        // A cada 30 segundos
        setInterval(async () => {
            await serviceRegistry.performHealthChecks();
        }, 30000);

        // Execução inicial
        setTimeout(async () => {
            await serviceRegistry.performHealthChecks();
        }, 5000);
    }

    start() {
        this.app.listen(this.port, () => {
            console.log('=====================================');
            console.log(`API Gateway iniciado na porta ${this.port}`);
            console.log('Rotas Configuradas:');
            console.log(' > /api/auth/* -> User Service');
            console.log(' > /api/users/* -> User Service');
            console.log(' > /api/lists/* -> List Service');
            console.log(' > /api/items/* -> Item Service');
            console.log(' > /api/dashboard (Agregado)');
            console.log(' > /api/search    (Agregado)');
            console.log('=====================================');
        });
    }
}

// Iniciar gateway
if (require.main === module) {
    const gateway = new APIGateway();
    gateway.start();
}

module.exports = APIGateway;