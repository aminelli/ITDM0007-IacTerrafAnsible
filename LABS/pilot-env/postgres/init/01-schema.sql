CREATE TABLE sales_orders (
  id                 BIGSERIAL PRIMARY KEY,
  customer_id        UUID           NOT NULL,
  customer_full_name TEXT           NOT NULL,
  created_at         TIMESTAMPTZ    NOT NULL DEFAULT now(),
  state              TEXT           NOT NULL DEFAULT 'created'
                     CHECK (state IN ('created','paid','shipped','cancelled')),
  amount_net         NUMERIC(12,2)  NOT NULL,
  amount_vat         NUMERIC(12,2)  NOT NULL,
  amount_gross       NUMERIC(12,2)  NOT NULL,
  currency_code      CHAR(3)        NOT NULL,
  country_code       CHAR(2)        NOT NULL
);
CREATE INDEX idx_sales_orders_created_at ON sales_orders (created_at);

CREATE TABLE sales_order_lines (
  line_id          BIGSERIAL PRIMARY KEY,
  order_id         BIGINT        NOT NULL REFERENCES sales_orders(id),
  line_number      INT           NOT NULL,
  item_code        TEXT          NOT NULL,
  item_description TEXT          NOT NULL,
  qty              INT           NOT NULL,
  price_net        NUMERIC(10,2) NOT NULL,
  line_net         NUMERIC(12,2) NOT NULL
);

-- Transactional outbox: one row per order, payload = order + lines (read by Debezium)
CREATE TABLE order_outbox (
  id             BIGSERIAL PRIMARY KEY,
  aggregate_type TEXT        NOT NULL,
  aggregate_id   TEXT        NOT NULL,
  event_type     TEXT        NOT NULL,
  payload        JSONB       NOT NULL,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
