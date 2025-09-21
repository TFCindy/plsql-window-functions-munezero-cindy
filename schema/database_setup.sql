-- Database Setup Script for Window Functions Assignment
-- This script creates and populates all necessary tables
-- 1. First, create the customers table
CREATE TABLE customers (
    customer_id INTEGER PRIMARY KEY,
    name VARCHAR(100),
    region VARCHAR(50)
);

-- 2. Second, create the products table
CREATE TABLE products (
    product_id INTEGER PRIMARY KEY,
    name VARCHAR(100),
    category VARCHAR(50)
);

-- 3. Finally, create the transactions table (it can now reference the other two)
CREATE TABLE transactions (
    transaction_id INTEGER PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(customer_id),
    product_id INTEGER REFERENCES products(product_id),
    sale_date DATE,
    amount NUMERIC(10,2)
);

-- 1. First insert ALL customers
INSERT INTO customers (customer_id, name, region) VALUES
(1001, 'John Doe', 'Kigali'),
(1002, 'Jane Smith', 'Kigali'),
(1003, 'Robert Johnson', 'North'),
(1004, 'Sarah Williams', 'South'),
(1005, 'Michael Brown', 'East');

-- 2. Then insert ALL products
INSERT INTO products (product_id, name, category) VALUES
(2001, 'Coffee Beans', 'Beverages'),
(2002, 'Coffee Maker', 'Appliances'),
(2003, 'Coffee Grinder', 'Appliances'),
(2004, 'Coffee Cups', 'Accessories');

-- 3. Finally, insert transactions (now the customer and product IDs exist)
INSERT INTO transactions (transaction_id, customer_id, product_id, sale_date, amount) VALUES
(3001, 1001, 2001, '2024-01-15', 25000),
(3002, 1002, 2002, '2024-01-20', 45000),
(3003, 1003, 2001, '2024-02-05', 12000),
(3004, 1004, 2003, '2024-02-15', 25000),
(3005, 1005, 2004, '2024-03-01', 18000);