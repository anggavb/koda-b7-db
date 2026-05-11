CREATE DATABASE kasviordb;
-- drop database kasviordb;

CREATE TABLE users (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fullname VARCHAR(255),
    email VARCHAR(100) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    pin CHAR(6),
    phone_number VARCHAR(13),
    photo VARCHAR(255),
    is_verified BOOLEAN DEFAULT FALSE NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP
);

CREATE TABLE wallets (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id INT UNIQUE,
    balance DECIMAL(19, 4) DEFAULT 0,

    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TYPE METHOD_TYPE AS ENUM ('bank', 'online');
CREATE TABLE payment_methods (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(255),
    logo VARCHAR(255),
    method METHOD_TYPE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP
);

INSERT INTO payment_methods
(name, logo, method)
VALUES
('BRI', 'bri.svg', 'bank'),
('DANA', 'dana.svg', 'online'),
('BCA', 'bca.svg', 'bank'),
('GOPAY', 'gopay.svg', 'online'),
('OVO', 'ovo.svg', 'online');

CREATE TYPE TRANSACTION_TYPE AS ENUM ('top-up', 'transfer', 'receive');
CREATE TYPE TRANSACTION_STATUS AS ENUM ('pending', 'success', 'failed');
CREATE TABLE transactions (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id INT NOT NULL,
    amount DECIMAL(19, 4) NOT NULL,
    type TRANSACTION_TYPE NOT NULL,
    status TRANSACTION_STATUS NOT NULL, --(need for log)
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP,

    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE topup_details (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    transaction_id INT NOT NULL,
    payment_method_id INT NOT NULL,
    discount DECIMAL(19, 4) NOT NULL,
    tax DECIMAL(19, 4) NOT NULL,
    sub_total DECIMAL(19, 4) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),

    FOREIGN KEY (transaction_id) REFERENCES transactions(id),
    FOREIGN KEY (payment_method_id) REFERENCES payment_methods(id)
);

CREATE TABLE transfer_details (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    transaction_id INT NOT NULL,
    recipient_user_id INT NOT NULL,
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW(),

    FOREIGN KEY (transaction_id) REFERENCES transactions(id),
    FOREIGN KEY (recipient_user_id) REFERENCES users(id)
);

SELECT tablename FROM pg_catalog.pg_tables WHERE schemaname != 'pg_catalog' AND schemaname != 'information_schema';
TABLE users;
TABLE wallets;
TABLE transactions;
TABLE payment_methods;
TABLE topup_details;
TABLE transfer_details;

-- Login
SELECT email, password
FROM users
WHERE email = 'anggavb8@gmail.com' AND password = 'password';

-- Register
WITH register AS (
    INSERT INTO users
    (email, password)
    VALUES
    ('anggavb82@gmail.com', 'password')
    RETURNING id
)
INSERT INTO wallets (user_id)
SELECT id FROM register;

-- Get user login information (username, email, photo)
SELECT fullname, email, photo FROM users WHERE id = 1;

-- Get/check user PIN
SELECT pin FROM users WHERE id = 1

-- Get transaction history
SELECT u.fullname,
    CASE
        WHEN t.type = 'top-up' THEN 'top-up'
        WHEN td.recipient_user_id = 1 THEN 'receive'
        ELSE 'transfer'
    END AS type,
    t.amount
FROM transactions t
JOIN users u ON t.user_id = u.id
JOIN transfer_details td ON u.id = td.recipient_user_id
WHERE u.id = 1;

-- Get user history with option (income/expense, date range)
SELECT u.fullname,
    CASE
        WHEN t.type = 'top-up' THEN 'income'
        WHEN td.recipient_user_id = 1 THEN 'income'
        ELSE 'expense'
    END AS type,
    t.amount
FROM transactions t
JOIN users u ON t.user_id = u.id
JOIN transfer_details td ON u.id = td.recipient_user_id
WHERE u.id = 1
AND t.created_at BETWEEN '2026-05-10' AND '2026-05-11'
AND type IN ('top-up', 'receive') -- income
-- AND type IN ('transfer') -- expense
ORDER BY t.created_at DESC;

-- Get user account information (balance, income, expense)
-- for 10 users 5x topup 5x transfer
-- EXPLAIN ANALYZE
WITH sum_transaction AS (
    SELECT SUM(amount) AS total, type
    FROM transactions
    WHERE user_id = 1
    GROUP BY type
)
SELECT
    w.balance,
    (
        SELECT SUM(t.amount)
        FROM transactions t
        JOIN transfer_details td
            ON td.transaction_id = t.id
        WHERE td.recipient_user_id = 1 -- for check dis (u.id vs id)
        AND t.type = 'transfer'
    )
    +
    (
        SELECT total
        FROM sum_transaction
        WHERE type = 'top-up'
    )
    AS income,
    (
        SELECT total
        FROM sum_transaction
        WHERE type = 'transfer'
    )
    AS expense
FROM users u
JOIN wallets w ON u.id = w.user_id
WHERE u.id = 1;

-- Find receiver with pagination
SELECT photo, fullname AS "receiver", phone_number
FROM users
WHERE id != 1
LIMIT 10
OFFSET 0;

-- Create transaction/topup
--topup, topup_details, update_balance
WITH topup AS (
    INSERT INTO transactions (user_id, amount, type)
    VALUES (1, 100000, 'top-up')
    RETURNING id, amount, user_id
),
update_topup_detail AS (
    INSERT INTO topup_details (transaction_id, payment_method_id, discount, tax, sub_total)
    SELECT id, 1, 5000, 4000, (amount - 5000 + 4000) FROM topup
    
)
UPDATE wallets
SET balance = balance + (SELECT amount FROM topup)
WHERE id = (SELECT user_id FROM topup);

-- Get user profile (photo, full name, phone, email)
SELECT photo, fullname, phone_number, email
FROM users
WHERE id = 1;

-- Change pin
UPDATE users
SET pin = '123456',
    updated_at = NOW()
WHERE id = 1;

-- Change password
UPDATE users
SET password = 'newpassword',
    updated_at = NOW()
WHERE id = 1;

-- Change user profile
UPDATE users
SET photo = 'newphoto.img',
    fullname = 'Angga Vb',
    phone_number = '085156770131',
    updated_at = NOW()
WHERE id = 1;