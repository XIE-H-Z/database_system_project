
-- ============================================================
-- 範例資料：芒果團購
-- 情境：供應商提供芒果原價 600 元／箱，團購價 450 元／箱，最低 20 箱成團。
-- ============================================================
INSERT INTO `Member`
  (`member_id`, `email`, `phone`, `password_hash`, `name`, `role`, `status`, `created_time`)
VALUES
  (1, 'ming@example.com', '0912345678', '$2y$10$abcdefghijklmnopqrstuvABCDEFGHIJKLMN1234567890abcd', '小明', 'organizer', 'active', '2026-06-01 09:00:00'),
  (2, 'mei@example.com', '0922333444', '$2y$10$abcdefghijklmnopqrstuvABCDEFGHIJKLMN1234567890abce', '小美', 'member', 'active', '2026-06-01 09:05:00'),
  (3, 'hua@example.com', '0933555666', '$2y$10$abcdefghijklmnopqrstuvABCDEFGHIJKLMN1234567890abcf', '阿華', 'member', 'active', '2026-06-01 09:10:00');

INSERT INTO `Supplier`
  (`supplier_id`, `supplier_name`, `contact_name`, `phone`, `email`, `address`, `status`, `created_at`)
VALUES
  (1, '南部鮮果供應商', '王先生', '071234567', 'supplier@example.com', '高雄市前鎮區果菜路 1 號', 'active', '2026-06-01 10:00:00');

INSERT INTO `Product`
  (`product_id`, `supplier_id`, `product_name`, `description`, `original_price`, `group_price`, `stock_quantity`, `status`, `created_time`, `end_time`)
VALUES
  (1, 1, '愛文芒果 10 斤箱', '產地直送，適合團購分享。', 600.00, 450.00, 100, 'active', '2026-06-01 10:30:00', '2026-06-30 23:59:59');

INSERT INTO `GroupBuy`
  (`group_buy_id`, `member_id`, `title`, `description`, `start_time`, `end_time`, `min_quantity`, `max_quantity`, `created_time`, `status`)
VALUES
  (1, 1, '小明的芒果團購', '原價 600 元／箱，團購價 450 元／箱，滿 20 箱成團。', '2026-06-02 08:00:00', '2026-06-20 23:59:59', 20, 100, '2026-06-02 08:00:00', 'active');

INSERT INTO `GroupBuyItem`
  (`group_buy_item_id`, `group_buy_id`, `product_id`, `group_price`, `quota_quantity`, `limit_per_member`, `status`, `original_price`)
VALUES
  (1, 1, 1, 450.00, 100, 20, 'active', 600.00);

INSERT INTO `groupbuytable`
  (`groupbuytable_id`, `group_buy_id`, `group_buy_item_id`, `status`)
VALUES
  (1, 1, 1, 'active');

-- 下單後 OrderItem 觸發器會自動回寫 PurchaseOrder.total_amount。
INSERT INTO `PurchaseOrder`
  (`order_id`, `member_id`, `group_buy_id`, `order_time`, `order_status`, `total_amount`, `note`, `created_time`, `status`, `pickup_location`)
VALUES
  (1, 2, 1, '2026-06-03 12:00:00', 'paid', 0.00, '小美訂購 12 箱', '2026-06-03 12:00:00', 'active', '校門口取貨'),
  (2, 3, 1, '2026-06-03 13:00:00', 'paid', 0.00, '阿華訂購 8 箱', '2026-06-03 13:00:00', 'active', '社區大廳取貨');

INSERT INTO `OrderItem`
  (`order_item_id`, `order_id`, `group_buy_item_id`, `quantity`, `unit_price_snapshot`)
VALUES
  (1, 1, 1, 12, 450.00),
  (2, 2, 1, 8, 450.00);

INSERT INTO `Payment`
  (`payment_id`, `order_id`, `payment_method`, `payment_amount`, `payment_status`, `paid_time`, `created_time`)
VALUES
  (1, 1, 'line_pay', 5400.00, 'success', '2026-06-03 12:03:00', '2026-06-03 12:00:00'),
  (2, 2, 'credit_card', 3600.00, 'success', '2026-06-03 13:05:00', '2026-06-03 13:00:00');

INSERT INTO `Fulfillment`
  (`fulfillment_id`, `order_id`, `fulfillment_type`, `recipient_name`, `recipient_phone`, `address`, `tracking_no`, `fulfillment_status`, `fulfilled_time`, `created_time`)
VALUES
  (1, 1, 'pickup', '小美', '0922333444', NULL, NULL, 'preparing', NULL, '2026-06-03 12:05:00'),
  (2, 2, 'delivery', '阿華', '0933555666', '台北市中正區範例路 88 號', 'TG202606030001', 'shipped', NULL, '2026-06-03 13:10:00');
