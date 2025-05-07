const express = require('express');
const router = express.Router();
const ReportsController = require('../controllers/reportsController');

const reportsController = new ReportsController();

// Endpoint for Top Customers by Spending
router.get('/top-customers', reportsController.getTopCustomers);

// Endpoint for Monthly Sales Report
router.get('/monthly-sales', reportsController.getMonthlySalesReport);

// Endpoint for Products Never Ordered
router.get('/products-never-ordered', reportsController.getProductsNeverOrdered);

// Endpoint for Average Order Value by Country
router.get('/average-order-value', reportsController.getAverageOrderValueByCountry);

// Endpoint for Frequent Buyers
router.get('/frequent-buyers', reportsController.getFrequentBuyers);

module.exports = router;