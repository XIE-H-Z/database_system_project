-- ============================================================
-- 團購系統資料庫 Schema（MariaDB）
-- 來源：資料庫作業一.pptx
-- 設計原則：
--   1. 依 PPT 定義建立 Member、Supplier、Product、GroupBuy、GroupBuyItem、PurchaseOrder、OrderItem、Payment、Fulfillment、groupbuytable。
--   2. 欄位命名統一為 lower_snake_case；例如 PPT 的 Group_price / End_time / Sub_total 改為 group_price / end_time / sub_total。
--   3. 非必要時不使用 VARCHAR：狀態值用 ENUM，固定長度可識別資料用 CHAR，說明文字用 TEXT + CHECK 控制長度。
--      只有 email 與 tracking_no 因需要唯一索引或常見變動長度索引，使用 VARCHAR。
--   4. 需要跨資料表檢查的規則以 TRIGGER 實作；衍生小計 sub_total 用 GENERATED COLUMN。
-- ============================================================

CREATE DATABASE IF NOT EXISTS `group_buying_system`
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;

USE `group_buying_system`;
SET NAMES utf8mb4;
SET time_zone = '+08:00';

DROP VIEW IF EXISTS `v_group_buy_progress`;
DROP PROCEDURE IF EXISTS `sp_recalc_order_total`;

DROP TABLE IF EXISTS `groupbuytable`;
DROP TABLE IF EXISTS `Fulfillment`;
DROP TABLE IF EXISTS `Payment`;
DROP TABLE IF EXISTS `OrderItem`;
DROP TABLE IF EXISTS `PurchaseOrder`;
DROP TABLE IF EXISTS `GroupBuyItem`;
DROP TABLE IF EXISTS `GroupBuy`;
DROP TABLE IF EXISTS `Product`;
DROP TABLE IF EXISTS `Supplier`;
DROP TABLE IF EXISTS `Member`;

-- ============================================================
-- 1. 會員 Member
-- ============================================================
CREATE TABLE `Member` (
  `member_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '會員編號',
  `email` VARCHAR(254) NOT NULL COMMENT '電子郵件；唯一替代鍵，因需完整唯一索引故使用 VARCHAR',
  `phone` CHAR(20) NOT NULL COMMENT '手機號碼；唯一替代鍵',
  `password_hash` CHAR(60) NOT NULL COMMENT '密碼雜湊值，例如 bcrypt 長度 60',
  `name` TEXT NOT NULL COMMENT '會員姓名',
  `role` ENUM('member','organizer','admin') NOT NULL COMMENT '會員角色',
  `status` ENUM('active','inactive','banned') NOT NULL DEFAULT 'active' COMMENT '帳號狀態',
  `created_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
  `updated_time` DATETIME NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP COMMENT '更新時間',
  CONSTRAINT `pk_member` PRIMARY KEY (`member_id`),
  CONSTRAINT `uk_member_email` UNIQUE (`email`),
  CONSTRAINT `uk_member_phone` UNIQUE (`phone`),
  CONSTRAINT `chk_member_name_len` CHECK (CHAR_LENGTH(`name`) BETWEEN 1 AND 100)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='會員';

-- ============================================================
-- 2. 供應商 Supplier
-- ============================================================
CREATE TABLE `Supplier` (
  `supplier_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '供應商編號',
  `supplier_name` TEXT NOT NULL COMMENT '供應商名稱',
  `contact_name` TEXT NULL COMMENT '聯絡人姓名',
  `phone` CHAR(20) NULL COMMENT '聯絡電話',
  `email` TEXT NULL COMMENT '聯絡 Email；未設唯一索引，因此不使用 VARCHAR',
  `address` TEXT NULL COMMENT '地址',
  `status` ENUM('active','inactive') NOT NULL DEFAULT 'active' COMMENT '供應商狀態',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
  CONSTRAINT `pk_supplier` PRIMARY KEY (`supplier_id`),
  CONSTRAINT `chk_supplier_name_len` CHECK (CHAR_LENGTH(`supplier_name`) BETWEEN 1 AND 100),
  CONSTRAINT `chk_supplier_contact_len` CHECK (`contact_name` IS NULL OR CHAR_LENGTH(`contact_name`) <= 100),
  CONSTRAINT `chk_supplier_email_len` CHECK (`email` IS NULL OR CHAR_LENGTH(`email`) <= 254)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='供應商';

-- ============================================================
-- 3. 商品 Product
-- ============================================================
CREATE TABLE `Product` (
  `product_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '商品編號',
  `supplier_id` BIGINT UNSIGNED NOT NULL COMMENT '供應商編號',
  `product_name` TEXT NOT NULL COMMENT '商品名稱；最多 50 字',
  `description` TEXT NULL COMMENT '商品描述；最多 500 字',
  `original_price` DECIMAL(12,2) NOT NULL COMMENT '商品原價',
  `group_price` DECIMAL(12,2) NOT NULL COMMENT '商品優惠價；PPT 原欄位為 Group_price',
  `stock_quantity` INT UNSIGNED NOT NULL COMMENT '庫存數量',
  `status` ENUM('active','inactive','discontinued') NOT NULL DEFAULT 'active' COMMENT '商品狀態',
  `created_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
  `end_time` DATETIME NOT NULL COMMENT '結束時間；PPT 原欄位為 End_time',
  CONSTRAINT `pk_product` PRIMARY KEY (`product_id`),
  CONSTRAINT `fk_product_supplier` FOREIGN KEY (`supplier_id`) REFERENCES `Supplier` (`supplier_id`),
  CONSTRAINT `chk_product_name_len` CHECK (CHAR_LENGTH(`product_name`) BETWEEN 1 AND 50),
  CONSTRAINT `chk_product_description_len` CHECK (`description` IS NULL OR CHAR_LENGTH(`description`) <= 500),
  CONSTRAINT `chk_product_original_price` CHECK (`original_price` >= 0),
  CONSTRAINT `chk_product_group_price` CHECK (`group_price` >= 0),
  CONSTRAINT `chk_product_stock_quantity` CHECK (`stock_quantity` >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='商品';

CREATE INDEX `idx_product_supplier_id` ON `Product` (`supplier_id`);
CREATE INDEX `idx_product_status` ON `Product` (`status`);

-- ============================================================
-- 4. 團購活動 GroupBuy
-- ============================================================
CREATE TABLE `GroupBuy` (
  `group_buy_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '團購活動編號',
  `member_id` BIGINT UNSIGNED NOT NULL COMMENT '團主會員編號',
  `title` TEXT NOT NULL COMMENT '團購標題；最多 50 字',
  `description` TEXT NULL COMMENT '團購說明；最多 500 字',
  `start_time` DATETIME NOT NULL COMMENT '開始時間',
  `end_time` DATETIME NOT NULL COMMENT '結束時間，必須晚於 start_time',
  `min_quantity` INT UNSIGNED NOT NULL COMMENT '最低成團數量',
  `max_quantity` INT UNSIGNED NULL COMMENT '最大可訂購數量；若有值需 >= min_quantity',
  `created_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
  `status` ENUM('active','end') NOT NULL DEFAULT 'active' COMMENT '團購狀態；PPT 表格中 staus 修正為 status',
  CONSTRAINT `pk_group_buy` PRIMARY KEY (`group_buy_id`),
  CONSTRAINT `fk_group_buy_member` FOREIGN KEY (`member_id`) REFERENCES `Member` (`member_id`),
  CONSTRAINT `chk_group_buy_title_len` CHECK (CHAR_LENGTH(`title`) BETWEEN 1 AND 50),
  CONSTRAINT `chk_group_buy_description_len` CHECK (`description` IS NULL OR CHAR_LENGTH(`description`) <= 500),
  CONSTRAINT `chk_group_buy_time` CHECK (`end_time` > `start_time`),
  CONSTRAINT `chk_group_buy_min_quantity` CHECK (`min_quantity` > 0),
  CONSTRAINT `chk_group_buy_max_quantity` CHECK (`max_quantity` IS NULL OR `max_quantity` >= `min_quantity`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='團購活動';

CREATE INDEX `idx_group_buy_member_id` ON `GroupBuy` (`member_id`);
CREATE INDEX `idx_group_buy_status` ON `GroupBuy` (`status`);
CREATE INDEX `idx_group_buy_time` ON `GroupBuy` (`start_time`, `end_time`);

-- ============================================================
-- 5. 團購商品 GroupBuyItem
-- ============================================================
CREATE TABLE `GroupBuyItem` (
  `group_buy_item_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '團購商品編號',
  `group_buy_id` BIGINT UNSIGNED NOT NULL COMMENT '團購活動編號',
  `product_id` BIGINT UNSIGNED NOT NULL COMMENT '商品編號',
  `group_price` DECIMAL(12,2) NOT NULL COMMENT '團購價格',
  `quota_quantity` INT UNSIGNED NOT NULL COMMENT '可團購數量上限；需 <= Product.stock_quantity',
  `limit_per_member` INT UNSIGNED NULL COMMENT '每位會員限購數量；若有值需 > 0',
  `status` ENUM('active','inactive','sold_out') NOT NULL DEFAULT 'active' COMMENT '團購商品狀態',
  `original_price` DECIMAL(12,2) NOT NULL COMMENT '商品原價格快照',
  CONSTRAINT `pk_group_buy_item` PRIMARY KEY (`group_buy_item_id`),
  CONSTRAINT `fk_group_buy_item_group_buy` FOREIGN KEY (`group_buy_id`) REFERENCES `GroupBuy` (`group_buy_id`),
  CONSTRAINT `fk_group_buy_item_product` FOREIGN KEY (`product_id`) REFERENCES `Product` (`product_id`),
  CONSTRAINT `uk_group_buy_item_group_product` UNIQUE (`group_buy_id`, `product_id`),
  CONSTRAINT `chk_group_buy_item_group_price` CHECK (`group_price` > 0),
  CONSTRAINT `chk_group_buy_item_quota_quantity` CHECK (`quota_quantity` > 0),
  CONSTRAINT `chk_group_buy_item_limit_per_member` CHECK (`limit_per_member` IS NULL OR `limit_per_member` > 0),
  CONSTRAINT `chk_group_buy_item_original_price` CHECK (`original_price` >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='團購商品';

CREATE INDEX `idx_group_buy_item_group_buy_id` ON `GroupBuyItem` (`group_buy_id`);
CREATE INDEX `idx_group_buy_item_product_id` ON `GroupBuyItem` (`product_id`);
CREATE INDEX `idx_group_buy_item_status` ON `GroupBuyItem` (`status`);

-- ============================================================
-- 6. 訂單 PurchaseOrder
-- ============================================================
CREATE TABLE `PurchaseOrder` (
  `order_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '訂單編號',
  `member_id` BIGINT UNSIGNED NOT NULL COMMENT '會員編號',
  `group_buy_id` BIGINT UNSIGNED NOT NULL COMMENT '團購活動編號',
  `order_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '下單時間',
  `order_status` ENUM('pending_payment','paid','cancelled','completed','refunded') NOT NULL DEFAULT 'pending_payment' COMMENT '訂單付款/交易狀態',
  `total_amount` DECIMAL(12,2) NOT NULL DEFAULT 0.00 COMMENT '訂單總金額；由 OrderItem 觸發器回寫',
  `note` TEXT NULL COMMENT '備註；最多 200 字',
  `created_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
  `status` ENUM('draft','active','closed','cancelled','completed') NOT NULL DEFAULT 'draft' COMMENT '訂單生命週期狀態',
  `pickup_location` TEXT NULL COMMENT '取貨地點',
  CONSTRAINT `pk_purchase_order` PRIMARY KEY (`order_id`),
  CONSTRAINT `fk_purchase_order_member` FOREIGN KEY (`member_id`) REFERENCES `Member` (`member_id`),
  CONSTRAINT `fk_purchase_order_group_buy` FOREIGN KEY (`group_buy_id`) REFERENCES `GroupBuy` (`group_buy_id`),
  CONSTRAINT `chk_purchase_order_total_amount` CHECK (`total_amount` >= 0),
  CONSTRAINT `chk_purchase_order_note_len` CHECK (`note` IS NULL OR CHAR_LENGTH(`note`) <= 200)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='訂單';

CREATE INDEX `idx_purchase_order_member_id` ON `PurchaseOrder` (`member_id`);
CREATE INDEX `idx_purchase_order_group_buy_id` ON `PurchaseOrder` (`group_buy_id`);
CREATE INDEX `idx_purchase_order_order_status` ON `PurchaseOrder` (`order_status`);

-- ============================================================
-- 7. 訂單明細 OrderItem
-- ============================================================
CREATE TABLE `OrderItem` (
  `order_item_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '訂單明細編號',
  `order_id` BIGINT UNSIGNED NOT NULL COMMENT '訂單編號',
  `group_buy_item_id` BIGINT UNSIGNED NOT NULL COMMENT '團購商品編號',
  `quantity` INT UNSIGNED NOT NULL COMMENT '訂購數量',
  `unit_price_snapshot` DECIMAL(12,2) NOT NULL COMMENT '下單時單價',
  `sub_total` DECIMAL(12,2) GENERATED ALWAYS AS (`quantity` * `unit_price_snapshot`) STORED COMMENT '小計金額，衍生欄位：quantity * unit_price_snapshot',
  CONSTRAINT `pk_order_item` PRIMARY KEY (`order_item_id`),
  CONSTRAINT `fk_order_item_order` FOREIGN KEY (`order_id`) REFERENCES `PurchaseOrder` (`order_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_order_item_group_buy_item` FOREIGN KEY (`group_buy_item_id`) REFERENCES `GroupBuyItem` (`group_buy_item_id`),
  CONSTRAINT `uk_order_item_order_group_buy_item` UNIQUE (`order_id`, `group_buy_item_id`),
  CONSTRAINT `chk_order_item_quantity` CHECK (`quantity` > 0),
  CONSTRAINT `chk_order_item_unit_price_snapshot` CHECK (`unit_price_snapshot` > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='訂單明細';

CREATE INDEX `idx_order_item_order_id` ON `OrderItem` (`order_id`);
CREATE INDEX `idx_order_item_group_buy_item_id` ON `OrderItem` (`group_buy_item_id`);

-- ============================================================
-- 8. 付款 Payment
-- ============================================================
CREATE TABLE `Payment` (
  `payment_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '付款編號',
  `order_id` BIGINT UNSIGNED NOT NULL COMMENT '訂單編號',
  `payment_method` ENUM('bank_transfer','credit_card','line_pay','cash') NOT NULL COMMENT '付款方式',
  `payment_amount` DECIMAL(12,2) NOT NULL COMMENT '付款金額',
  `payment_status` ENUM('pending','success','failed','refunded') NOT NULL DEFAULT 'pending' COMMENT '付款狀態',
  `paid_time` DATETIME NULL COMMENT '付款完成時間',
  `created_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
  CONSTRAINT `pk_payment` PRIMARY KEY (`payment_id`),
  CONSTRAINT `fk_payment_order` FOREIGN KEY (`order_id`) REFERENCES `PurchaseOrder` (`order_id`),
  CONSTRAINT `chk_payment_amount` CHECK (`payment_amount` > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='付款';

CREATE INDEX `idx_payment_order_id` ON `Payment` (`order_id`);
CREATE INDEX `idx_payment_status` ON `Payment` (`payment_status`);

-- ============================================================
-- 9. 履約 Fulfillment
-- ============================================================
CREATE TABLE `Fulfillment` (
  `fulfillment_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '履約編號',
  `order_id` BIGINT UNSIGNED NOT NULL COMMENT '訂單編號；唯一，確保一筆訂單對應一筆履約',
  `fulfillment_type` ENUM('delivery','pickup') NOT NULL COMMENT '履約方式',
  `recipient_name` TEXT NULL COMMENT '收件人或取貨人姓名',
  `recipient_phone` CHAR(20) NULL COMMENT '收件人電話',
  `address` TEXT NULL COMMENT '配送地址',
  `tracking_no` VARCHAR(64) NULL COMMENT '物流追蹤編號；替代鍵，因需完整唯一索引故使用 VARCHAR',
  `fulfillment_status` ENUM('pending','preparing','shipped','picked_up','completed') NOT NULL DEFAULT 'pending' COMMENT '履約狀態',
  `fulfilled_time` DATETIME NULL COMMENT '完成配送或取貨時間',
  `created_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '建立時間',
  CONSTRAINT `pk_fulfillment` PRIMARY KEY (`fulfillment_id`),
  CONSTRAINT `uk_fulfillment_order_id` UNIQUE (`order_id`),
  CONSTRAINT `uk_fulfillment_tracking_no` UNIQUE (`tracking_no`),
  CONSTRAINT `fk_fulfillment_order` FOREIGN KEY (`order_id`) REFERENCES `PurchaseOrder` (`order_id`),
  CONSTRAINT `chk_fulfillment_recipient_name_len` CHECK (`recipient_name` IS NULL OR CHAR_LENGTH(`recipient_name`) <= 100)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='履約';

CREATE INDEX `idx_fulfillment_status` ON `Fulfillment` (`fulfillment_status`);

-- ============================================================
-- 10. 團購表 groupbuytable
--     備註：此表依 PPT 保留；在正規化設計中，GroupBuyItem 已可表示 GroupBuy 與 Product 的關聯。
-- ============================================================
CREATE TABLE `groupbuytable` (
  `groupbuytable_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '團購表編號',
  `group_buy_id` BIGINT UNSIGNED NOT NULL COMMENT '團購活動編號；PPT 原欄位為 Group_buy_id',
  `group_buy_item_id` BIGINT UNSIGNED NOT NULL COMMENT '團購商品編號；PPT 原欄位為 Group_buy_item_id',
  `status` ENUM('active','inactive','end') NOT NULL DEFAULT 'active' COMMENT '團購狀態',
  CONSTRAINT `pk_groupbuytable` PRIMARY KEY (`groupbuytable_id`),
  CONSTRAINT `uk_groupbuytable_group_buy_id` UNIQUE (`group_buy_id`),
  CONSTRAINT `uk_groupbuytable_group_buy_item_id` UNIQUE (`group_buy_item_id`),
  CONSTRAINT `fk_groupbuytable_group_buy` FOREIGN KEY (`group_buy_id`) REFERENCES `GroupBuy` (`group_buy_id`),
  CONSTRAINT `fk_groupbuytable_group_buy_item` FOREIGN KEY (`group_buy_item_id`) REFERENCES `GroupBuyItem` (`group_buy_item_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='團購表';

-- ============================================================
-- 觸發器與程序：跨表商業規則與訂單總額回寫
-- ============================================================
DELIMITER //

CREATE TRIGGER `bi_group_buy_item_check_stock`
BEFORE INSERT ON `GroupBuyItem`
FOR EACH ROW
BEGIN
  DECLARE v_stock_quantity INT UNSIGNED;

  SELECT `stock_quantity`
    INTO v_stock_quantity
    FROM `Product`
   WHERE `product_id` = NEW.`product_id`
   LIMIT 1;

  IF NEW.`quota_quantity` > v_stock_quantity THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'quota_quantity cannot exceed Product.stock_quantity';
  END IF;
END//

CREATE TRIGGER `bu_group_buy_item_check_stock`
BEFORE UPDATE ON `GroupBuyItem`
FOR EACH ROW
BEGIN
  DECLARE v_stock_quantity INT UNSIGNED;

  SELECT `stock_quantity`
    INTO v_stock_quantity
    FROM `Product`
   WHERE `product_id` = NEW.`product_id`
   LIMIT 1;

  IF NEW.`quota_quantity` > v_stock_quantity THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'quota_quantity cannot exceed Product.stock_quantity';
  END IF;
END//

CREATE PROCEDURE `sp_recalc_order_total`(IN p_order_id BIGINT UNSIGNED)
BEGIN
  UPDATE `PurchaseOrder` AS po
     SET po.`total_amount` = (
       SELECT COALESCE(SUM(oi.`sub_total`), 0.00)
         FROM `OrderItem` AS oi
        WHERE oi.`order_id` = p_order_id
     )
   WHERE po.`order_id` = p_order_id;
END//

CREATE TRIGGER `ai_order_item_recalc_total`
AFTER INSERT ON `OrderItem`
FOR EACH ROW
BEGIN
  CALL `sp_recalc_order_total`(NEW.`order_id`);
END//

CREATE TRIGGER `au_order_item_recalc_total`
AFTER UPDATE ON `OrderItem`
FOR EACH ROW
BEGIN
  IF OLD.`order_id` <> NEW.`order_id` THEN
    CALL `sp_recalc_order_total`(OLD.`order_id`);
  END IF;
  CALL `sp_recalc_order_total`(NEW.`order_id`);
END//

CREATE TRIGGER `ad_order_item_recalc_total`
AFTER DELETE ON `OrderItem`
FOR EACH ROW
BEGIN
  CALL `sp_recalc_order_total`(OLD.`order_id`);
END//

DELIMITER ;

-- ============================================================
-- 檢視表：團購進度
-- paid / completed 訂單納入成團統計，取消與退款不納入。
-- ============================================================
CREATE VIEW `v_group_buy_progress` AS
SELECT
  gb.`group_buy_id`,
  gb.`title`,
  gbi.`group_buy_item_id`,
  gbi.`product_id`,
  gb.`min_quantity`,
  gb.`max_quantity`,
  gbi.`quota_quantity`,
  COALESCE(SUM(CASE WHEN po.`order_id` IS NOT NULL THEN oi.`quantity` ELSE 0 END), 0) AS `ordered_quantity`,
  CASE
    WHEN COALESCE(SUM(CASE WHEN po.`order_id` IS NOT NULL THEN oi.`quantity` ELSE 0 END), 0) >= gb.`min_quantity` THEN 'qualified'
    ELSE 'not_yet'
  END AS `formation_status`
FROM `GroupBuy` AS gb
JOIN `GroupBuyItem` AS gbi
  ON gbi.`group_buy_id` = gb.`group_buy_id`
LEFT JOIN `OrderItem` AS oi
  ON oi.`group_buy_item_id` = gbi.`group_buy_item_id`
LEFT JOIN `PurchaseOrder` AS po
  ON po.`order_id` = oi.`order_id`
 AND po.`order_status` IN ('paid', 'completed')
GROUP BY
  gb.`group_buy_id`, gb.`title`, gbi.`group_buy_item_id`, gbi.`product_id`,
  gb.`min_quantity`, gb.`max_quantity`, gbi.`quota_quantity`;
