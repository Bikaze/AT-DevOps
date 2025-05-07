const express = require('express');
const router = express.Router();
const CustomersController = require('../controllers/customersController');
const customersController = new CustomersController();

// Route to get all customers
router.get('/', customersController.getAllCustomers.bind(customersController));

// Route to get a customer by ID
router.get('/:id', customersController.getCustomerById.bind(customersController));

// Route to create a new customer
router.post('/', customersController.createCustomer.bind(customersController));

// Route to update a customer
router.put('/:id', customersController.updateCustomer.bind(customersController));

// Route to delete a customer
router.delete('/:id', customersController.deleteCustomer.bind(customersController));

module.exports = router;