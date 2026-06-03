📖 專案簡介

本專案為一個團購平台資料庫設計，提供會員發起團購、商品管理、訂單管理、付款管理及履約管理等功能。

系統透過 MariaDB 建立完整的關聯式資料庫架構，並遵循資料庫正規化與完整性限制設計原則，確保資料一致性與正確性。

🎯 專案目標

建立一套完整的團購系統資料庫，支援：

會員註冊與登入
團購活動建立
商品管理
訂單管理
線上付款紀錄
出貨與取貨管理
團購成團判定
團購進度追蹤
🏗️ 系統架構
Member
   │
   ├── GroupBuy
   │      │
   │      └── GroupBuyItem
   │               │
   │               └── Product
   │                       │
   │                       └── Supplier
   │
   └── PurchaseOrder
             │
             ├── OrderItem
             ├── Payment
             └── Fulfillment
🗄️ 資料表設計
Member（會員）

儲存系統使用者資訊。

欄位	說明
member_id	會員編號
email	電子郵件
phone	電話
password_hash	密碼雜湊值
name	姓名
role	角色
status	帳號狀態
Supplier（供應商）

管理商品供應商資料。

欄位	說明
supplier_id	供應商編號
supplier_name	供應商名稱
contact_name	聯絡人
phone	電話
email	Email
address	地址
Product（商品）

記錄供應商所提供商品資訊。

欄位	說明
product_id	商品編號
supplier_id	所屬供應商
product_name	商品名稱
description	商品描述
original_price	原價
group_price	團購價
stock_quantity	庫存數量
GroupBuy（團購活動）

由會員建立的團購活動。

欄位	說明
group_buy_id	團購編號
member_id	發起人
title	團購標題
description	團購說明
start_time	開始時間
end_time	結束時間
min_quantity	最低成團數量
max_quantity	最大數量
GroupBuyItem（團購商品）

定義團購活動中的商品內容。

欄位	說明
group_buy_item_id	團購商品編號
group_buy_id	團購活動
product_id	商品
group_price	團購價格
quota_quantity	配額數量
limit_per_member	每人購買上限
PurchaseOrder（訂單）

會員參與團購後建立訂單。

欄位	說明
order_id	訂單編號
member_id	訂購會員
group_buy_id	所屬團購
order_time	下單時間
order_status	訂單狀態
total_amount	訂單總額
OrderItem（訂單明細）

記錄訂單中的商品資訊。

欄位	說明
order_item_id	明細編號
order_id	訂單編號
group_buy_item_id	團購商品
quantity	購買數量
unit_price_snapshot	下單時價格
Payment（付款）

記錄付款資訊。

欄位	說明
payment_id	付款編號
order_id	訂單編號
payment_method	付款方式
payment_amount	付款金額
payment_status	付款狀態
Fulfillment（履約）

管理出貨與取貨資訊。

欄位	說明
fulfillment_id	履約編號
order_id	訂單編號
fulfillment_type	配送方式
fulfillment_status	配送狀態
tracking_no	物流編號
