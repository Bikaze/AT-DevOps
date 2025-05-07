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
