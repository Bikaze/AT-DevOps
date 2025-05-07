const express = require('express');
const router = express.Router();
const OrdersController = require('../controllers/ordersController');

const ordersController = new OrdersController();

// Define routes for orders
router.get('/', ordersController.getAllOrders.bind(ordersController));
router.get('/:id', ordersController.getOrderById.bind(ordersController));
router.post('/', ordersController.createOrder.bind(ordersController));
router.put('/:id', ordersController.updateOrder.bind(ordersController));
router.delete('/:id', ordersController.deleteOrder.bind(ordersController));

module.exports = router;