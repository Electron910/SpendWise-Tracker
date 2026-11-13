import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import pinoHttp from 'pino-http';
import swaggerUi from 'swagger-ui-express';
import { env } from './config/env';
import { logger } from './config/logger';
import { swaggerSpec } from './config/swagger';
import { authRouter } from './modules/auth/auth.routes';
import { analyticsRouter } from './modules/analytics/analytics.routes';
import { budgetsRouter } from './modules/budgets/budgets.routes';
import { categoriesRouter } from './modules/categories/categories.routes';
import { categorizationRouter } from './modules/categorization/categorization.routes';
import { insightsRouter } from './modules/insights/insights.routes';
import { recurringRouter } from './modules/recurring/recurring.routes';
import { transactionsRouter } from './modules/transactions/transactions.routes';
import { errorHandler, notFoundHandler } from './middleware/error.middleware';

export const app = express();

// Security & parsing middleware
app.use(helmet());
app.use(
  cors({
    origin: env.CORS_ORIGIN === '*' ? true : env.CORS_ORIGIN.split(','),
    credentials: true,
  }),
);
app.use(express.json({ limit: '2mb' }));
app.use(express.urlencoded({ extended: true }));

if (env.NODE_ENV !== 'test') {
  app.use(pinoHttp({ logger }));
}

// Rate limiter
const apiLimiter = rateLimit({
  windowMs: env.RATE_LIMIT_WINDOW_MS,
  max: env.RATE_LIMIT_MAX_REQUESTS,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    success: false,
    error: {
      code: 'RATE_LIMIT_EXCEEDED',
      message: 'Too many requests, please try again later.',
    },
  },
});

app.use(env.API_PREFIX, apiLimiter);

// Health check
app.get('/health', (_req, res) => {
  res.status(200).json({
    success: true,
    service: 'spendwise-backend',
    status: 'healthy',
    timestamp: new Date().toISOString(),
  });
});

// OpenAPI Docs
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec));

// API v1 routes
app.use(`${env.API_PREFIX}/auth`, authRouter);
app.use(`${env.API_PREFIX}/analytics`, analyticsRouter);
app.use(`${env.API_PREFIX}/budgets`, budgetsRouter);
app.use(`${env.API_PREFIX}/categories`, categoriesRouter);
app.use(`${env.API_PREFIX}/categorization`, categorizationRouter);
app.use(`${env.API_PREFIX}/insights`, insightsRouter);
app.use(`${env.API_PREFIX}/recurring`, recurringRouter);
app.use(`${env.API_PREFIX}/transactions`, transactionsRouter);

// 404 & Error Handlers
app.use(notFoundHandler);
app.use(errorHandler);
