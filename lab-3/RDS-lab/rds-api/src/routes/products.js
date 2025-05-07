const express = require('express');
const router = express.Router();
const ProductsController = require('../controllers/productsController');

const productsController = new ProductsController();

// Route to get all products
router.get('/', productsController.getAllProducts.bind(productsController));

// Route to get a product by ID
router.get('/:id', productsController.getProductById.bind(productsController));

// Route to create a new product
router.post('/', productsController.createProduct.bind(productsController));

// Route to update a product by ID
router.put('/:id', productsController.updateProduct.bind(productsController));

// Route to delete a product by ID
router.delete('/:id', productsController.deleteProduct.bind(productsController));

module.exports = router;