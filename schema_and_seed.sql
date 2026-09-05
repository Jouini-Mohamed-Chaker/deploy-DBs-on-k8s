-- Replace this file with your own schema + seed data.
-- It gets mounted into a one-shot Job and run with `cockroach sql --file=...`
-- Example:

CREATE DATABASE IF NOT EXISTS lab;
USE lab;

CREATE TABLE IF NOT EXISTS example_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name STRING NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO example_items (name) VALUES
    ('item-one'),
    ('item-two'),
    ('item-three');