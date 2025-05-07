# E-Commerce Database Queries

This repository contains SQL scripts for an e-commerce database along with complex analytical queries for data analysis.

## Database Schema

The database consists of four interconnected tables:

| Table         | Description                                                                 |
| ------------- | --------------------------------------------------------------------------- |
| `customers`   | Stores customer information including ID, name, email, and country          |
| `products`    | Contains product details including ID, name, category, and price            |
| `orders`      | Tracks order information including ID, customer reference, date, and status |
| `order_items` | Contains individual items within each order with quantity and unit price    |

### Entity Relationship Diagram

```
customers (1) ----< orders (1) ----< order_items >---- (1) products
```

## Setup Scripts

### Table Creation Script

```sql
-- Drop tables if they exist
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS customers;

-- Customers table
CREATE TABLE customers (
    customer_id INT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    country VARCHAR(50)
);

-- Products table
CREATE TABLE products (
    product_id INT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    category VARCHAR(50),
    price DECIMAL(10,2)
);

-- Orders table
CREATE TABLE orders (
    order_id INT PRIMARY KEY,
    customer_id INT,
    order_date DATE,
    status VARCHAR(20),
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

-- Order Items table
CREATE TABLE order_items (
    order_item_id INT PRIMARY KEY,
    order_id INT,
    product_id INT,
    quantity INT,
    unit_price DECIMAL(10,2),
    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);
```

### Data Insertion Script

```sql
-- Customers
INSERT INTO customers VALUES
(1, 'Alice Smith', 'alice@example.com', 'USA'),
(2, 'Bob Jones', 'bob@example.com', 'Canada'),
(3, 'Charlie Zhang', 'charlie@example.com', 'UK');

-- Products
INSERT INTO products VALUES
(1, 'Laptop', 'Electronics', 1200.00),
(2, 'Smartphone', 'Electronics', 800.00),
(3, 'Desk Chair', 'Furniture', 150.00),
(4, 'Coffee Maker', 'Appliances', 85.50);

-- Orders
INSERT INTO orders VALUES
(1, 1, '2023-11-15', 'Shipped'),
(2, 2, '2023-11-20', 'Pending'),
(3, 1, '2023-12-01', 'Delivered'),
(4, 3, '2023-12-03', 'Cancelled');

-- Order Items
INSERT INTO order_items VALUES
(1, 1, 1, 1, 1200.00), -- Laptop
(2, 1, 4, 2, 85.50),   -- Coffee Maker
(3, 2, 2, 1, 800.00),  -- Smartphone
(4, 3, 3, 2, 150.00),  -- Desk Chair
(5, 4, 1, 1, 1200.00); -- Laptop
```

## Complex Queries

### Query 1: Top Customers by Spending

**Description**: Identifies customers who have spent the most money across all their orders, sorted in descending order of total spend.

```sql
SELECT
    c.customer_id,
    c.name,
    c.country,
    SUM(oi.quantity * oi.unit_price) AS total_spend
FROM
    customers c
JOIN
    orders o ON c.customer_id = o.customer_id
JOIN
    order_items oi ON o.order_id = oi.order_id
GROUP BY
    c.customer_id, c.name, c.country
ORDER BY
    total_spend DESC;
```

[View screenshot of results](./screenshots/database-query-screenshots/querying_top_customers_in_descending_order.png)

### Query 2: Monthly Sales Report (Only Shipped/Delivered)

**Description**: Generates a monthly sales report, showing total sales for each month, but only including orders with status 'Shipped' or 'Delivered'.

```sql
SELECT
    DATE_FORMAT(o.order_date, '%Y-%m') AS month,
    SUM(oi.quantity * oi.unit_price) AS total_sales,
    COUNT(DISTINCT o.order_id) AS order_count
FROM
    orders o
JOIN
    order_items oi ON o.order_id = oi.order_id
WHERE
    o.status IN ('Shipped', 'Delivered')
GROUP BY
    DATE_FORMAT(o.order_date, '%Y-%m')
ORDER BY
    month;
```

[View screenshot of results](./screenshots/database-query-screenshots/querying_monthly_sales_report.png)

### Query 3: Products Never Ordered

**Description**: Identifies products that have never been purchased by any customer.

```sql
SELECT
    p.product_id,
    p.name,
    p.category,
    p.price
FROM
    products p
LEFT JOIN
    order_items oi ON p.product_id = oi.product_id
WHERE
    oi.order_item_id IS NULL;
```

[View screenshot of results](./screenshots/database-query-screenshots/querying_never_ordered_products.png)

### Query 4: Average Order Value by Country

**Description**: Calculates the average order value (AOV) for customers from each country.

```sql
SELECT
    c.country,
    AVG(order_total.total) AS average_order_value
FROM
    customers c
JOIN
    orders o ON c.customer_id = o.customer_id
JOIN
    (SELECT
        order_id,
        SUM(quantity * unit_price) AS total
     FROM
        order_items
     GROUP BY
        order_id) AS order_total ON o.order_id = order_total.order_id
GROUP BY
    c.country
ORDER BY
    average_order_value DESC;
```

[View screenshot of results](./screenshots/database-query-screenshots/average_order_value_by_country.png)

### Query 5: Frequent Buyers (More Than One Order)

**Description**: Identifies customers who have placed more than one order, indicating customer loyalty.

```sql
SELECT
    c.customer_id,
    c.name,
    c.email,
    c.country,
    COUNT(o.order_id) AS order_count
FROM
    customers c
JOIN
    orders o ON c.customer_id = o.customer_id
GROUP BY
    c.customer_id, c.name, c.email, c.country
HAVING
    COUNT(o.order_id) > 1
ORDER BY
    order_count DESC;
```

[View screenshot of results](./screenshots/database-query-screenshots/querying_top_customers.png)
