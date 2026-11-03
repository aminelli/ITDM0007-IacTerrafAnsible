USE sales_mysql;

CREATE TABLE orders (
  order_id       BIGINT        NOT NULL AUTO_INCREMENT PRIMARY KEY,
  customer_code  VARCHAR(20)   NOT NULL,
  customer_name  VARCHAR(100)  NOT NULL,
  order_datetime DATETIME(3)   NOT NULL,
  order_status   ENUM('NEW','PAID','SHIPPED','CANCELLED') NOT NULL DEFAULT 'NEW',
  net_amount     DECIMAL(12,2) NOT NULL,
  tax_amount     DECIMAL(12,2) NOT NULL,
  total_amount   DECIMAL(12,2) NOT NULL,
  currency       CHAR(3)       NOT NULL,
  ship_country   CHAR(2)       NOT NULL,
  KEY idx_orders_datetime (order_datetime)
) ENGINE=InnoDB;

CREATE TABLE order_items (
  item_id      BIGINT        NOT NULL AUTO_INCREMENT PRIMARY KEY,
  order_id     BIGINT        NOT NULL,
  line_no      INT           NOT NULL,
  product_sku  VARCHAR(30)   NOT NULL,
  product_name VARCHAR(100)  NOT NULL,
  quantity     INT           NOT NULL,
  unit_price   DECIMAL(10,2) NOT NULL,
  line_total   DECIMAL(12,2) NOT NULL,
  CONSTRAINT fk_items_order FOREIGN KEY (order_id) REFERENCES orders(order_id)
) ENGINE=InnoDB;

-- Transactional outbox: one row per order, payload = order + items (read by Debezium)
CREATE TABLE order_outbox (
  id             BIGINT       NOT NULL AUTO_INCREMENT PRIMARY KEY,
  aggregate_type VARCHAR(50)  NOT NULL,
  aggregate_id   VARCHAR(50)  NOT NULL,
  event_type     VARCHAR(50)  NOT NULL,
  payload        JSON         NOT NULL,
  created_at     TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
) ENGINE=InnoDB;

CREATE USER 'debezium'@'%' IDENTIFIED BY 'dbz_pwd';
GRANT SELECT, RELOAD, SHOW DATABASES, REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO 'debezium'@'%';
FLUSH PRIVILEGES;
