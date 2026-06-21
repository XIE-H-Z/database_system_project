# 團購系統資料庫 README

## 環境版本

使用 **MariaDB 10.11.2** 版本。

## 匯入 SQL 檔案

請先使用 `root` 帳號登入 MariaDB，並依序 `source` SQL 資料夾中的 SQL 檔案。

```sql
source C:/Users/User/Downloads/group_buying_create_tables.sql
source C:/Users/User/Downloads/group_buying_sample_values_fixed_0831.sql
source C:/Users/User/Downloads/group_buying_views_role_flow_v3.sql
source C:/Users/User/Downloads/group_buying_privileges_role_flow_v3.sql
```

---

## 所有 View 快速查詢指令

### Member View

```sql
SELECT * FROM v_m_active_product_list;
SELECT * FROM v_m_available_product_for_groupbuy;
SELECT * FROM v_m_open_groupbuy_list;
SELECT * FROM v_m_groupbuy_progress;
SELECT * FROM v_m_create_active_groupbuy;
SELECT * FROM v_m_create_pending_order;
SELECT * FROM v_m_delete_pending_order;
```

### Organizer View

```sql
SELECT * FROM v_o_my_groupbuy_summary;
SELECT * FROM v_o_my_groupbuy_summary WHERE organizer_id = 1;
SELECT * FROM v_o_my_groupbuy_orders;
SELECT * FROM v_o_my_groupbuy_orders WHERE organizer_id = 1;
SELECT * FROM v_o_delete_active_groupbuy;
```

### Admin View

```sql
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
```

---

## 使用者帳號

| 角色 | 帳號 | 密碼 |
|---|---|---|
| Member | `member_user` | `member123` |
| Organizer | `organizer_user` | `organizer123` |
| Admin | `admin_user` | `admin123` |
