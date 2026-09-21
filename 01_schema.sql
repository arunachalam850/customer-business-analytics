-- MySQL 8+ schema
CREATE DATABASE IF NOT EXISTS business_analytics;
USE business_analytics;

DROP TABLE IF EXISTS returns, support_tickets, campaign_touchpoints, payments, order_items, orders, products, customers;

CREATE TABLE customers (
    customer_id VARCHAR(20) PRIMARY KEY,
    customer_name VARCHAR(120),
    city VARCHAR(80),
    region VARCHAR(40),
    segment VARCHAR(30),
    acquisition_channel VARCHAR(40),
    signup_date DATE
);

CREATE TABLE products (
    product_id VARCHAR(20) PRIMARY KEY,
    product_name VARCHAR(120),
    category VARCHAR(50),
    unit_cost DECIMAL(12,2),
    list_price DECIMAL(12,2),
    product_tier VARCHAR(30)
);

CREATE TABLE orders (
    order_id VARCHAR(20) PRIMARY KEY,
    customer_id VARCHAR(20),
    order_datetime DATETIME,
    order_status VARCHAR(20),
    sales_channel VARCHAR(40),
    payment_method VARCHAR(30),
    item_count INT,
    gross_sales DECIMAL(14,2),
    net_sales DECIMAL(14,2),
    shipping_fee DECIMAL(12,2),
    order_total DECIMAL(14,2),
    delivery_days INT,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

CREATE TABLE order_items (
    order_item_id VARCHAR(20) PRIMARY KEY,
    order_id VARCHAR(20),
    product_id VARCHAR(20),
    quantity INT,
    unit_price DECIMAL(12,2),
    discount_pct DECIMAL(6,2),
    discount_amount DECIMAL(12,2),
    net_line_sales DECIMAL(14,2),
    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

CREATE TABLE payments (
    payment_id VARCHAR(20) PRIMARY KEY,
    order_id VARCHAR(20),
    payment_datetime DATETIME,
    payment_method VARCHAR(30),
    amount DECIMAL(14,2),
    payment_status VARCHAR(20)
);

CREATE TABLE returns (
    return_id VARCHAR(20) PRIMARY KEY,
    order_id VARCHAR(20),
    product_id VARCHAR(20),
    return_reason VARCHAR(50),
    refund_amount DECIMAL(14,2),
    return_date DATE
);

CREATE TABLE support_tickets (
    ticket_id VARCHAR(20) PRIMARY KEY,
    customer_id VARCHAR(20),
    opened_datetime DATETIME,
    issue_type VARCHAR(50),
    priority VARCHAR(20),
    resolution_hours DECIMAL(10,2),
    resolved_datetime DATETIME,
    csat DECIMAL(4,1),
    channel VARCHAR(20)
);

CREATE TABLE campaign_touchpoints (
    campaign_touch_id VARCHAR(20) PRIMARY KEY,
    customer_id VARCHAR(20),
    touch_date DATE,
    campaign_name VARCHAR(50),
    touch_channel VARCHAR(20),
    delivered TINYINT,
    opened TINYINT,
    clicked TINYINT,
    converted TINYINT,
    spend DECIMAL(12,2)
);
