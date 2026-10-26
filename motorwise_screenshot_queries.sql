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
