-- Minimal TPC-H subset for the api/ smoke test. Three orders, one customer.
CREATE TABLE IF NOT EXISTS orders (
    o_orderkey      BIGINT PRIMARY KEY,
    o_custkey       BIGINT NOT NULL,
    o_orderstatus   CHAR(1) NOT NULL,
    o_totalprice    NUMERIC(12,2) NOT NULL,
    o_orderdate     DATE NOT NULL,
    o_orderpriority VARCHAR(15) NOT NULL,
    o_clerk         VARCHAR(15) NOT NULL,
    o_shippriority  INTEGER NOT NULL,
    o_comment       VARCHAR(79) NOT NULL
);

INSERT INTO orders VALUES
    (1, 100, 'O',  1500.50, '1995-03-15', '1-URGENT', 'Clerk#0001', 0, 'first fixture order'),
    (2, 100, 'F',  2400.75, '1995-04-02', '2-HIGH',   'Clerk#0002', 0, 'second fixture order'),
    (3, 100, 'P',   850.00, '1995-05-10', '3-MEDIUM', 'Clerk#0003', 0, 'third fixture order');
