-- MotorWise - Car Dealership Management System
-- Database Design and Setup, Version 2 
-- Aligned with the SDD: wireframes, state diagram, receipt
-- =====================================================

DROP DATABASE IF EXISTS motorwise;
CREATE DATABASE motorwise;
USE motorwise;

-- 1. ROLES: admin or staff (employee permissions)
CREATE TABLE roles (
    role_id     TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    role_name   VARCHAR(30) NOT NULL UNIQUE,
    description VARCHAR(150)
);

-- 2. USERS: employee login accounts only (matches "MotorWise Employees Only" login)
CREATE TABLE users (
    user_id       INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    role_id       TINYINT UNSIGNED NOT NULL,
    first_name    VARCHAR(100) NOT NULL,
    last_name     VARCHAR(100) NOT NULL,
    email         VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,        -- hashed password, never plain text
    is_active     BOOLEAN NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_login    TIMESTAMP NULL,
    CONSTRAINT fk_users_role FOREIGN KEY (role_id) REFERENCES roles(role_id)
);

-- 3. CUSTOMERS: filled in from the Purchase Vehicle form (no customer login needed)
CREATE TABLE customers (
    customer_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    first_name  VARCHAR(100) NOT NULL,
    last_name   VARCHAR(100) NOT NULL,
    address     VARCHAR(250),
    city        VARCHAR(100),
    state       VARCHAR(50),
    zip_code    VARCHAR(10),
    email       VARCHAR(100),
    phone       VARCHAR(20),
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 4. VEHICLES: inventory (columns match Search, Compare, and Details wireframes)
CREATE TABLE vehicles (
    vehicle_id   INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    stock_number VARCHAR(10) NOT NULL UNIQUE,
    vin          VARCHAR(17) NOT NULL UNIQUE,
    model_year   SMALLINT UNSIGNED NOT NULL,
    make         VARCHAR(50)  NOT NULL,
    model        VARCHAR(100) NOT NULL,
    mileage      INT UNSIGNED NOT NULL DEFAULT 0,
    price        DECIMAL(10,2) NOT NULL CHECK (price >= 0),
    body_type    VARCHAR(50),
    engine       VARCHAR(50),
    transmission VARCHAR(50),
    drivetrain   VARCHAR(50),
    color        VARCHAR(50),
    -- Matches the state diagram:
    -- available -> pending (purchase in progress) -> sold, or back to available if failed/cancelled
    -- removed = taken off the lot by an employee
    status       ENUM('available','pending','sold','removed') NOT NULL DEFAULT 'available',
    description  TEXT,
    image_url    VARCHAR(255),
    created_by   INT UNSIGNED,
    created_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_vehicles_creator FOREIGN KEY (created_by) REFERENCES users(user_id)
        ON DELETE SET NULL,
    INDEX idx_vehicle_search (make, model, model_year, price),
    INDEX idx_vehicle_status (status)
);

-- 5. FEATURES (for "search by features" and comparison)
CREATE TABLE features (
    feature_id   INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    feature_name VARCHAR(60) NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE vehicle_features (
    vehicle_id INT UNSIGNED NOT NULL,
    feature_id INT UNSIGNED NOT NULL,
    PRIMARY KEY (vehicle_id, feature_id),
    CONSTRAINT fk_vf_vehicle FOREIGN KEY (vehicle_id) REFERENCES vehicles(vehicle_id) ON DELETE CASCADE,
    CONSTRAINT fk_vf_feature FOREIGN KEY (feature_id) REFERENCES features(feature_id) ON DELETE CASCADE
);

-- 6. TRANSACTIONS: one row per purchase attempt (receipt data lives here)
--    One vehicle can have many attempts (failed/cancelled), but only one approved.
--    Card number, expiration, and security code are NEVER stored (PCI DSS).
CREATE TABLE transactions (
    transaction_id    INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    receipt_number    VARCHAR(20) NOT NULL UNIQUE,
    vehicle_id        INT UNSIGNED NOT NULL,
    customer_id       INT UNSIGNED NOT NULL,
    processed_by      INT UNSIGNED NULL,        -- employee for in-store sales; NULL for online
    vehicle_price     DECIMAL(10,2) NOT NULL,
    tax               DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    total             DECIMAL(10,2) NOT NULL,
    payment_status    ENUM('pending','approved','failed','cancelled') NOT NULL DEFAULT 'pending',
    payment_reference VARCHAR(100),             -- confirmation ID from the payment sandbox
    transaction_date  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_total CHECK (total = vehicle_price + tax),
    CONSTRAINT fk_tx_vehicle  FOREIGN KEY (vehicle_id)  REFERENCES vehicles(vehicle_id),
    CONSTRAINT fk_tx_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    CONSTRAINT fk_tx_staff    FOREIGN KEY (processed_by) REFERENCES users(user_id) ON DELETE SET NULL,
    INDEX idx_tx_vehicle (vehicle_id),
    INDEX idx_tx_customer (customer_id)
);

-- =====================================================
-- SAMPLE DATA (fake, for testing only)
-- =====================================================
INSERT INTO roles (role_name, description) VALUES
    ('admin', 'Full access, including account management'),
    ('staff', 'Add, edit, and remove vehicle listings');

-- Placeholder hashes: replace with real hashes created by the login code
INSERT INTO users (role_id, first_name, last_name, email, password_hash) VALUES
    (1, 'Admin', 'User', 'admin@motorwise.test', 'REPLACE_WITH_HASH'),
    (2, 'Staff', 'User', 'staff@motorwise.test', 'REPLACE_WITH_HASH');

INSERT INTO features (feature_name) VALUES
    ('Backup Camera'), ('Bluetooth'), ('All-Wheel Drive'), ('Sunroof'), ('Leather Seats');

INSERT INTO vehicles
    (stock_number, vin, model_year, make, model, mileage, price, body_type, engine, transmission, drivetrain, color, status, created_by)
VALUES
    ('MW001', 'MWSAMPLE000000001', 2025, 'Chevrolet', 'Trax',       100, 40000.00, 'SUV',   '1.2L Turbo', 'Automatic', 'FWD', 'White',  'available', 2),
    ('MW002', 'MWSAMPLE000000002', 2026, 'Subaru',    'Forester',     0, 30000.00, 'SUV',   '2.5L',       'Automatic', 'AWD', 'Green',  'available', 2),
    ('MW003', 'MWSAMPLE000000003', 2025, 'GMC',       'Sierra 1500', 20000, 45000.00, 'Truck', '5.3L V8',    'Automatic', '4WD', 'Black',  'available', 2),
    ('MW004', 'MWSAMPLE000000004', 2025, 'Honda',     'HR-V',       500, 27900.00, 'SUV',   '2.0L',       'Automatic', 'AWD', 'Gray',   'sold',      2);

INSERT INTO vehicle_features (vehicle_id, feature_id) VALUES
    (1,1),(1,2),(2,1),(2,2),(2,3),(3,1),(3,3),(4,1),(4,2);

INSERT INTO customers (first_name, last_name, address, city, state, zip_code)
VALUES ('Test', 'Customer', '123 Main St', 'Minneapolis', 'MN', '55401');

-- One completed sample sale (HR-V). Total = 27900 + 837 tax.
INSERT INTO transactions
    (receipt_number, vehicle_id, customer_id, vehicle_price, tax, total, payment_status, payment_reference, transaction_date)
VALUES
    ('MW-20261015-0001', 4, 1, 27900.00, 837.00, 28737.00, 'approved', 'SANDBOX-TEST-0001', '2026-10-15 10:30:00');

-- =====================================================
-- TEST QUERY: everything the Receipt page (Figure 11) needs
-- =====================================================
-- SELECT t.receipt_number, t.transaction_date,
--        v.model_year, v.make, v.model, v.vin, v.mileage,
--        c.first_name, c.last_name,
--        t.vehicle_price, t.tax, t.total, t.payment_status
-- FROM transactions t
-- JOIN vehicles  v ON v.vehicle_id  = t.vehicle_id
-- JOIN customers c ON c.customer_id = t.customer_id
-- WHERE t.receipt_number = 'MW-20261015-0001';


-- ==================================================================================== NINKA ========================================================




-- MotorWise - Inventory Management (database layer)
-- Run AFTER motorwise_schema_v2.sql. Adds NO new tables
-- (the database stays at 7 tables, matching the SDD/SRS).
--
-- Vehicle status flow (matches the SDD state diagram):
--   available -> pending -> sold
--   pending   -> available (payment failed/cancelled)
--   available -> removed   (employee removes listing)
--   removed   -> available (employee restores listing)
-- =====================================================

USE motorwise;

-- -----------------------------------------------------
-- VIEWS (View Inventory)
-- -----------------------------------------------------
-- Customer-facing: only vehicles that can be bought
CREATE OR REPLACE VIEW v_available_inventory AS
SELECT v.vehicle_id, v.stock_number, v.vin, v.model_year, v.make, v.model,
       v.mileage, v.price, v.body_type, v.engine, v.transmission,
       v.drivetrain, v.color, v.description, v.image_url,
       (SELECT GROUP_CONCAT(f.feature_name ORDER BY f.feature_name SEPARATOR ', ')
          FROM vehicle_features vf
          JOIN features f ON f.feature_id = vf.feature_id
         WHERE vf.vehicle_id = v.vehicle_id) AS features
FROM vehicles v
WHERE v.status = 'available';

-- Employee-facing (Manage page): every vehicle, every status
CREATE OR REPLACE VIEW v_inventory_manage AS
SELECT v.vehicle_id, v.stock_number, v.vin, v.model_year, v.make, v.model,
       v.mileage, v.price, v.body_type, v.engine, v.transmission,
       v.drivetrain, v.color, v.status, v.description, v.image_url,
       (SELECT GROUP_CONCAT(f.feature_name ORDER BY f.feature_name SEPARATOR ', ')
          FROM vehicle_features vf
          JOIN features f ON f.feature_id = vf.feature_id
         WHERE vf.vehicle_id = v.vehicle_id) AS features,
       CONCAT(u.first_name, ' ', u.last_name) AS added_by,
       v.created_at, v.updated_at
FROM vehicles v
LEFT JOIN users u ON u.user_id = v.created_by;

-- -----------------------------------------------------
-- STORED PROCEDURES
-- -----------------------------------------------------
DROP PROCEDURE IF EXISTS sp_assert_employee;
DROP PROCEDURE IF EXISTS sp_add_vehicle;
DROP PROCEDURE IF EXISTS sp_update_vehicle;
DROP PROCEDURE IF EXISTS sp_remove_vehicle;
DROP PROCEDURE IF EXISTS sp_restore_vehicle;
DROP PROCEDURE IF EXISTS sp_mark_vehicle_sold;
DROP PROCEDURE IF EXISTS sp_add_vehicle_feature;
DROP PROCEDURE IF EXISTS sp_remove_vehicle_feature;
DROP PROCEDURE IF EXISTS sp_reserve_vehicle;
DROP PROCEDURE IF EXISTS sp_release_vehicle;
DROP PROCEDURE IF EXISTS sp_complete_sale;

DELIMITER $$

-- Only active employee accounts may manage inventory
CREATE PROCEDURE sp_assert_employee(IN p_user_id INT UNSIGNED)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM users WHERE user_id = p_user_id AND is_active = TRUE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Access denied: active employee account required.';
    END IF;
END$$

-- ADD a vehicle (new listings start as available)
CREATE PROCEDURE sp_add_vehicle(
    IN p_user_id      INT UNSIGNED,
    IN p_stock_number VARCHAR(10),
    IN p_vin          VARCHAR(17),
    IN p_model_year   SMALLINT UNSIGNED,
    IN p_make         VARCHAR(50),
    IN p_model        VARCHAR(100),
    IN p_mileage      INT UNSIGNED,
    IN p_price        DECIMAL(10,2),
    IN p_body_type    VARCHAR(50),
    IN p_engine       VARCHAR(50),
    IN p_transmission VARCHAR(50),
    IN p_drivetrain   VARCHAR(50),
    IN p_color        VARCHAR(50),
    IN p_description  TEXT,
    IN p_image_url    VARCHAR(255)
)
BEGIN
    CALL sp_assert_employee(p_user_id);

    IF CHAR_LENGTH(p_vin) <> 17 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid VIN: must be exactly 17 characters.';
    END IF;
    IF p_price IS NULL OR p_price < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid price: must be 0 or greater.';
    END IF;
    IF p_model_year < 1980 OR p_model_year > YEAR(CURDATE()) + 2 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid model year.';
    END IF;
    IF EXISTS (SELECT 1 FROM vehicles WHERE vin = p_vin) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A vehicle with this VIN already exists.';
    END IF;
    IF EXISTS (SELECT 1 FROM vehicles WHERE stock_number = p_stock_number) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A vehicle with this stock number already exists.';
    END IF;

    INSERT INTO vehicles
        (stock_number, vin, model_year, make, model, mileage, price, body_type,
         engine, transmission, drivetrain, color, status, description, image_url, created_by)
    VALUES
        (p_stock_number, p_vin, p_model_year, p_make, p_model, p_mileage, p_price, p_body_type,
         p_engine, p_transmission, p_drivetrain, p_color, 'available', p_description, p_image_url, p_user_id);

    SELECT LAST_INSERT_ID() AS vehicle_id;
END$$

-- UPDATE (edit) a vehicle. Sold or pending vehicles are locked to protect transaction history.
CREATE PROCEDURE sp_update_vehicle(
    IN p_user_id      INT UNSIGNED,
    IN p_vehicle_id   INT UNSIGNED,
    IN p_stock_number VARCHAR(10),
    IN p_vin          VARCHAR(17),
    IN p_model_year   SMALLINT UNSIGNED,
    IN p_make         VARCHAR(50),
    IN p_model        VARCHAR(100),
    IN p_mileage      INT UNSIGNED,
    IN p_price        DECIMAL(10,2),
    IN p_body_type    VARCHAR(50),
    IN p_engine       VARCHAR(50),
    IN p_transmission VARCHAR(50),
    IN p_drivetrain   VARCHAR(50),
    IN p_color        VARCHAR(50),
    IN p_description  TEXT,
    IN p_image_url    VARCHAR(255)
)
BEGIN
    DECLARE v_status VARCHAR(20);

    CALL sp_assert_employee(p_user_id);

    SELECT status INTO v_status FROM vehicles WHERE vehicle_id = p_vehicle_id;
    IF v_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Vehicle not found.';
    END IF;
    IF v_status IN ('pending', 'sold') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Pending or sold vehicles cannot be edited.';
    END IF;
    IF CHAR_LENGTH(p_vin) <> 17 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid VIN: must be exactly 17 characters.';
    END IF;
    IF p_price IS NULL OR p_price < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid price: must be 0 or greater.';
    END IF;
    IF p_model_year < 1980 OR p_model_year > YEAR(CURDATE()) + 2 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid model year.';
    END IF;
    IF EXISTS (SELECT 1 FROM vehicles WHERE vin = p_vin AND vehicle_id <> p_vehicle_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Another vehicle already uses this VIN.';
    END IF;
    IF EXISTS (SELECT 1 FROM vehicles WHERE stock_number = p_stock_number AND vehicle_id <> p_vehicle_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Another vehicle already uses this stock number.';
    END IF;

    UPDATE vehicles
       SET stock_number = p_stock_number, vin = p_vin, model_year = p_model_year,
           make = p_make, model = p_model, mileage = p_mileage, price = p_price,
           body_type = p_body_type, engine = p_engine, transmission = p_transmission,
           drivetrain = p_drivetrain, color = p_color, description = p_description,
           image_url = p_image_url
     WHERE vehicle_id = p_vehicle_id;

    SELECT ROW_COUNT() AS rows_updated;
END$$

-- REMOVE a listing (soft delete: the row stays so past transactions keep working)
CREATE PROCEDURE sp_remove_vehicle(IN p_user_id INT UNSIGNED, IN p_vehicle_id INT UNSIGNED)
BEGIN
    DECLARE v_status VARCHAR(20);
    CALL sp_assert_employee(p_user_id);

    SELECT status INTO v_status FROM vehicles WHERE vehicle_id = p_vehicle_id;
    IF v_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Vehicle not found.';
    END IF;
    IF v_status <> 'available' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only available vehicles can be removed.';
    END IF;

    UPDATE vehicles SET status = 'removed' WHERE vehicle_id = p_vehicle_id;
    SELECT 'removed' AS new_status;
END$$

-- RESTORE a removed listing
CREATE PROCEDURE sp_restore_vehicle(IN p_user_id INT UNSIGNED, IN p_vehicle_id INT UNSIGNED)
BEGIN
    CALL sp_assert_employee(p_user_id);

    UPDATE vehicles SET status = 'available'
     WHERE vehicle_id = p_vehicle_id AND status = 'removed';

    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Vehicle not found or not in removed status.';
    END IF;
    SELECT 'available' AS new_status;
END$$

-- MARK SOLD (employee action)
CREATE PROCEDURE sp_mark_vehicle_sold(IN p_user_id INT UNSIGNED, IN p_vehicle_id INT UNSIGNED)
BEGIN
    CALL sp_assert_employee(p_user_id);

    UPDATE vehicles SET status = 'sold'
     WHERE vehicle_id = p_vehicle_id AND status IN ('available', 'pending');

    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Vehicle not found or cannot be marked sold.';
    END IF;
    SELECT 'sold' AS new_status;
END$$

-- FEATURES: attach or detach a feature (creates the feature if it is new)
CREATE PROCEDURE sp_add_vehicle_feature(
    IN p_user_id INT UNSIGNED, IN p_vehicle_id INT UNSIGNED, IN p_feature_name VARCHAR(60))
BEGIN
    DECLARE v_feature_id INT UNSIGNED;
    CALL sp_assert_employee(p_user_id);

    IF NOT EXISTS (SELECT 1 FROM vehicles WHERE vehicle_id = p_vehicle_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Vehicle not found.';
    END IF;

    INSERT IGNORE INTO features (feature_name) VALUES (p_feature_name);
    SELECT feature_id INTO v_feature_id FROM features WHERE feature_name = p_feature_name;
    INSERT IGNORE INTO vehicle_features (vehicle_id, feature_id) VALUES (p_vehicle_id, v_feature_id);
END$$

CREATE PROCEDURE sp_remove_vehicle_feature(
    IN p_user_id INT UNSIGNED, IN p_vehicle_id INT UNSIGNED, IN p_feature_name VARCHAR(60))
BEGIN
    CALL sp_assert_employee(p_user_id);

    DELETE vf FROM vehicle_features vf
      JOIN features f ON f.feature_id = vf.feature_id
     WHERE vf.vehicle_id = p_vehicle_id AND f.feature_name = p_feature_name;
END$$

-- -----------------------------------------------------
-- PURCHASE WORKFLOW HOOKS (for Zach's Transaction module)
-- Each one is a single atomic UPDATE, so two buyers can never
-- reserve the same car at the same time.
-- -----------------------------------------------------
-- available -> pending (purchase in progress)
CREATE PROCEDURE sp_reserve_vehicle(IN p_vehicle_id INT UNSIGNED)
BEGIN
    UPDATE vehicles SET status = 'pending'
     WHERE vehicle_id = p_vehicle_id AND status = 'available';

    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Vehicle is no longer available.';
    END IF;
END$$

-- pending -> available (payment failed or cancelled)
CREATE PROCEDURE sp_release_vehicle(IN p_vehicle_id INT UNSIGNED)
BEGIN
    UPDATE vehicles SET status = 'available'
     WHERE vehicle_id = p_vehicle_id AND status = 'pending';
END$$

-- pending -> sold (payment approved)
CREATE PROCEDURE sp_complete_sale(IN p_vehicle_id INT UNSIGNED)
BEGIN
    UPDATE vehicles SET status = 'sold'
     WHERE vehicle_id = p_vehicle_id AND status = 'pending';

    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Vehicle is not in pending status.';
    END IF;
END$$

DELIMITER ;

-- =====================================================
-- TRY IT (run these one at a time; user_id 2 = staff user from the seed data)
-- =====================================================
-- SELECT * FROM v_available_inventory;
-- SELECT * FROM v_inventory_manage;
--
-- CALL sp_add_vehicle(2, 'MW005', 'MWSAMPLE000000005', 2025, 'Toyota', 'Camry', 1200,
--      29500.00, 'Sedan', '2.5L', 'Automatic', 'FWD', 'Silver', 'Like new', NULL);
-- CALL sp_add_vehicle_feature(2, 5, 'Backup Camera');
-- CALL sp_update_vehicle(2, 5, 'MW005', 'MWSAMPLE000000005', 2025, 'Toyota', 'Camry', 1200,
--      28900.00, 'Sedan', '2.5L', 'Automatic', 'FWD', 'Silver', 'Price reduced', NULL);
-- CALL sp_remove_vehicle(2, 5);
-- CALL sp_restore_vehicle(2, 5);
-- CALL sp_mark_vehicle_sold(2, 5);

-- SELECT * FROM v_available_inventory;
-- SELECT * FROM v_inventory_manage;

-- ==================================================================================== NINKA ========================================================


-- =====================================================
-- MotorWise - Screenshot queries for the Implementation & Documentation
-- HOW TO USE:
--   1. Run your combined schema + inventory script first (fresh database).
--   2. In MySQL Workbench, highlight ONE statement at a time and press
--      Ctrl+Enter (Cmd+Enter on Mac) so the result grid shows only that query.
--   3. Take the screenshot with the query and result both visible.
--   4. Run this file's steps once, in order. To reset, re-run the combined script.
-- =====================================================
USE motorwise;

-- =====================================================
-- A. DATABASE DESIGN AND SETUP
-- =====================================================
-- A1. All 7 tables
SHOW TABLES;

-- A2. Table structure
DESCRIBE vehicles;
DESCRIBE transactions;

-- A3. Relationships (foreign keys)
SELECT table_name AS child_table, column_name AS child_column,
       referenced_table_name AS parent_table, referenced_column_name AS parent_column
FROM information_schema.key_column_usage
WHERE table_schema = 'motorwise' AND referenced_table_name IS NOT NULL
ORDER BY child_table;

-- A4. Receipt query (shows transactions, vehicles, and customers working together)
SELECT t.receipt_number, t.transaction_date,
       v.model_year, v.make, v.model, v.vin,
       c.first_name, c.last_name,
       t.vehicle_price, t.tax, t.total, t.payment_status
FROM transactions t
JOIN vehicles  v ON v.vehicle_id  = t.vehicle_id
JOIN customers c ON c.customer_id = t.customer_id
WHERE t.receipt_number = 'MW-20261015-0001';

-- =====================================================
-- B. INVENTORY MANAGEMENT  (user_id 2 = staff employee)
-- =====================================================
-- B1. View all inventory (employee view)
SELECT vehicle_id, stock_number, model_year, make, model, price, status, features
FROM v_inventory_manage;

-- B2. ADD a vehicle
CALL sp_add_vehicle(2, 'MW005', 'MWSAMPLE000000005', 2025, 'Toyota', 'Camry', 1200,
     29500.00, 'Sedan', '2.5L', 'Automatic', 'FWD', 'Silver', 'Like new', NULL);
CALL sp_add_vehicle_feature(2, 5, 'Backup Camera');
SELECT vehicle_id, stock_number, make, model, price, status, features
FROM v_inventory_manage WHERE vehicle_id = 5;

-- B3. UPDATE (edit) the price
CALL sp_update_vehicle(2, 5, 'MW005', 'MWSAMPLE000000005', 2025, 'Toyota', 'Camry', 1200,
     28900.00, 'Sedan', '2.5L', 'Automatic', 'FWD', 'Silver', 'Price reduced', NULL);
SELECT vehicle_id, stock_number, make, model, price, status
FROM v_inventory_manage WHERE vehicle_id = 5;

-- B4. REMOVE a vehicle (status changes; customers no longer see it)
CALL sp_remove_vehicle(2, 5);
SELECT vehicle_id, make, model, status FROM v_inventory_manage WHERE vehicle_id = 5;
SELECT vehicle_id, make, model FROM v_available_inventory;      -- Camry is missing here

-- B5. RESTORE the vehicle
CALL sp_restore_vehicle(2, 5);
SELECT vehicle_id, make, model, status FROM v_inventory_manage WHERE vehicle_id = 5;

-- B6. MARK SOLD
CALL sp_mark_vehicle_sold(2, 5);
SELECT vehicle_id, make, model, status FROM v_inventory_manage WHERE vehicle_id = 5;

-- B7. Purchase workflow hooks (vehicle 1: available -> pending -> available)
CALL sp_reserve_vehicle(1);
SELECT vehicle_id, make, model, status FROM v_inventory_manage WHERE vehicle_id = 1;
CALL sp_release_vehicle(1);
SELECT vehicle_id, make, model, status FROM v_inventory_manage WHERE vehicle_id = 1;

-- B8. Validation and access control (each of these should return an ERROR; screenshot the error)
CALL sp_add_vehicle(2, 'MW006', 'SHORT', 2025, 'Test', 'Car', 0, 1000.00,
     NULL, NULL, NULL, NULL, NULL, NULL, NULL);                  -- invalid VIN
CALL sp_add_vehicle(99, 'MW007', 'MWSAMPLE000000007', 2025, 'Test', 'Car', 0, 1000.00,
     NULL, NULL, NULL, NULL, NULL, NULL, NULL);                  -- unknown employee
CALL sp_update_vehicle(2, 5, 'MW005', 'MWSAMPLE000000005', 2025, 'Toyota', 'Camry', 1200,
     1.00, 'Sedan', '2.5L', 'Automatic', 'FWD', 'Silver', 'Edit sold car', NULL);   -- sold car locked
CALL sp_reserve_vehicle(4);                                      -- already sold

-- =====================================================
-- C. VEHICLE SEARCH & FILTERING (database level)
-- =====================================================
-- C1. Filter by make and price
SELECT stock_number, model_year, make, model, price, mileage
FROM v_available_inventory
WHERE make = 'Subaru' AND price <= 35000
ORDER BY price;

-- C2. Filter by body type, year, and feature
SELECT stock_number, model_year, make, model, price, features
FROM v_available_inventory
WHERE body_type = 'SUV' AND model_year >= 2025 AND features LIKE '%Bluetooth%'
ORDER BY price;
