const amqp = require('amqplib');
const path = require('path');

// Configura o dotenv para procurar o arquivo .env na raiz do projeto
// __dirname é a pasta 'shared', então '../.env' aponta para a raiz 'mensageria2'
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });

class MessageBroker {
    constructor() {
        this.connection = null;
        this.channel = null;
        this.url = process.env.RABBITMQ_URL || 'amqp://localhost';
    }

    async connect() {
        if (this.connection) return;

        try {
            console.log(`🐰 Conectando ao RabbitMQ em ${this.url.split('@')[1] || 'localhost'}...`);
            this.connection = await amqp.connect(this.url);
            this.channel = await this.connection.createChannel();
            console.log(`✅ RabbitMQ Conectado!`);
        } catch (error) {
            console.error('❌ Erro ao conectar no RabbitMQ:', error.message);
            // Retry logic simples
            setTimeout(() => this.connect(), 5000);
        }
    }

    /**
     * Publica uma mensagem em uma Exchange (Broadcast)
     */
    async publish(exchange, routingKey, data) {
        if (!this.channel) await this.connect();

        try {
            await this.channel.assertExchange(exchange, 'topic', { durable: false });
            
            const message = JSON.stringify(data);
            this.channel.publish(exchange, routingKey, Buffer.from(message));
            
            console.log(`📤 Evento Publicado: [${exchange}:${routingKey}]`);
        } catch (error) {
            console.error('Erro ao publicar:', error);
        }
    }

    /**
     * Escuta uma fila específica
     */
    async subscribe(exchange, routingKey, queueName, callback) {
        if (!this.channel) await this.connect();

        try {
            await this.channel.assertExchange(exchange, 'topic', { durable: false });
            
            const q = await this.channel.assertQueue(queueName, { durable: false });
            
            await this.channel.bindQueue(q.queue, exchange, routingKey);

            console.log(`📥 Ouvindo fila: ${queueName} ligada a ${routingKey}`);

            this.channel.consume(q.queue, (msg) => {
                if (msg !== null) {
                    const content = JSON.parse(msg.content.toString());
                    // console.log(`📨 Mensagem recebida em ${queueName}`);
                    callback(content);
                    this.channel.ack(msg);
                }
            });
        } catch (error) {
            console.error('Erro ao subscrever:', error);
        }
    }
}

module.exports = new MessageBroker();