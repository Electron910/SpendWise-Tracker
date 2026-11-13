import { app } from './app';
import { env } from './config/env';
import { logger } from './config/logger';
import { prisma } from './config/database';

async function bootstrap() {
  try {
    await prisma.$connect();
    logger.info('Connected to PostgreSQL database');

    const server = app.listen(env.PORT, () => {
      logger.info(`SpendWise API server running on http://localhost:${env.PORT}${env.API_PREFIX}`);
    });

    const shutdown = async () => {
      logger.info('Shutting down SpendWise API server...');
      server.close(async () => {
        await prisma.$disconnect();
        process.exit(0);
      });
    };

    process.on('SIGINT', shutdown);
    process.on('SIGTERM', shutdown);
  } catch (error) {
    logger.error({ error }, 'Failed to start SpendWise API server');
    process.exit(1);
  }
}

void bootstrap();
