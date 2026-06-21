-- ============================================================
-- 團購系統 View SQL
-- 版本：role_flow_v3
-- 說明：
--   1. member 開團前仍是 member，所以「可開團商品」與「新增團購」放在 member View。
--   2. 使用作法一：member 建立 groupbuy 成功後，由程式執行 UPDATE member SET role='2'。
--   3. organizer View 只負責管理自己已建立的團購。
--   4. 所有資料表別名使用大寫，避免與欄位名稱混淆。
--   5. 每個 View 的備註都有查詢方式。
-- ============================================================

USE group_buying_system;

-- ============================================================
-- 先刪除舊 View，避免重複建立失敗
-- ============================================================
DROP VIEW IF EXISTS v_m_active_product_list;
DROP VIEW IF EXISTS v_m_available_product_for_groupbuy;
DROP VIEW IF EXISTS v_m_open_groupbuy_list;
DROP VIEW IF EXISTS v_m_groupbuy_progress;
DROP VIEW IF EXISTS v_m_create_active_groupbuy;
DROP VIEW IF EXISTS v_m_create_pending_order;
DROP VIEW IF EXISTS v_m_delete_pending_order;

DROP VIEW IF EXISTS v_o_my_groupbuy_summary;
DROP VIEW IF EXISTS v_o_my_groupbuy_orders;
DROP VIEW IF EXISTS v_o_delete_active_groupbuy;

DROP VIEW IF EXISTS v_a_member_full_list;
DROP VIEW IF EXISTS v_a_supplier_full_list;
DROP VIEW IF EXISTS v_a_product_full_list;
DROP VIEW IF EXISTS v_a_groupbuy_full_list;
DROP VIEW IF EXISTS v_a_order_payment_fulfillment_detail;
DROP VIEW IF EXISTS v_a_create_active_member;
DROP VIEW IF EXISTS v_a_create_active_supplier;
DROP VIEW IF EXISTS v_a_create_active_product;
DROP VIEW IF EXISTS v_a_delete_inactive_member;
DROP VIEW IF EXISTS v_a_delete_inactive_supplier;
DROP VIEW IF EXISTS v_a_delete_inactive_product;

-- ============================================================
-- member 身分組 View
-- ============================================================

-- ------------------------------------------------------------
-- View：v_m_active_product_list
-- 身分：member
-- 功能：一般會員瀏覽目前可購買、可瀏覽的商品。
-- 條件：
--   1. 商品狀態必須是 active。
--   2. 供應商狀態必須是 active。
--   3. 商品期限必須尚未過期。
--   4. 商品庫存必須大於 0。
-- 查詢：
--   SELECT * FROM v_m_active_product_list;
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_m_active_product_list AS
SELECT
    P.product_id,
    P.product_name,
    P.brand,
    P.description,
    P.original_price,
    P.group_price,
    P.stock_quantity,
    P.end_time,
    S.supplier_name
FROM product P
JOIN supplier S
    ON P.supplier_id = S.supplier_id
WHERE P.status = '1'
  AND S.status = '1'
  AND P.end_time > CURRENT_TIMESTAMP
  AND P.stock_quantity > 0;

-- ------------------------------------------------------------
-- View：v_m_available_product_for_groupbuy
-- 身分：member
-- 功能：member 開團前查看哪些商品可以拿來建立團購。
-- 條件：
--   1. 商品狀態必須是 active。
--   2. 供應商狀態必須是 active。
--   3. 商品期限必須尚未過期。
--   4. 庫存必須大於等於最低成團數。
-- 查詢：
--   SELECT * FROM v_m_available_product_for_groupbuy;
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_m_available_product_for_groupbuy AS
SELECT
    P.product_id,
    P.product_name,
    P.brand,
    P.description,
    P.original_price,
    P.group_price,
    P.stock_quantity,
    P.min_quantity,
    P.max_quantity,
    P.end_time,
    S.supplier_name,
    'available_for_groupbuy' AS groupbuy_available_status
FROM product P
JOIN supplier S
    ON P.supplier_id = S.supplier_id
WHERE P.status = '1'
  AND S.status = '1'
  AND P.end_time > CURRENT_TIMESTAMP
  AND P.stock_quantity >= P.min_quantity;

-- ------------------------------------------------------------
-- View：v_m_open_groupbuy_list
-- 身分：member
-- 功能：一般會員瀏覽目前進行中的團購活動。
-- 條件：
--   1. 團購狀態必須是 active。
--   2. 商品與供應商都必須是 active。
--   3. 現在時間必須介於團購 start_time 與 end_time 之間。
-- 查詢：
--   SELECT * FROM v_m_open_groupbuy_list;
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_m_open_groupbuy_list AS
SELECT
    G.group_buy_id,
    G.title,
    G.description,
    P.product_name,
    P.brand,
    S.supplier_name,
    G.original_price_snapshot,
    G.group_price_snapshot,
    P.min_quantity,
    P.max_quantity,
    G.limit_per_member,
    G.start_time,
    G.end_time,
    M.name AS organizer_name
FROM groupbuy G
JOIN product P
    ON G.product_id = P.product_id
JOIN supplier S
    ON P.supplier_id = S.supplier_id
JOIN member M
    ON G.member_id = M.member_id
WHERE G.status = '1'
  AND P.status = '1'
  AND S.status = '1'
  AND G.start_time <= CURRENT_TIMESTAMP
  AND G.end_time > CURRENT_TIMESTAMP;

-- ------------------------------------------------------------
-- View：v_m_groupbuy_progress
-- 身分：member
-- 功能：一般會員查看團購進度。
-- 條件：
--   1. 只顯示 active 團購。
--   2. 只統計 pending_payment、paid、completed 訂單。
--   3. cancelled、refunded 不計入成團進度。
-- 查詢：
--   SELECT * FROM v_m_groupbuy_progress;
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_m_groupbuy_progress AS
SELECT
    G.group_buy_id,
    G.title,
    P.product_name,
    P.min_quantity,
    P.max_quantity,
    COALESCE(COUNT(DISTINCT PO.member_id), 0) AS participant_count,
    COALESCE(SUM(PO.quantity), 0) AS ordered_quantity,
    ROUND(
        COALESCE(SUM(PO.quantity), 0) / P.min_quantity * 100,
        2
    ) AS progress_percent,
    CASE
        WHEN COALESCE(SUM(PO.quantity), 0) >= P.min_quantity THEN 'formed'
        ELSE 'not_formed'
    END AS formed_status
FROM groupbuy G
JOIN product P
    ON G.product_id = P.product_id
LEFT JOIN purchaseorder PO
    ON G.group_buy_id = PO.group_buy_id
   AND PO.order_status IN ('1', '2', '4')
WHERE G.status = '1'
GROUP BY
    G.group_buy_id,
    G.title,
    P.product_name,
    P.min_quantity,
    P.max_quantity;

-- ------------------------------------------------------------
-- View：v_m_create_active_groupbuy
-- 身分：member
-- 功能：member 建立 active 團購。
-- 條件：
--   1. 只能新增 status = '1' 的 active 團購。
--   2. end_time 必須晚於 start_time。
--   3. WITH CHECK OPTION 會阻擋新增不符合條件的資料。
-- 查詢：
--   SELECT * FROM v_m_create_active_groupbuy;
-- 新增範例：
--   要先新增商品：
--INSERT INTO v_a_create_active_product
--(    supplier_id,product_name,brand,description,original_price,group_price,stock_quantity,
--    status,end_time,max_quantity,min_quantity)
--VALUES( 1,'芒果乾禮盒','玉井農會','台南玉井芒果乾，適合團購測試。',500,399,80,'1','2026-08-31 23:59:59',60,10);

--   INSERT INTO v_m_create_active_groupbuy
--  (member_id, product_id, title, description, original_price_snapshot, group_price_snapshot,
--   limit_per_member, start_time, end_time)
--  VALUES
--  (12, 12, '芒果乾開團測試', 'member 建立芒果乾團購測試。', 600, 450,
--    3, '2026-06-01 12:00:00', '2026-08-31 23:59:59');
-- 開團後升級 organizer，作法一：
--   UPDATE member SET role = '2' WHERE member_id = 12;
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_m_create_active_groupbuy AS
SELECT
    group_buy_id,
    member_id,
    product_id,
    title,
    description,
    original_price_snapshot,
    group_price_snapshot,
    limit_per_member,
    start_time,
    end_time,
    status,
    created_time
FROM groupbuy
WHERE status = '1'
  AND end_time > start_time
WITH CASCADED CHECK OPTION;

-- ------------------------------------------------------------
-- View：v_m_create_pending_order
-- 身分：member
-- 功能：member 加入團購並建立待付款訂單。
-- 條件：
--   1. 只能新增 order_status = '1' 的 pending_payment 訂單。
--   2. WITH CHECK OPTION 會阻擋新增成 paid、cancelled 等狀態。
-- 查詢：
--   SELECT * FROM v_m_create_pending_order;
-- 新增範例：
--   INSERT INTO v_m_create_pending_order
--   (member_id, group_buy_id, quantity, unit_price_snapshot, pickup_location)
--   VALUES
--   (2, 1, 1, 450, '校門口取貨點');
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_m_create_pending_order AS
SELECT
    order_id,
    member_id,
    group_buy_id,
    order_time,
    order_status,
    quantity,
    unit_price_snapshot,
    pickup_location,
    created_time
FROM purchaseorder
WHERE order_status = '1'
WITH CASCADED CHECK OPTION;

-- ------------------------------------------------------------
-- View：v_m_delete_pending_order
-- 身分：member
-- 功能：member 刪除尚未付款的訂單。
-- 條件：
--   1. 只能刪除 order_status = '1' 的 pending_payment 訂單。
--   2. 如果該訂單已被 payment 或 fulfillment 參照，可能會被外鍵限制擋下。
-- 查詢：
--   SELECT * FROM v_m_delete_pending_order;
-- 刪除範例：
--   DELETE FROM v_m_delete_pending_order WHERE order_id = 11;
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_m_delete_pending_order AS
SELECT
    order_id,
    member_id,
    group_buy_id,
    order_time,
    order_status,
    quantity,
    unit_price_snapshot,
    pickup_location,
    created_time
FROM purchaseorder
WHERE order_status = '1';

-- ============================================================
-- organizer 身分組 View
-- ============================================================

-- ------------------------------------------------------------
-- View：v_o_my_groupbuy_summary
-- 身分：organizer
-- 功能：團主查看自己建立的 active 團購統計。
-- 條件：
--   1. 只顯示 active 團購。
--   2. 只統計 pending_payment、paid、completed 訂單。
-- 查詢全部：
--   SELECT * FROM v_o_my_groupbuy_summary;
-- 查詢某位團主，例如 member_id = 1：
--   SELECT * FROM v_o_my_groupbuy_summary WHERE organizer_id = 1;
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_o_my_groupbuy_summary AS
SELECT
    G.group_buy_id,
    G.member_id AS organizer_id,
    M.name AS organizer_name,
    G.title,
    P.product_name,
    P.min_quantity,
    P.max_quantity,
    G.limit_per_member,
    COALESCE(COUNT(DISTINCT PO.member_id), 0) AS participant_count,
    COALESCE(SUM(PO.quantity), 0) AS ordered_quantity,
    ROUND(
        COALESCE(SUM(PO.quantity), 0) / P.min_quantity * 100,
        2
    ) AS progress_percent,
    CASE
        WHEN COALESCE(SUM(PO.quantity), 0) >= P.min_quantity THEN 'formed'
        ELSE 'not_formed'
    END AS formed_status,
    G.start_time,
    G.end_time,
    G.status
FROM groupbuy G
JOIN member M
    ON G.member_id = M.member_id
JOIN product P
    ON G.product_id = P.product_id
LEFT JOIN purchaseorder PO
    ON G.group_buy_id = PO.group_buy_id
   AND PO.order_status IN ('1', '2', '4')
WHERE G.status = '1'
GROUP BY
    G.group_buy_id,
    G.member_id,
    M.name,
    G.title,
    P.product_name,
    P.min_quantity,
    P.max_quantity,
    G.limit_per_member,
    G.start_time,
    G.end_time,
    G.status;

-- ------------------------------------------------------------
-- View：v_o_my_groupbuy_orders
-- 身分：organizer
-- 功能：團主查看自己團購底下的訂單明細。
-- 條件：
--   1. 只顯示 active 團購。
--   2. 不顯示 cancelled 訂單。
-- 查詢全部：
--   SELECT * FROM v_o_my_groupbuy_orders;
-- 查詢某位團主，例如 member_id = 1：
--   SELECT * FROM v_o_my_groupbuy_orders WHERE organizer_id = 1;
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_o_my_groupbuy_orders AS
SELECT
    G.group_buy_id,
    G.title AS groupbuy_title,
    G.member_id AS organizer_id,
    M.name AS organizer_name,
    PO.order_id,
    PO.member_id AS buyer_id,
    BUYER.name AS buyer_name,
    P.product_name,
    PO.quantity,
    PO.unit_price_snapshot,
    PO.total_amount,
    PO.order_time,
    PO.order_status
FROM groupbuy G
JOIN member M
    ON G.member_id = M.member_id
JOIN product P
    ON G.product_id = P.product_id
JOIN purchaseorder PO
    ON G.group_buy_id = PO.group_buy_id
JOIN member BUYER
    ON PO.member_id = BUYER.member_id
WHERE G.status = '1'
  AND PO.order_status <> '3';

-- ------------------------------------------------------------
-- View：v_o_delete_active_groupbuy
-- 身分：organizer
-- 功能：團主刪除 active 團購。
-- 條件：
--   1. 只能刪除 status = '1' 的 active 團購。
--   2. 若該團購已經有訂單，會被 purchaseorder 外鍵限制擋下。
-- 查詢：
--   SELECT * FROM v_o_delete_active_groupbuy;
-- 刪除範例：
--DELETE FROM v_o_delete_active_groupbuy WHERE group_buy_id = 13;
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_o_delete_active_groupbuy AS
SELECT
    group_buy_id,
    member_id,
    product_id,
    title,
    description,
    original_price_snapshot,
    group_price_snapshot,
    limit_per_member,
    start_time,
    end_time,
    status,
    created_time
FROM groupbuy
WHERE status = '1';

-- ============================================================
-- admin 身分組 View
-- ============================================================

-- ------------------------------------------------------------
-- View：v_a_member_full_list
-- 身分：admin
-- 功能：管理員查看會員完整清單。
-- 條件：
--   顯示所有會員，並將角色與狀態代碼轉成文字。
-- 查詢：
--   SELECT * FROM v_a_member_full_list;
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_a_member_full_list AS
SELECT
    member_id,
    email,
    phone,
    name,
    CASE role
        WHEN '1' THEN 'member'
        WHEN '2' THEN 'organizer'
        WHEN '3' THEN 'admin'
    END AS role_name,
    CASE status
        WHEN '1' THEN 'active'
        WHEN '2' THEN 'inactive'
        WHEN '3' THEN 'banned'
    END AS status_name,
    created_time,
    updated_time
FROM member;

-- ------------------------------------------------------------
-- View：v_a_supplier_full_list
-- 身分：admin
-- 功能：管理員查看供應商完整清單。
-- 條件：
--   顯示所有供應商，並將狀態代碼轉成文字。
-- 查詢：
--   SELECT * FROM v_a_supplier_full_list;
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_a_supplier_full_list AS
SELECT
    supplier_id,
    supplier_name,
    contact_name,
    phone,
    email,
    address,
    CASE status
        WHEN '1' THEN 'active'
        WHEN '2' THEN 'inactive'
    END AS status_name,
    created_time
FROM supplier;

-- ------------------------------------------------------------
-- View：v_a_product_full_list
-- 身分：admin
-- 功能：管理員查看商品完整清單。
-- 條件：
--   顯示所有商品，並連接供應商名稱。
-- 查詢：
--   SELECT * FROM v_a_product_full_list;
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_a_product_full_list AS
SELECT
    P.product_id,
    P.supplier_id,
    S.supplier_name,
    P.product_name,
    P.brand,
    P.description,
    P.original_price,
    P.group_price,
    P.stock_quantity,
    P.min_quantity,
    P.max_quantity,
    CASE P.status
        WHEN '1' THEN 'active'
        WHEN '2' THEN 'inactive'
        WHEN '3' THEN 'discontinued'
    END AS product_status,
    P.created_time,
    P.end_time
FROM product P
JOIN supplier S
    ON P.supplier_id = S.supplier_id;

-- ------------------------------------------------------------
-- View：v_a_groupbuy_full_list
-- 身分：admin
-- 功能：管理員查看所有團購活動。
-- 條件：
--   顯示所有團購，並連接團主與商品資料。
-- 查詢：
--   SELECT * FROM v_a_groupbuy_full_list;
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_a_groupbuy_full_list AS
SELECT
    G.group_buy_id,
    G.member_id AS organizer_id,
    M.name AS organizer_name,
    G.product_id,
    P.product_name,
    G.title,
    G.description,
    G.original_price_snapshot,
    G.group_price_snapshot,
    G.limit_per_member,
    G.start_time,
    G.end_time,
    CASE G.status
        WHEN '1' THEN 'active'
        WHEN '2' THEN 'end'
    END AS groupbuy_status,
    G.created_time
FROM groupbuy G
JOIN member M
    ON G.member_id = M.member_id
JOIN product P
    ON G.product_id = P.product_id;

-- ------------------------------------------------------------
-- View：v_a_order_payment_fulfillment_detail
-- 身分：admin
-- 功能：管理員查看訂單、付款、履約完整明細。
-- 條件：
--   只排除 cancelled 訂單。
-- 查詢：
--   SELECT * FROM v_a_order_payment_fulfillment_detail;
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_a_order_payment_fulfillment_detail AS
SELECT
    PO.order_id,
    BUYER.member_id,
    BUYER.name AS buyer_name,
    BUYER.email AS buyer_email,
    G.group_buy_id,
    G.title AS groupbuy_title,
    P.product_id,
    P.product_name,
    PO.quantity,
    PO.unit_price_snapshot,
    PO.total_amount,
    CASE PO.order_status
        WHEN '1' THEN 'pending_payment'
        WHEN '2' THEN 'paid'
        WHEN '3' THEN 'cancelled'
        WHEN '4' THEN 'completed'
        WHEN '5' THEN 'refunded'
    END AS order_status_name,
    PAY.payment_id,
    CASE PAY.payment_method
        WHEN '1' THEN 'bank_transfer'
        WHEN '2' THEN 'credit_card'
        WHEN '3' THEN 'line_pay'
        WHEN '4' THEN 'cash'
    END AS payment_method_name,
    PAY.payment_amount,
    CASE PAY.payment_status
        WHEN '1' THEN 'pending'
        WHEN '2' THEN 'success'
        WHEN '3' THEN 'failed'
        WHEN '4' THEN 'refunded'
    END AS payment_status_name,
    PAY.paid_time,
    F.fulfillment_id,
    CASE F.fulfillment_type
        WHEN '1' THEN 'delivery'
        WHEN '2' THEN 'pickup'
    END AS fulfillment_type_name,
    F.recipient_name,
    F.recipient_phone,
    F.address,
    F.tracking_no,
    CASE F.fulfillment_status
        WHEN '1' THEN 'pending'
        WHEN '2' THEN 'preparing'
        WHEN '3' THEN 'shipped'
        WHEN '4' THEN 'picked_up'
        WHEN '5' THEN 'completed'
    END AS fulfillment_status_name,
    F.fulfilled_time
FROM purchaseorder PO
JOIN member BUYER
    ON PO.member_id = BUYER.member_id
JOIN groupbuy G
    ON PO.group_buy_id = G.group_buy_id
JOIN product P
    ON G.product_id = P.product_id
LEFT JOIN payment PAY
    ON PO.order_id = PAY.order_id
LEFT JOIN fulfillment F
    ON PO.order_id = F.order_id
WHERE PO.order_status <> '3';

-- ------------------------------------------------------------
-- View：v_a_create_active_member
-- 身分：admin
-- 功能：管理員新增 active 會員。
-- 條件：
--   只能新增 status = '1' 的 active 會員。
-- 查詢：
--   SELECT * FROM v_a_create_active_member;
-- 新增範例：
--   INSERT INTO v_a_create_active_member
--   (email, phone, name, role, status)
--   VALUES
--   ('new_member@example.com', '0912999999', '新會員', '1', '1');
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_a_create_active_member AS
SELECT
    member_id,
    email,
    phone,
    name,
    role,
    status,
    created_time,
    updated_time
FROM member
WHERE status = '1'
WITH CASCADED CHECK OPTION;

-- ------------------------------------------------------------
-- View：v_a_create_active_supplier
-- 身分：admin
-- 功能：管理員新增 active 供應商。
-- 條件：
--   只能新增 status = '1' 的 active 供應商。
-- 查詢：
--   SELECT * FROM v_a_create_active_supplier;
-- 新增範例：
--   INSERT INTO v_a_create_active_supplier
--   (supplier_name, contact_name, phone, email, address, status)
--   VALUES
--   ('新供應商', '王先生', '0933000001', 'new_supplier@example.com', '雲林縣斗六市新路1號', '1');
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_a_create_active_supplier AS
SELECT
    supplier_id,
    supplier_name,
    contact_name,
    phone,
    email,
    address,
    status,
    created_time
FROM supplier
WHERE status = '1'
WITH CASCADED CHECK OPTION;

-- ------------------------------------------------------------
-- View：v_a_create_active_product
-- 身分：admin
-- 功能：管理員新增 active 商品。
-- 條件：
--   只能新增 status = '1' 的 active 商品。
-- 查詢：
--   SELECT * FROM v_a_create_active_product;
-- 新增範例：
--INSERT INTO v_a_create_active_product
--(
--    supplier_id,product_name,brand,description,original_price,group_price,stock_quantity,
--    status,end_time,max_quantity,min_quantity)
--VALUES
--(
--    1,'鳳梨乾禮盒','玉井農會','台南鳳梨乾禮盒，適合團購與送禮。',500,
--    399,80,'1','2026-08-31 23:59:59',60,10);
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_a_create_active_product AS
SELECT
    product_id,
    supplier_id,
    product_name,
    brand,
    description,
    original_price,
    group_price,
    stock_quantity,
    status,
    created_time,
    end_time,
    max_quantity,
    min_quantity
FROM product
WHERE status = '1'
WITH CASCADED CHECK OPTION;

-- ------------------------------------------------------------
-- View：v_a_delete_inactive_member
-- 身分：admin
-- 功能：管理員刪除 inactive 或 banned 會員。
-- 條件：
--   只能刪除 status IN ('2','3') 的會員。
-- 查詢：
--   SELECT * FROM v_a_delete_inactive_member;
-- 刪除範例：
--   DELETE FROM v_a_delete_inactive_member WHERE member_id = 7;
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_a_delete_inactive_member AS
SELECT
    member_id,
    email,
    phone,
    name,
    role,
    status,
    created_time,
    updated_time
FROM member
WHERE status IN ('2', '3');

-- ------------------------------------------------------------
-- View：v_a_delete_inactive_supplier
-- 身分：admin
-- 功能：管理員刪除 inactive 供應商。
-- 條件：
--   只能刪除 status = '2' 的供應商。
-- 查詢：
--   SELECT * FROM v_a_delete_inactive_supplier;
-- 刪除範例：
--   DELETE FROM v_a_delete_inactive_supplier WHERE supplier_id = 11;
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_a_delete_inactive_supplier AS
SELECT
    supplier_id,
    supplier_name,
    contact_name,
    phone,
    email,
    address,
    status,
    created_time
FROM supplier
WHERE status = '2';

-- ------------------------------------------------------------
-- View：v_a_delete_inactive_product
-- 身分：admin
-- 功能：管理員刪除 inactive 或 discontinued 商品。
-- 條件：
--   只能刪除 status IN ('2','3') 的商品。
-- 查詢：
--   SELECT * FROM v_a_delete_inactive_product;
-- 刪除範例：
--   DELETE FROM v_a_delete_inactive_product WHERE product_id = 11;
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_a_delete_inactive_product AS
SELECT
    product_id,
    supplier_id,
    product_name,
    brand,
    description,
    original_price,
    group_price,
    stock_quantity,
    status,
    created_time,
    end_time,
    max_quantity,
    min_quantity
FROM product
WHERE status IN ('2', '3');

-- ============================================================
-- 所有 View 快速查詢指令
-- ============================================================

-- member View
-- SELECT * FROM v_m_active_product_list;
-- SELECT * FROM v_m_available_product_for_groupbuy;
-- SELECT * FROM v_m_open_groupbuy_list;
-- SELECT * FROM v_m_groupbuy_progress;
-- SELECT * FROM v_m_create_active_groupbuy;
-- SELECT * FROM v_m_create_pending_order;
-- SELECT * FROM v_m_delete_pending_order;

-- organizer View
-- SELECT * FROM v_o_my_groupbuy_summary;
-- SELECT * FROM v_o_my_groupbuy_summary WHERE organizer_id = 1;
-- SELECT * FROM v_o_my_groupbuy_orders;
-- SELECT * FROM v_o_my_groupbuy_orders WHERE organizer_id = 1;
-- SELECT * FROM v_o_delete_active_groupbuy;

-- admin View
-- SELECT * FROM v_a_member_full_list;
-- SELECT * FROM v_a_supplier_full_list;
-- SELECT * FROM v_a_product_full_list;
-- SELECT * FROM v_a_groupbuy_full_list;
-- SELECT * FROM v_a_order_payment_fulfillment_detail;
-- SELECT * FROM v_a_create_active_member;
-- SELECT * FROM v_a_create_active_supplier;
-- SELECT * FROM v_a_create_active_product;
-- SELECT * FROM v_a_delete_inactive_member;
-- SELECT * FROM v_a_delete_inactive_supplier;
-- SELECT * FROM v_a_delete_inactive_product;

