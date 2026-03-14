-- ═══ OUTLETS ═══
INSERT INTO outlets (id, code, name, address, api_key, webhook_url, is_active) VALUES
('01JQXK0000OUTLET001JAKART', 'JKT-001', 'Nusantara Resto Jakarta Pusat', 'Jl. Thamrin No. 10, Jakarta Pusat', 'pos_a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4', 'https://webhook.example.com/jkt001', true),
('01JQXK0000OUTLET002BANDUN', 'BDG-001', 'Nusantara Resto Bandung', 'Jl. Braga No. 25, Bandung', 'pos_b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5', 'https://webhook.example.com/bdg001', true),
('01JQXK0000OUTLET003SURABA', 'SBY-001', 'Nusantara Resto Surabaya', 'Jl. Pemuda No. 15, Surabaya', 'pos_c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6', 'https://webhook.example.com/sby001', true)
ON CONFLICT DO NOTHING;

-- ═══ CATEGORIES ═══
-- id = local_id (ID sama di POS dan Cloud)
INSERT INTO cloud_categories (id, local_id, outlet_id, name, version) VALUES
('01JQXK0000CATEG001MAKANAN', '01JQXK0000CATEG001MAKANAN', '01JQXK0000OUTLET001JAKART', 'Makanan', 1),
('01JQXK0000CATEG002MINUMAN', '01JQXK0000CATEG002MINUMAN', '01JQXK0000OUTLET001JAKART', 'Minuman', 1),
('01JQXK0000CATEG003DESSERT', '01JQXK0000CATEG003DESSERT', '01JQXK0000OUTLET001JAKART', 'Dessert', 1),
('01JQXK0000CATEG004SNACKSS', '01JQXK0000CATEG004SNACKSS', '01JQXK0000OUTLET001JAKART', 'Snack', 1),
('01JQXK0000CATEG005BDGMKN0', '01JQXK0000CATEG005BDGMKN0', '01JQXK0000OUTLET002BANDUN', 'Makanan', 1),
('01JQXK0000CATEG006BDGMNM0', '01JQXK0000CATEG006BDGMNM0', '01JQXK0000OUTLET002BANDUN', 'Minuman', 1)
ON CONFLICT DO NOTHING;

-- ═══ PRODUCTS ═══
-- id = local_id (ID sama di POS dan Cloud), cloud tidak punya kode produk
INSERT INTO cloud_products (id, local_id, outlet_id, name, category_id, category_name, price, stock, destination, version) VALUES
('01JQXK0000PRODU001NASGOR0', '01JQXK0000PRODU001NASGOR0', '01JQXK0000OUTLET001JAKART', 'Nasi Goreng Spesial', '01JQXK0000CATEG001MAKANAN', 'Makanan', 35000.00, 100, 'dapur', 1),
('01JQXK0000PRODU002MIAYAM0', '01JQXK0000PRODU002MIAYAM0', '01JQXK0000OUTLET001JAKART', 'Mie Ayam Bakso', '01JQXK0000CATEG001MAKANAN', 'Makanan', 28000.00, 80, 'dapur', 1),
('01JQXK0000PRODU003AYAMGR0', '01JQXK0000PRODU003AYAMGR0', '01JQXK0000OUTLET001JAKART', 'Ayam Goreng Kremes', '01JQXK0000CATEG001MAKANAN', 'Makanan', 32000.00, 50, 'dapur', 1),
('01JQXK0000PRODU004SATAYA0', '01JQXK0000PRODU004SATAYA0', '01JQXK0000OUTLET001JAKART', 'Sate Ayam (10 tusuk)', '01JQXK0000CATEG001MAKANAN', 'Makanan', 30000.00, 60, 'dapur', 1),
('01JQXK0000PRODU005RENDNG0', '01JQXK0000PRODU005RENDNG0', '01JQXK0000OUTLET001JAKART', 'Rendang Sapi', '01JQXK0000CATEG001MAKANAN', 'Makanan', 45000.00, 30, 'dapur', 1),
('01JQXK0000PRODU006ESTEH00', '01JQXK0000PRODU006ESTEH00', '01JQXK0000OUTLET001JAKART', 'Es Teh Manis', '01JQXK0000CATEG002MINUMAN', 'Minuman', 8000.00, 200, 'bar', 1),
('01JQXK0000PRODU007ESJEUK0', '01JQXK0000PRODU007ESJEUK0', '01JQXK0000OUTLET001JAKART', 'Es Jeruk Segar', '01JQXK0000CATEG002MINUMAN', 'Minuman', 12000.00, 150, 'bar', 1),
('01JQXK0000PRODU008KOPISS0', '01JQXK0000PRODU008KOPISS0', '01JQXK0000OUTLET001JAKART', 'Kopi Susu Gula Aren', '01JQXK0000CATEG002MINUMAN', 'Minuman', 22000.00, 100, 'bar', 1),
('01JQXK0000PRODU009JUSCAL0', '01JQXK0000PRODU009JUSCAL0', '01JQXK0000OUTLET001JAKART', 'Jus Alpukat', '01JQXK0000CATEG002MINUMAN', 'Minuman', 18000.00, 80, 'bar', 1),
('01JQXK0000PRODU010PUDING0', '01JQXK0000PRODU010PUDING0', '01JQXK0000OUTLET001JAKART', 'Puding Coklat', '01JQXK0000CATEG003DESSERT', 'Dessert', 15000.00, 40, 'dapur', 1),
('01JQXK0000PRODU011BDGNSG0', '01JQXK0000PRODU011BDGNSG0', '01JQXK0000OUTLET002BANDUN', 'Nasi Goreng Kambing', '01JQXK0000CATEG005BDGMKN0', 'Makanan', 40000.00, 70, 'dapur', 1),
('01JQXK0000PRODU012BDGBAK0', '01JQXK0000PRODU012BDGBAK0', '01JQXK0000OUTLET002BANDUN', 'Batagor Kuah', '01JQXK0000CATEG005BDGMKN0', 'Makanan', 25000.00, 90, 'dapur', 1),
('01JQXK0000PRODU013BDGEST0', '01JQXK0000PRODU013BDGEST0', '01JQXK0000OUTLET002BANDUN', 'Es Teh Tarik', '01JQXK0000CATEG006BDGMNM0', 'Minuman', 15000.00, 120, 'bar', 1)
ON CONFLICT DO NOTHING;

-- ═══ ORDERS ═══
-- ═══ ORDERS ═══
-- id = local_id (ID sama di POS dan Cloud)
INSERT INTO cloud_orders (id, local_id, outlet_id, outlet_code, table_number, customer_name, pax, total_amount, status, items, payment_info, version, created_at, updated_at) VALUES
('01JQXK0000ORDER001JKTORD0', '01JQXK0000ORDER001JKTORD0', '01JQXK0000OUTLET001JAKART', 'JKT-001', 'T-05', 'Budi Santoso', 4, 123000.00, 'completed',
 '[{"product_name":"Nasi Goreng Spesial","category":"Makanan","qty":2,"price":35000,"subtotal":70000,"destination":"dapur","status":"served"},{"product_name":"Es Teh Manis","category":"Minuman","qty":4,"price":8000,"subtotal":32000,"destination":"bar","status":"served"},{"product_name":"Kopi Susu Gula Aren","category":"Minuman","qty":1,"price":22000,"subtotal":22000,"destination":"bar","status":"served"}]',
 '{"method":"cash","amount":150000,"paid_at":"2026-03-02T10:30:00Z"}', 1, NOW() - INTERVAL '2 hours', NOW() - INTERVAL '1 hour'),

('01JQXK0000ORDER002JKTORD0', '01JQXK0000ORDER002JKTORD0', '01JQXK0000OUTLET001JAKART', 'JKT-001', 'T-03', 'Siti Aminah', 2, 82000.00, 'completed',
 '[{"product_name":"Ayam Goreng Kremes","category":"Makanan","qty":2,"price":32000,"subtotal":64000,"destination":"dapur","status":"served"},{"product_name":"Es Jeruk Segar","category":"Minuman","qty":2,"price":12000,"subtotal":24000,"destination":"bar","status":"served"}]',
 '{"method":"qris","amount":82000,"paid_at":"2026-03-02T11:15:00Z"}', 1, NOW() - INTERVAL '3 hours', NOW() - INTERVAL '2 hours'),

('01JQXK0000ORDER003JKTORD0', '01JQXK0000ORDER003JKTORD0', '01JQXK0000OUTLET001JAKART', 'JKT-001', 'T-01', 'Ahmad Rizki', 3, 141000.00, 'completed',
 '[{"product_name":"Rendang Sapi","category":"Makanan","qty":2,"price":45000,"subtotal":90000,"destination":"dapur","status":"served"},{"product_name":"Sate Ayam (10 tusuk)","category":"Makanan","qty":1,"price":30000,"subtotal":30000,"destination":"dapur","status":"served"},{"product_name":"Jus Alpukat","category":"Minuman","qty":1,"price":18000,"subtotal":18000,"destination":"bar","status":"served"}]',
 '{"method":"cash","amount":150000,"paid_at":"2026-03-02T12:00:00Z"}', 1, NOW() - INTERVAL '1 hour', NOW() - INTERVAL '30 minutes'),

('01JQXK0000ORDER004JKTORD0', '01JQXK0000ORDER004JKTORD0', '01JQXK0000OUTLET001JAKART', 'JKT-001', 'T-07', 'Dewi Lestari', 2, 71000.00, 'in_progress',
 '[{"product_name":"Mie Ayam Bakso","category":"Makanan","qty":2,"price":28000,"subtotal":56000,"destination":"dapur","status":"cooking"},{"product_name":"Puding Coklat","category":"Dessert","qty":1,"price":15000,"subtotal":15000,"destination":"dapur","status":"pending"}]',
 '{}', 1, NOW() - INTERVAL '15 minutes', NOW() - INTERVAL '10 minutes'),

('01JQXK0000ORDER005BDGORD0', '01JQXK0000ORDER005BDGORD0', '01JQXK0000OUTLET002BANDUN', 'BDG-001', 'T-02', 'Rina Marlina', 3, 120000.00, 'completed',
 '[{"product_name":"Nasi Goreng Kambing","category":"Makanan","qty":2,"price":40000,"subtotal":80000,"destination":"dapur","status":"served"},{"product_name":"Batagor Kuah","category":"Makanan","qty":1,"price":25000,"subtotal":25000,"destination":"dapur","status":"served"},{"product_name":"Es Teh Tarik","category":"Minuman","qty":1,"price":15000,"subtotal":15000,"destination":"bar","status":"served"}]',
 '{"method":"cash","amount":120000,"paid_at":"2026-03-02T09:45:00Z"}', 1, NOW() - INTERVAL '4 hours', NOW() - INTERVAL '3 hours')
ON CONFLICT DO NOTHING;

-- ═══ TRANSACTIONS ═══
-- id = local_id (ID sama di POS dan Cloud), order_id referensi ke ULID order
INSERT INTO cloud_transactions (id, local_id, outlet_id, outlet_code, order_id, total_amount, payment_method, cash_amount, change_amount, cashier_name, version, created_at) VALUES
('01JQXK0000TRANS001JKTTXN0', '01JQXK0000TRANS001JKTTXN0', '01JQXK0000OUTLET001JAKART', 'JKT-001', '01JQXK0000ORDER001JKTORD0', 123000.00, 'cash', 150000.00, 27000.00, 'Kasir Andi', 1, NOW() - INTERVAL '1 hour'),
('01JQXK0000TRANS002JKTTXN0', '01JQXK0000TRANS002JKTTXN0', '01JQXK0000OUTLET001JAKART', 'JKT-001', '01JQXK0000ORDER002JKTORD0', 82000.00, 'qris', 82000.00, 0.00, 'Kasir Andi', 1, NOW() - INTERVAL '2 hours'),
('01JQXK0000TRANS003JKTTXN0', '01JQXK0000TRANS003JKTTXN0', '01JQXK0000OUTLET001JAKART', 'JKT-001', '01JQXK0000ORDER003JKTORD0', 141000.00, 'cash', 150000.00, 9000.00, 'Kasir Maya', 1, NOW() - INTERVAL '30 minutes'),
('01JQXK0000TRANS004BDGTXN0', '01JQXK0000TRANS004BDGTXN0', '01JQXK0000OUTLET002BANDUN', 'BDG-001', '01JQXK0000ORDER005BDGORD0', 120000.00, 'cash', 120000.00, 0.00, 'Kasir Riko', 1, NOW() - INTERVAL '3 hours')
ON CONFLICT DO NOTHING;

-- ═══ ANALYTICS ═══
INSERT INTO cloud_analytics (id, outlet_id, outlet_code, date, summary) VALUES
('01JQXK0000ANALY001JKTDAY', '01JQXK0000OUTLET001JAKART', 'JKT-001', '2026-03-02',
 '{"total_orders":15,"total_revenue":1850000,"total_transactions":15,"avg_order_value":123333,"top_products":[{"name":"Nasi Goreng Spesial","qty":25},{"name":"Es Teh Manis","qty":40},{"name":"Ayam Goreng Kremes","qty":18}],"payment_methods":{"cash":10,"qris":4,"transfer":1},"peak_hour":12}'),
('01JQXK0000ANALY002JKTDAY', '01JQXK0000OUTLET001JAKART', 'JKT-001', '2026-03-01',
 '{"total_orders":22,"total_revenue":2750000,"total_transactions":22,"avg_order_value":125000,"top_products":[{"name":"Rendang Sapi","qty":15},{"name":"Nasi Goreng Spesial","qty":30},{"name":"Kopi Susu Gula Aren","qty":28}],"payment_methods":{"cash":14,"qris":6,"transfer":2},"peak_hour":13}'),
('01JQXK0000ANALY003BDGDAY', '01JQXK0000OUTLET002BANDUN', 'BDG-001', '2026-03-02',
 '{"total_orders":12,"total_revenue":1450000,"total_transactions":12,"avg_order_value":120833,"top_products":[{"name":"Nasi Goreng Kambing","qty":18},{"name":"Batagor Kuah","qty":15},{"name":"Es Teh Tarik","qty":20}],"payment_methods":{"cash":8,"qris":3,"transfer":1},"peak_hour":12}')
ON CONFLICT DO NOTHING;

-- ═══ SYNC LOGS ═══
INSERT INTO sync_logs (id, outlet_id, action, entity_type, entity_count, status, created_at) VALUES
('01JQXK0000SYNCL001JKTLOG', '01JQXK0000OUTLET001JAKART', 'push_order', 'order', 3, 'success', NOW() - INTERVAL '1 hour'),
('01JQXK0000SYNCL002JKTLOG', '01JQXK0000OUTLET001JAKART', 'push_transaction', 'transaction', 3, 'success', NOW() - INTERVAL '1 hour'),
('01JQXK0000SYNCL003JKTLOG', '01JQXK0000OUTLET001JAKART', 'push_product', 'product', 10, 'success', NOW() - INTERVAL '5 hours'),
('01JQXK0000SYNCL004JKTLOG', '01JQXK0000OUTLET001JAKART', 'batch_sync', 'batch', 15, 'success', NOW() - INTERVAL '30 minutes'),
('01JQXK0000SYNCL005BDGLOG', '01JQXK0000OUTLET002BANDUN', 'push_order', 'order', 1, 'success', NOW() - INTERVAL '3 hours'),
('01JQXK0000SYNCL006BDGLOG', '01JQXK0000OUTLET002BANDUN', 'push_product', 'product', 3, 'success', NOW() - INTERVAL '6 hours')
ON CONFLICT DO NOTHING;
