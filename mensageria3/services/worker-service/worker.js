// services/worker-service/worker.js
const messageBroker = require('../../shared/MessageBroker');

console.log('👷 Worker Service iniciado...');

const start = async () => {
    // Conectar ao RabbitMQ
    await messageBroker.connect();

    // --- CONSUMER A: Log/Notification Service ---
    // Escuta tudo sobre checkout (list.checkout.#)
    await messageBroker.subscribe(
        'shopping_events',           // Exchange
        'list.checkout.#',           // Routing Key (Wildcard)
        'notification_queue',        // Nome da fila (Durável/Persistente)
        (msg) => {
            console.log(`\n📧 [Consumer A - Notificação]`);
            console.log(`   Processando envio de email para: ${msg.userEmail || 'Usuário Desconhecido'}`);
            console.log(`   Assunto: Comprovante da lista ${msg.listId}`);
            console.log(`   Status: Enviado ✅`);
        }
    );

    // --- CONSUMER B: Analytics Service ---
    // Escuta apenas checkouts completados para somar totais
    await messageBroker.subscribe(
        'shopping_events',
        'list.checkout.completed',
        'analytics_queue',           // Fila diferente = processamento paralelo
        (msg) => {
            console.log(`\n📊 [Consumer B - Analytics]`);
            console.log(`   Registrando venda no dashboard...`);
            console.log(`   + R$ ${msg.total?.toFixed(2) || 0.00} em volume de vendas.`);
            console.log(`   Itens movidos: ${msg.itemsCount}`);
        }
    );
};

start().catch(err => console.error('Erro fatal no worker:', err));