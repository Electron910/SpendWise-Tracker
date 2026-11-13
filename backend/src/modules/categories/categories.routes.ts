import { Router } from 'express';
import { CategoriesController } from './categories.controller';
import { requireAuth } from '../../middleware/auth.middleware';
import { validateRequest } from '../../middleware/validate.middleware';
import {
  categoryIdParamSchema,
  createCategorySchema,
  updateCategorySchema,
} from './categories.validation';

export const categoriesRouter = Router();

categoriesRouter.use(requireAuth);

categoriesRouter.get('/', CategoriesController.list);
categoriesRouter.post('/', validateRequest(createCategorySchema), CategoriesController.create);
categoriesRouter.patch('/:id', validateRequest(updateCategorySchema), CategoriesController.update);
categoriesRouter.delete(
  '/:id',
  validateRequest(categoryIdParamSchema),
  CategoriesController.remove,
);
