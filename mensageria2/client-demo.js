const axios = require('axios');

class MicroservicesClient {
    constructor(gatewayUrl = 'http://127.0.0.1:3000') {
        this.gatewayUrl = gatewayUrl;
        this.authToken = null;
        this.user = null;
        
        // Configurar axios
        this.api = axios.create({
            baseURL: gatewayUrl,
            timeout: 10000,
            family: 4  // Forçar IPv4
        });

        // Interceptor para adicionar token automaticamente
        this.api.interceptors.request.use(config => {
            if (this.authToken) {
                config.headers.Authorization = `Bearer ${this.authToken}`;
            }
            return config;
        });

        // Interceptor para log de erros
        this.api.interceptors.response.use(
            response => response,
            error => {
                // Tratamento de erro silencioso para fluxos esperados (ex: login falhar)
                if (error.response && error.response.status < 500) {
                    return Promise.reject(error);
                }
                console.error('Erro na requisição:', {
                    url: error.config?.url,
                    method: error.config?.method,
                    status: error.response?.status,
                    message: error.response?.data?.message || error.message
                });
                return Promise.reject(error);
            }
        );
    }

    // --- USER SERVICE ---

    async register(userData) {
        try {
            console.log('\nRegistrando usuário...');
            // CORREÇÃO: Usar /api/users/auth para que o gateway envie /auth/register para o serviço
            const response = await this.api.post('/api/users/auth/register', userData);
            
            if (response.data.success) {
                this.authToken = response.data.data.token;
                this.user = response.data.data.user;
                console.log(`✅ Usuário registrado: ${this.user.username} (ID: ${this.user.id})`);
                return response.data;
            }
        } catch (error) {
            const message = error.response?.data?.message || error.message;
            console.log(`❌ Erro no registro: ${message}`);
            throw error;
        }
    }

    async login(credentials) {
        try {
            console.log('\nFazendo login...');
            // CORREÇÃO: Usar /api/users/auth para que o gateway envie /auth/login para o serviço
            const response = await this.api.post('/api/users/auth/login', credentials);
            
            if (response.data.success) {
                this.authToken = response.data.data.token;
                this.user = response.data.data.user;
                console.log(`✅ Login realizado: ${this.user.username}`);
                return response.data;
            }
        } catch (error) {
            const message = error.response?.data?.message || error.message;
            console.log(`❌ Erro no login: ${message}`);
            throw error;
        }
    }

    // --- ITEM SERVICE ---

    async getItems(filters = {}) {
        try {
            console.log('\nBuscando itens no catálogo...');
            const response = await this.api.get('/api/items', { params: filters });
            
            if (response.data.success) {
                const items = response.data.data;
                console.log(`📋 Encontrados ${items.length} itens no catálogo global:`);
                items.forEach((item, index) => {
                    console.log(`   ${index + 1}. ${item.name} - R$ ${item.averagePrice}/${item.unit} (${item.category})`);
                });
                return items; // Retorna o array direto para uso
            }
            return [];
        } catch (error) {
            console.log('Erro ao buscar itens:', error.message);
            return [];
        }
    }

    async createItem(itemData) {
        try {
            console.log(`\nCriando novo item: ${itemData.name}...`);
            const response = await this.api.post('/api/items', itemData);
            if (response.data.success) {
                console.log(`✅ Item criado: ${response.data.data.name}`);
                return response.data.data;
            }
        } catch (error) {
            console.log(`❌ Falha ao criar item: ${error.response?.data?.message || error.message}`);
        }
    }

    // --- LIST SERVICE ---

    async getLists() {
        try {
            console.log('\nBuscando suas listas de compras...');
            const response = await this.api.get('/api/lists');
            if (response.data.success) {
                const lists = response.data.data;
                console.log(`📑 Você possui ${lists.length} listas:`);
                lists.forEach(list => {
                    const total = list.summary?.estimatedTotal || 0;
                    console.log(`   - ${list.name} (${list.status}): ${list.items.length} itens (Est: R$ ${total.toFixed(2)})`);
                });
                return lists;
            }
        } catch (error) {
            console.log('Erro ao buscar listas:', error.message);
        }
    }

    async createList(listData) {
        try {
            console.log(`\nCriando lista: "${listData.name}"...`);
            const response = await this.api.post('/api/lists', listData);
            if (response.data.success) {
                console.log(`✅ Lista criada com ID: ${response.data.data.id}`);
                return response.data.data;
            }
        } catch (error) {
            console.log(`❌ Erro ao criar lista: ${error.response?.data?.message || error.message}`);
        }
    }

    async addItemToList(listId, itemData) {
        try {
            console.log(`   ➕ Adicionando "${itemData.notes || 'item'}" à lista...`);
            const response = await this.api.post(`/api/lists/${listId}/items`, itemData);
            if (response.data.success) {
                // console.log(`      Item adicionado com sucesso.`);
                return response.data.data;
            }
        } catch (error) {
            console.log(`      ❌ Erro ao adicionar item: ${error.response?.data?.message}`);
        }
    }

    async getListSummary(listId) {
        try {
            console.log('\nObtendo resumo da lista...');
            const response = await this.api.get(`/api/lists/${listId}/summary`);
            if (response.data.success) {
                const summary = response.data.data;
                console.log('💰 Resumo Financeiro:');
                console.log(`   Itens Totais: ${summary.totalItems}`);
                console.log(`   Itens Comprados: ${summary.purchasedItems}`);
                console.log(`   Total Estimado: R$ ${summary.estimatedTotal.toFixed(2)}`);
                return summary;
            }
        } catch (error) {
            console.log('Erro ao obter resumo:', error.message);
        }
    }

    // --- AGGREGATED SERVICES ---

    async getDashboard() {
        try {
            console.log('\n📊 Carregando Dashboard do Sistema...');
            const response = await this.api.get('/api/dashboard');
            
            if (response.data.success) {
                const db = response.data.data;
                console.log(`   Arquitetura: ${db.architecture}`);
                console.log('   Status dos Microsserviços:');
                
                Object.entries(db.services_status).forEach(([name, info]) => {
                    const statusIcon = info.healthy ? '🟢' : '🔴';
                    console.log(`     ${statusIcon} ${name}`);
                });

                console.log('   Dados Agregados:');
                console.log(`     Usuários: ${db.data.users.available ? 'Disponível' : 'Indisponível'}`);
                console.log(`     Listas: ${db.data.list.available ? 'Disponível' : 'Indisponível'}`);
                console.log(`     Itens: ${db.data.items.available ? 'Disponível' : 'Indisponível'}`);
            }
        } catch (error) {
            console.log('Erro ao carregar dashboard:', error.message);
        }
    }

    async globalSearch(query) {
        try {
            console.log(`\n🔍 Busca Global por: "${query}"...`);
            const response = await this.api.get('/api/search', { params: { q: query } });
            
            if (response.data.success) {
                const res = response.data.data;
                
                if (res.items && res.items.results.length > 0) {
                    console.log(`   📦 Itens de Mercado encontrados: ${res.items.results.length}`);
                    res.items.results.forEach(i => console.log(`      - ${i.name} (${i.brand})`));
                } else {
                    console.log('   📦 Nenhum item de mercado encontrado.');
                }

                if (res.lists && res.lists.results.length > 0) {
                    console.log(`   📑 Listas encontradas: ${res.lists.results.length}`);
                    res.lists.results.forEach(l => console.log(`      - ${l.name}`));
                } else {
                    console.log('   📑 Nenhuma lista encontrada.');
                }
            }
        } catch (error) {
            console.log('Erro na busca global:', error.message);
        }
    }

    // Helper
    delay(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }

    // --- DEMO FLOW ---
    async runDemo() {
        console.log('=============================================');
        console.log('🚀 DEMO: Sistema de Listas com Microsserviços');
        console.log('=============================================');

        try {
            // CORREÇÃO: Dashboard requer autenticação, movido para depois do login
            // await this.getDashboard(); 

            // 1. Autenticação
            const userId = Date.now();
            const userData = {
                email: `usuario${userId}@demo.com`,
                username: `user${userId}`,
                password: 'password123',
                firstName: 'Demo',
                lastName: 'User'
            };

            // Tenta registrar, se falhar (ex: reiniciar demo rapido), tenta login
            try {
                await this.register(userData);
            } catch (e) {
                await this.login({ identifier: userData.email, password: userData.password });
            }
            
            if (!this.authToken) {
                console.log('⛔ Abortando demo: Falha na autenticação.');
                return;
            }
            await this.delay(1000);

            // 2. Verificar Dashboard Inicial (Agora autenticado)
            await this.getDashboard();
            await this.delay(1000);

            // 3. Catálogo de Itens (Item Service)
            // Listar itens existentes (seed data)
            const items = await this.getItems({ limit: 5 });
            
            // Criar um item novo que não existe no mercado
            await this.createItem({
                name: 'Café Especial Torra Média',
                category: 'Bebidas',
                brand: 'CoffeeLovers',
                unit: 'pct',
                averagePrice: 22.50,
                description: 'Café artesanal 500g'
            });
            await this.delay(1000);

            // 4. Busca Global (API Gateway Aggregation)
            await this.globalSearch('cafe'); // Deve achar o item criado
            await this.delay(1000);

            // 5. Gestão de Listas (List Service + Integração Item Service)
            const myList = await this.createList({
                name: 'Café da Tarde da Empresa',
                description: 'Comprar itens para a reunião de sexta',
                status: 'active'
            });

            if (myList) {
                console.log('\n📝 Preenchendo a lista...');
                
                // Adicionar itens do catálogo (usando IDs reais recuperados no passo 3)
                if (items.length > 0) {
                    // Adiciona o primeiro item encontrado (ex: Arroz ou Leite)
                    await this.addItemToList(myList.id, {
                        itemId: items[0].id,
                        quantity: 2,
                        notes: 'Marca preferencial'
                    });
                }

                // Adicionar item por busca textual (simulando usuário que não clicou no catálogo)
                // O backend vai tentar achar detalhes se passarmos ID, ou criar item avulso
                await this.addItemToList(myList.id, {
                    itemName: 'Pão de Queijo',
                    quantity: 10,
                    estimatedPrice: 1.50, // Preço manual
                    unit: 'un',
                    notes: 'Quentinho se possível'
                });

                await this.delay(1000);

                // 6. Resumo e Totais
                await this.getListSummary(myList.id);
                
                // 7. Listar todas as listas
                await this.getLists();
            }

            console.log('\n=============================================');
            console.log('✅ Demo concluída com sucesso!');
            console.log('=============================================');

        } catch (error) {
            console.error('\n❌ Erro crítico na execução da demo:', error.message);
        }
    }
}

// Executar
if (require.main === module) {
    const client = new MicroservicesClient();
    client.runDemo();
}

module.exports = MicroservicesClient;