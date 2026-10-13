CREATE DATABASE IF NOT EXISTS revenue_audit;
USE revenue_audit;

DROP TABLE IF EXISTS shipping_costs;
DROP TABLE IF EXISTS returns;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS date_dim;

CREATE TABLE customers (
    customer_unique_id VARCHAR(40) PRIMARY KEY,
    customer_state     VARCHAR(5),
    customer_city      VARCHAR(80)
);

CREATE TABLE products (
    product_id VARCHAR(40) PRIMARY KEY,
    category   VARCHAR(80),
    list_price DECIMAL(12,2)
);

CREATE TABLE date_dim (
    date_key    INT PRIMARY KEY,
    full_date   DATE NOT NULL UNIQUE,
    year        SMALLINT,
    quarter     TINYINT,
    month_num   TINYINT,
    month_name  VARCHAR(10),
    ym          CHAR(7),
    day_of_week VARCHAR(10),
    is_weekend  TINYINT
);

CREATE TABLE orders (
    order_id           VARCHAR(40) PRIMARY KEY,
    customer_unique_id VARCHAR(40) NOT NULL,
    order_status       VARCHAR(20),
    purchase_date      DATE NOT NULL,
    purchase_ts        DATETIME,
    delivered_date     DATETIME NULL,
    estimated_date     DATETIME NULL,
    is_late            TINYINT,
    review_score       DECIMAL(3,1) NULL,
    FOREIGN KEY (customer_unique_id) REFERENCES customers(customer_unique_id),
    INDEX idx_purchase_date (purchase_date)
);

CREATE TABLE order_items (
    order_id                VARCHAR(40) NOT NULL,
    order_item_id           INT NOT NULL,
    product_id              VARCHAR(40) NOT NULL,
    seller_id               VARCHAR(40),
    seller_state            VARCHAR(5),
    price                   DECIMAL(12,2),
    gross_revenue           DECIMAL(12,2),
    discount_amount         DECIMAL(12,2),
    net_revenue             DECIMAL(12,2),
    product_cost            DECIMAL(12,2),
    shipping_cost           DECIMAL(12,2),
    refund_amount           DECIMAL(12,2),
    total_cost              DECIMAL(12,2),
    gross_profit            DECIMAL(12,2),
    gross_margin_percentage DECIMAL(12,2) NULL,
    revenue_leakage_amount  DECIMAL(12,2),
    below_margin_threshold  TINYINT,
    PRIMARY KEY (order_id, order_item_id),
    FOREIGN KEY (order_id)   REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id),
    INDEX idx_product (product_id)
);

CREATE TABLE returns (
    order_id      VARCHAR(40) NOT NULL,
    order_item_id INT NOT NULL,
    return_reason VARCHAR(40),
    refund_amount DECIMAL(12,2),
    PRIMARY KEY (order_id, order_item_id),
    FOREIGN KEY (order_id, order_item_id) REFERENCES order_items(order_id, order_item_id)
);

CREATE TABLE shipping_costs (
    order_id        VARCHAR(40) NOT NULL,
    order_item_id   INT NOT NULL,
    freight_value   DECIMAL(12,2),
    excess_freight  DECIMAL(12,2),
    freight_pct     DECIMAL(8,2),
    PRIMARY KEY (order_id, order_item_id),
    FOREIGN KEY (order_id, order_item_id) REFERENCES order_items(order_id, order_item_id)
);