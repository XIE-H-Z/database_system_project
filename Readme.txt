使用mariadb 10.11.2版本

先以root帳號source sql資料夾的sql檔案
source C:/Users/User/Downloads/group_buying_create_tables.sql
source C:/Users/User/Downloads/group_buying_sample_values_fixed_0831.sql
source C:/Users/User/Downloads/group_buying_views_role_flow_v3.sql
source C:/Users/User/Downloads/group_buying_privileges_role_flow_v3.sql

============================================================
所有 View 快速查詢指令
============================================================

member View
SELECT * FROM v_m_active_product_list;
SELECT * FROM v_m_available_product_for_groupbuy;
SELECT * FROM v_m_open_groupbuy_list;
SELECT * FROM v_m_groupbuy_progress;
SELECT * FROM v_m_create_active_groupbuy;
SELECT * FROM v_m_create_pending_order;
SELECT * FROM v_m_delete_pending_order;

organizer View
SELECT * FROM v_o_my_groupbuy_summary;
SELECT * FROM v_o_my_groupbuy_summary WHERE organizer_id = 1;
SELECT * FROM v_o_my_groupbuy_orders;
SELECT * FROM v_o_my_groupbuy_orders WHERE organizer_id = 1;
SELECT * FROM v_o_delete_active_groupbuy;

admin View
SELECT * FROM v_a_member_full_list;
SELECT * FROM v_a_supplier_full_list;
SELECT * FROM v_a_product_full_list;
SELECT * FROM v_a_groupbuy_full_list;
SELECT * FROM v_a_order_payment_fulfillment_detail;
SELECT * FROM v_a_create_active_member;
SELECT * FROM v_a_create_active_supplier;
SELECT * FROM v_a_create_active_product;
SELECT * FROM v_a_delete_inactive_member;
SELECT * FROM v_a_delete_inactive_supplier;
SELECT * FROM v_a_delete_inactive_product;

============================================================
使用者帳號
============================================================
member_user      密碼 member123
organizer_user   密碼 organizer123
admin_user       密碼 admin123
