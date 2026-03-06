-- User dummy untuk testing masing-masing role
-- PIN untuk semua user: "1234"
-- Hash bcrypt untuk PIN 1234: $2a$10$oXUCAAv0Ogc46O0PxqVWQOi3BEXgEQ1T7h6jzrVoMjp.4fAieHKn.

-- 1. Admin User
INSERT INTO users (id, username, password_hash, full_name, role, is_active, created_at, updated_at)
VALUES (
    '01HQXYZABC1234567890ABCDEF', 
    'admin', 
    '$2a$10$oXUCAAv0Ogc46O0PxqVWQOi3BEXgEQ1T7h6jzrVoMjp.4fAieHKn.',
    'Administrator System',
    'admin',
    1,
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
);

-- 2. Waiter User
INSERT INTO users (id, username, password_hash, full_name, role, is_active, created_at, updated_at)
VALUES (
    '01HQXYZABC1234567890ABCDEG', 
    'waiter', 
    '$2a$10$oXUCAAv0Ogc46O0PxqVWQOi3BEXgEQ1T7h6jzrVoMjp.4fAieHKn.',
    'Budi Pelayan',
    'waiter',
    1,
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
);

-- 3. Kitchen User
INSERT INTO users (id, username, password_hash, full_name, role, is_active, created_at, updated_at)
VALUES (
    '01HQXYZABC1234567890ABCDEH', 
    'kitchen', 
    '$2a$10$oXUCAAv0Ogc46O0PxqVWQOi3BEXgEQ1T7h6jzrVoMjp.4fAieHKn.',
    'Andi Chef',
    'kitchen',
    1,
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
);

-- 4. Bar User
INSERT INTO users (id, username, password_hash, full_name, role, is_active, created_at, updated_at)
VALUES (
    '01HQXYZABC1234567890ABCDEI', 
    'bartender', 
    '$2a$10$oXUCAAv0Ogc46O0PxqVWQOi3BEXgEQ1T7h6jzrVoMjp.4fAieHKn.',
    'Siti Bartender',
    'bar',
    1,
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
);

-- 5. Cashier User
INSERT INTO users (id, username, password_hash, full_name, role, is_active, created_at, updated_at)
VALUES (
    '01HQXYZABC1234567890ABCDEJ', 
    'cashier', 
    '$2a$10$oXUCAAv0Ogc46O0PxqVWQOi3BEXgEQ1T7h6jzrVoMjp.4fAieHKn.',
    'Dewi Kasir',
    'cashier',
    1,
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
);

-- 6. Manager User
INSERT INTO users (id, username, password_hash, full_name, role, is_active, created_at, updated_at)
VALUES (
    '01HQXYZABC1234567890ABCDEK', 
    'manager', 
    '$2a$10$oXUCAAv0Ogc46O0PxqVWQOi3BEXgEQ1T7h6jzrVoMjp.4fAieHKn.',
    'Joko Manager',
    'manager',
    1,
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
);

-- Verifikasi user yang sudah dibuat
SELECT id, username, full_name, role, is_active FROM users ORDER BY role;
