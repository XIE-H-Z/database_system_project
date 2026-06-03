-- ============================================================
-- 範例查詢
-- ============================================================

-- 1. 查看團購是否成團：ordered_quantity = 20，min_quantity = 20，狀態為 qualified。
SELECT *
  FROM `v_group_buy_progress`
 WHERE `group_buy_id` = 1;

-- 2. 查詢會員小美的訂單與小計。
SELECT
  m.`name` AS `member_name`,
  po.`order_id`,
  gb.`title`,
  oi.`quantity`,
  oi.`unit_price_snapshot`,
  oi.`sub_total`,
  po.`total_amount`,
  po.`order_status`
FROM `PurchaseOrder` AS po
JOIN `Member` AS m
  ON m.`member_id` = po.`member_id`
JOIN `GroupBuy` AS gb
  ON gb.`group_buy_id` = po.`group_buy_id`
JOIN `OrderItem` AS oi
  ON oi.`order_id` = po.`order_id`
WHERE po.`member_id` = 2;

-- 3. 查詢付款與履約狀態。
SELECT
  po.`order_id`,
  p.`payment_method`,
  p.`payment_status`,
  f.`fulfillment_type`,
  f.`fulfillment_status`,
  f.`tracking_no`
FROM `PurchaseOrder` AS po
LEFT JOIN `Payment` AS p
  ON p.`order_id` = po.`order_id`
LEFT JOIN `Fulfillment` AS f
  ON f.`order_id` = po.`order_id`
ORDER BY po.`order_id`;