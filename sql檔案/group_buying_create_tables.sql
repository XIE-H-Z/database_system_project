-- ============================================================
-- 團購系統資料庫 Create Table SQL
-- 版本：依目前提供的 CREATE TABLE 截圖整理
-- DBMS：MariaDB / MySQL
-- 說明：
--   1. 狀態欄位目前使用 CHAR(1) 代碼。
--   2. 此版本先依「之前版本」整理，之後可再依新版 ER 圖修正。
-- ============================================================

CREATE DATABASE IF NOT EXISTS group_buying_system
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;

USE group_buying_system;

SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS fulfillment;
DROP TABLE IF EXISTS payment;
DROP TABLE IF EXISTS purchaseorder;
DROP TABLE IF EXISTS groupbuy;
DROP TABLE IF EXISTS product;
DROP TABLE IF EXISTS supplier;
DROP TABLE IF EXISTS member;

SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================
-- 會員資料表 member
-- role:
--   1 = member
--   2= organizer
--   3= admin
-- status:
--   1 = active
--   2 = inactive
--   3 = banned
-- ============================================================
CREATE TABLE member (
    member_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    email VARCHAR(254) NOT NULL,
    phone CHAR(10) NOT NULL,
    name CHAR(10) NOT NULL,
    role CHAR(1) NOT NULL DEFAULT '1',
    status CHAR(1) NOT NULL DEFAULT '1',
    created_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_time DATETIME NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (member_id),
    UNIQUE KEY uk_member_email (email),
    UNIQUE KEY uk_member_phone (phone),

    CHECK (phone REGEXP '^[0-9]{10}$'),
    CHECK (role IN ('1', '2', '3')),
    CHECK (status IN ('1', '2', '3')),
    CHECK (
        email REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$'
    )
);

-- ============================================================
-- 供應商資料表 supplier
-- status:
--   1 = active
--   2 = inactive
-- ============================================================
CREATE TABLE supplier (
    supplier_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    supplier_name CHAR(20) NOT NULL,
    contact_name CHAR(10) NOT NULL,
    phone CHAR(10) NOT NULL,
    email VARCHAR(254) NOT NULL,
    address CHAR(50) NOT NULL,
    status CHAR(1) NOT NULL DEFAULT '1',
    created_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (supplier_id),
    UNIQUE KEY uk_supplier_email (email),
    UNIQUE KEY uk_supplier_phone (phone),

    CHECK (phone REGEXP '^[0-9]{10}$'),
    CHECK (status IN ('1', '2')),
    CHECK (
        email REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$'
    )
);

-- ============================================================
-- 商品資料表 product
-- status:
--   1 = active
--   2 = inactive
--   3 = discontinued
-- ============================================================
CREATE TABLE product (
    product_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    supplier_id BIGINT UNSIGNED NOT NULL,
    product_name CHAR(50) NOT NULL,
    brand CHAR(20) NOT NULL,
    description TEXT NULL,
    original_price INT UNSIGNED NOT NULL,
    group_price INT UNSIGNED NOT NULL,
    stock_quantity INT UNSIGNED NOT NULL,
    status CHAR(1) NOT NULL DEFAULT '1',
    created_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    end_time DATETIME NOT NULL,
    max_quantity INT UNSIGNED NOT NULL,
    min_quantity INT UNSIGNED NOT NULL,

    PRIMARY KEY (product_id),
    KEY idx_product_supplier_id (supplier_id),

    CONSTRAINT fk_product_supplier
        FOREIGN KEY (supplier_id)
        REFERENCES supplier(supplier_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CHECK (description IS NULL OR CHAR_LENGTH(description) <= 500),
    CHECK (group_price <= original_price),
    CHECK (status IN ('1', '2', '3')),
    CHECK (max_quantity > 0),
    CHECK (max_quantity >= min_quantity),
    CHECK (min_quantity > 0),
    CHECK (max_quantity <= stock_quantity),
    CHECK (end_time > created_time)
);

-- ============================================================
-- 團購資料表 groupbuy
-- status:
--   1 = active
--   2 = end
-- ============================================================
CREATE TABLE groupbuy (
    group_buy_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    member_id BIGINT UNSIGNED NOT NULL,
    product_id BIGINT UNSIGNED NOT NULL,
    title CHAR(50) NOT NULL,
    description TEXT NULL,
    original_price_snapshot INT UNSIGNED NOT NULL,
    group_price_snapshot INT UNSIGNED NOT NULL,

    limit_per_member INT UNSIGNED NOT NULL,

    start_time DATETIME NOT NULL,
    end_time DATETIME NOT NULL,
    status CHAR(1) NOT NULL DEFAULT '1',
    created_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (group_buy_id),

    KEY idx_groupbuy_member_id (member_id),
    UNIQUE KEY uk_groupbuy_product_id (product_id),
    KEY idx_groupbuy_status (status),
    KEY idx_groupbuy_end_time (end_time),

    CONSTRAINT fk_groupbuy_member
        FOREIGN KEY (member_id)
        REFERENCES member(member_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_groupbuy_product
        FOREIGN KEY (product_id)
        REFERENCES product(product_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CHECK (description IS NULL OR CHAR_LENGTH(description) <= 500),
    CHECK (original_price_snapshot > 0),
    CHECK (group_price_snapshot > 0),
    CHECK (group_price_snapshot <= original_price_snapshot),
    CHECK (limit_per_member > 0),
    CHECK (end_time > start_time),
    CHECK (status IN ('1', '2'))
);

-- ============================================================
-- 訂單資料表 purchaseorder
-- order_status:
--   1 = pending_payment
--   2 = paid
--   3 = cancelled
--   4 = completed
--   5 = refunded
-- ============================================================
CREATE TABLE purchaseorder (
    order_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    member_id BIGINT UNSIGNED NOT NULL,
    group_buy_id BIGINT UNSIGNED NOT NULL,
    order_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    order_status CHAR(1) NOT NULL DEFAULT '1',
    quantity INT UNSIGNED NOT NULL,
    unit_price_snapshot INT UNSIGNED NOT NULL,
    total_amount INT UNSIGNED
        GENERATED ALWAYS AS (quantity * unit_price_snapshot) STORED,
    pickup_location CHAR(50) NULL,
    created_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (order_id),

    KEY idx_purchaseorder_member_id (member_id),
    KEY idx_purchaseorder_group_buy_id (group_buy_id),
    KEY idx_purchaseorder_status (order_status),
    KEY idx_purchaseorder_order_time (order_time),

    CONSTRAINT fk_purchaseorder_member
        FOREIGN KEY (member_id)
        REFERENCES member(member_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_purchaseorder_groupbuy
        FOREIGN KEY (group_buy_id)
        REFERENCES groupbuy(group_buy_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CHECK (order_status IN ('1', '2', '3', '4', '5')),
    CHECK (quantity > 0),
    CHECK (unit_price_snapshot > 0)
);

-- ============================================================
-- 付款資料表 payment
-- payment_method:
--   1 = bank_transfer
--   2 = credit_card
--   3 = line_pay
--   4 = cash
-- payment_status:
--   1 = pending
--   2 = success
--   3 = failed
--   4 = refunded
-- ============================================================
CREATE TABLE payment (
    payment_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    order_id BIGINT UNSIGNED NOT NULL,
    payment_method CHAR(1) NOT NULL,
    payment_amount INT UNSIGNED NOT NULL,
    payment_status CHAR(1) NOT NULL DEFAULT '1',
    paid_time DATETIME NULL,
    created_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (payment_id),

    KEY idx_payment_order_id (order_id),
    KEY idx_payment_method (payment_method),
    KEY idx_payment_status (payment_status),
    KEY idx_payment_paid_time (paid_time),

    CONSTRAINT fk_payment_purchaseorder
        FOREIGN KEY (order_id)
        REFERENCES purchaseorder(order_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CHECK (payment_method IN ('1', '2', '3', '4')),
    CHECK (payment_amount > 0),
    CHECK (payment_status IN ('1', '2', '3', '4')),
    CHECK (payment_status <> '2' OR paid_time IS NOT NULL)
);

-- ============================================================
-- 履約資料表 fulfillment
-- fulfillment_type:
--   1 = delivery
--   2 = pickup
-- fulfillment_status:
--   1 = pending
--   2 = preparing
--   3 = shipped
--   4 = picked_up
--   5 = completed
-- ============================================================
CREATE TABLE fulfillment (
    fulfillment_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    order_id BIGINT UNSIGNED NOT NULL,
    fulfillment_type CHAR(1) NOT NULL,
    recipient_name CHAR(10) NOT NULL,
    recipient_phone CHAR(10) NOT NULL,
    address CHAR(50) NULL,
    tracking_no CHAR(20) NULL,
    fulfillment_status CHAR(1) NOT NULL DEFAULT '1',
    fulfilled_time DATETIME NULL,
    created_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (fulfillment_id),

    UNIQUE KEY uk_fulfillment_order_id (order_id),
    UNIQUE KEY uk_fulfillment_tracking_no (tracking_no),

    KEY idx_fulfillment_type (fulfillment_type),
    KEY idx_fulfillment_status (fulfillment_status),
    KEY idx_fulfillment_created_time (created_time),

    CONSTRAINT fk_fulfillment_purchaseorder
        FOREIGN KEY (order_id)
        REFERENCES purchaseorder(order_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CHECK (fulfillment_type IN ('1', '2')),
    CHECK (fulfillment_status IN ('1', '2', '3', '4', '5')),
    CHECK (recipient_phone REGEXP '^[0-9]{10}$'),

    -- 宅配 delivery 時，地址不可為空；自取 pickup 時，地址可以為空
    CHECK (fulfillment_type <> '1' OR address IS NOT NULL),

    -- 完成履約時，完成時間不可為空
    CHECK (fulfillment_status <> '5' OR fulfilled_time IS NOT NULL)
);
