-- Create test user
CREATE USER testuser WITH PASSWORD 'testuser_password';
ALTER USER testuser CREATEDB;

-- Create test schema and tables
CREATE SCHEMA IF NOT EXISTS testschema;

CREATE TABLE testschema.users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE testschema.orders (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES testschema.users(id),
    total_amount DECIMAL(10, 2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample data
INSERT INTO testschema.users (username, email) VALUES
    ('alice', 'alice@example.com'),
    ('bob', 'bob@example.com'),
    ('charlie', 'charlie@example.com');

INSERT INTO testschema.orders (user_id, total_amount) VALUES
    (1, 100.50),
    (1, 250.75),
    (2, 50.00),
    (3, 1000.00);

-- Grant permissions to testuser
GRANT ALL PRIVILEGES ON SCHEMA testschema TO testuser;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA testschema TO testuser;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA testschema TO testuser;

-- Allow testuser to login
ALTER USER testuser WITH PASSWORD 'testuser_password';
