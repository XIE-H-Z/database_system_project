-- ============================================================
-- 團購系統權限設定 SQL
-- 版本：privileges_role_flow_v3
-- 使用時機：
--   1. 先 source create table
--   2. 再 source sample values
--   3. 再 source views
--   4. 最後 source 這個權限檔
--
-- 執行身分：
--   請用 root 或具有 CREATE USER / CREATE ROLE / GRANT 權限的帳號執行。
--
-- 對應 View 檔：
--   group_buying_views_role_flow_v3.sql
-- ============================================================

USE group_buying_system;

-- ============================================================
-- 1. 建立角色 Role
-- ============================================================
CREATE ROLE IF NOT EXISTS role_member;
CREATE ROLE IF NOT EXISTS role_organizer;
CREATE ROLE IF NOT EXISTS role_admin;

-- ============================================================
-- 2. 建立測試用資料庫帳號 User
--    你可以依照需要改帳號與密碼。
-- ============================================================
CREATE USER IF NOT EXISTS 'member_user'@'localhost' IDENTIFIED BY 'member123';
CREATE USER IF NOT EXISTS 'organizer_user'@'localhost' IDENTIFIED BY 'organizer123';
CREATE USER IF NOT EXISTS 'admin_user'@'localhost' IDENTIFIED BY 'admin123';

-- ============================================================
-- 3. member 角色權限
-- 說明：
--   member 開團前仍然是 member，所以可開團商品與新增團購 View
--   也要給 member 使用。
-- ============================================================

-- member 查詢 View
GRANT SELECT ON group_buying_system.v_m_active_product_list TO role_member;
GRANT SELECT ON group_buying_system.v_m_available_product_for_groupbuy TO role_member;
GRANT SELECT ON group_buying_system.v_m_open_groupbuy_list TO role_member;
GRANT SELECT ON group_buying_system.v_m_groupbuy_progress TO role_member;

-- member 新增 View
GRANT INSERT ON group_buying_system.v_m_create_active_groupbuy TO role_member;
GRANT SELECT ON group_buying_system.v_m_create_active_groupbuy TO role_member;

GRANT INSERT ON group_buying_system.v_m_create_pending_order TO role_member;
GRANT SELECT ON group_buying_system.v_m_create_pending_order TO role_member;

-- member 刪除 View
GRANT DELETE ON group_buying_system.v_m_delete_pending_order TO role_member;
GRANT SELECT ON group_buying_system.v_m_delete_pending_order TO role_member;

-- ============================================================
-- 4. organizer 角色權限
-- 說明：
--   organizer 是開團後用來管理自己團購的角色。
-- ============================================================

-- organizer 查詢 View
GRANT SELECT ON group_buying_system.v_o_my_groupbuy_summary TO role_organizer;
GRANT SELECT ON group_buying_system.v_o_my_groupbuy_orders TO role_organizer;

-- organizer 刪除 View
GRANT DELETE ON group_buying_system.v_o_delete_active_groupbuy TO role_organizer;
GRANT SELECT ON group_buying_system.v_o_delete_active_groupbuy TO role_organizer;

-- ============================================================
-- 5. admin 角色權限
-- 說明：
--   admin 可以查詢完整資料，並透過 View 新增與刪除符合條件的資料。
-- ============================================================

-- admin 查詢 View
GRANT SELECT ON group_buying_system.v_a_member_full_list TO role_admin;
GRANT SELECT ON group_buying_system.v_a_supplier_full_list TO role_admin;
GRANT SELECT ON group_buying_system.v_a_product_full_list TO role_admin;
GRANT SELECT ON group_buying_system.v_a_groupbuy_full_list TO role_admin;
GRANT SELECT ON group_buying_system.v_a_order_payment_fulfillment_detail TO role_admin;

-- admin 新增 View
GRANT INSERT ON group_buying_system.v_a_create_active_member TO role_admin;
GRANT SELECT ON group_buying_system.v_a_create_active_member TO role_admin;

GRANT INSERT ON group_buying_system.v_a_create_active_supplier TO role_admin;
GRANT SELECT ON group_buying_system.v_a_create_active_supplier TO role_admin;

GRANT INSERT ON group_buying_system.v_a_create_active_product TO role_admin;
GRANT SELECT ON group_buying_system.v_a_create_active_product TO role_admin;

-- admin 刪除 View
GRANT DELETE ON group_buying_system.v_a_delete_inactive_member TO role_admin;
GRANT SELECT ON group_buying_system.v_a_delete_inactive_member TO role_admin;

GRANT DELETE ON group_buying_system.v_a_delete_inactive_supplier TO role_admin;
GRANT SELECT ON group_buying_system.v_a_delete_inactive_supplier TO role_admin;

GRANT DELETE ON group_buying_system.v_a_delete_inactive_product TO role_admin;
GRANT SELECT ON group_buying_system.v_a_delete_inactive_product TO role_admin;

-- ============================================================
-- 6. 將 Role 指派給 User
-- ============================================================
GRANT role_member TO 'member_user'@'localhost';
GRANT role_organizer TO 'organizer_user'@'localhost';
GRANT role_admin TO 'admin_user'@'localhost';

-- ============================================================
-- 7. 設定預設 Role
-- 說明：
--   這樣使用者登入後就會自動啟用對應角色。
-- ============================================================
SET DEFAULT ROLE role_member FOR 'member_user'@'localhost';
SET DEFAULT ROLE role_organizer FOR 'organizer_user'@'localhost';
SET DEFAULT ROLE role_admin FOR 'admin_user'@'localhost';

FLUSH PRIVILEGES;

-- ============================================================
-- 8. 測試登入方式
-- 請先 exit 離開 MariaDB，再用下面指令測試。
--
-- Windows CMD：
--   mysql -u member_user -p
--   mysql -u organizer_user -p
--   mysql -u admin_user -p
--
-- 密碼：
--   member_user     member123
--   organizer_user  organizer123
--   admin_user      admin123
-- ============================================================

-- ============================================================
-- 9. member_user 測試指令
-- 登入 member_user 後執行：
--
-- USE group_buying_system;
-- SELECT * FROM v_m_active_product_list;
-- SELECT * FROM v_m_available_product_for_groupbuy;
-- SELECT * FROM v_m_open_groupbuy_list;
-- SELECT * FROM v_m_groupbuy_progress;
--
-- INSERT INTO v_m_create_pending_order
-- (member_id, group_buy_id, quantity, unit_price_snapshot, pickup_location)
-- VALUES
-- (2, 1, 1, 450, '校門口取貨點');
--
-- 下面這個應該失敗，因為 member 沒有 admin View 權限：
-- SELECT * FROM v_a_member_full_list;
-- ============================================================

-- ============================================================
-- 10. organizer_user 測試指令
-- 登入 organizer_user 後執行：
--
-- USE group_buying_system;
-- SELECT * FROM v_o_my_groupbuy_summary;
-- SELECT * FROM v_o_my_groupbuy_orders;
-- SELECT * FROM v_o_delete_active_groupbuy;
--
-- 下面這個應該失敗，因為 organizer 沒有 admin View 權限：
-- SELECT * FROM v_a_product_full_list;
-- ============================================================

-- ============================================================
-- 11. admin_user 測試指令
-- 登入 admin_user 後執行：
--
-- USE group_buying_system;
-- SELECT * FROM v_a_member_full_list;
-- SELECT * FROM v_a_supplier_full_list;
-- SELECT * FROM v_a_product_full_list;
-- SELECT * FROM v_a_groupbuy_full_list;
-- SELECT * FROM v_a_order_payment_fulfillment_detail;
--
-- INSERT INTO v_a_create_active_supplier
-- (supplier_name, contact_name, phone, email, address, status)
-- VALUES
-- ('新供應商', '王先生', '0933000001', 'new_supplier@example.com', '雲林縣斗六市新路1號', '1');
-- ============================================================

-- ============================================================
-- 12. member 開團後升級 organizer 的作法一
-- 說明：
--   這不是由 member_user 自己執行。
--   實際系統中應由後端程式或系統管理帳號執行。
--
-- 範例：
--   UPDATE member
--   SET role = '2'
--   WHERE member_id = 12;
--
-- 如果只是課堂測試，可以用 root 手動執行。
-- ============================================================
