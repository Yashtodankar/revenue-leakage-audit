USE revenue_audit;

-- Q1. Overall KPIs and leakage
SELECT COUNT(DISTINCT order_id) orders, ROUND(SUM(gross_revenue)) gross_rev, ROUND(SUM(discount_amount)) discounts,
       ROUND(SUM(net_revenue)) net_rev, ROUND(SUM(product_cost)) product_cost, ROUND(SUM(shipping_cost)) shipping,
       ROUND(SUM(refund_amount)) refunds, ROUND(SUM(gross_profit)) profit,
       ROUND(100*SUM(gross_profit)/SUM(net_revenue),2) margin_pct,
       ROUND(SUM(revenue_leakage_amount)) leakage,
       ROUND(100*SUM(revenue_leakage_amount)/SUM(gross_revenue),2) leakage_pct
FROM order_items;

-- Q2. Leakage composition: discount vs refund vs excess freight
SELECT 'Discount' leak_type, ROUND(SUM(discount_amount)) amount FROM order_items
UNION ALL SELECT 'Refund', ROUND(SUM(refund_amount)) FROM order_items
UNION ALL SELECT 'Excess freight', ROUND(SUM(excess_freight)) FROM shipping_costs;

-- Q3. Categories ranked by leakage (RANK)
SELECT p.category, ROUND(SUM(oi.net_revenue)) revenue, ROUND(SUM(oi.revenue_leakage_amount)) leakage,
       ROUND(100*SUM(oi.revenue_leakage_amount)/SUM(oi.gross_revenue),1) leakage_pct,
       RANK() OVER (ORDER BY SUM(oi.revenue_leakage_amount) DESC) leakage_rank
FROM order_items oi JOIN products p ON p.product_id = oi.product_id
GROUP BY p.category ORDER BY leakage_rank LIMIT 15;

-- Q4. Top 10 loss-making products
SELECT oi.product_id, p.category, COUNT(*) line_items, ROUND(SUM(oi.net_revenue)) revenue, ROUND(SUM(oi.gross_profit)) profit
FROM order_items oi JOIN products p ON p.product_id = oi.product_id
GROUP BY oi.product_id, p.category HAVING SUM(oi.gross_profit) < 0
ORDER BY profit LIMIT 10;

-- Q5. High-revenue products with thin margin (top 100 by revenue, margin < 15%) (DENSE_RANK)
WITH pr AS (
  SELECT product_id, SUM(net_revenue) revenue, SUM(gross_profit) profit FROM order_items GROUP BY product_id),
ranked AS (
  SELECT *, 100*profit/revenue margin_pct, DENSE_RANK() OVER (ORDER BY revenue DESC) rev_rank
  FROM pr WHERE revenue > 0)
SELECT r.rev_rank, r.product_id, p.category, ROUND(r.revenue) revenue, ROUND(r.profit) profit, ROUND(r.margin_pct,1) margin_pct
FROM ranked r JOIN products p ON p.product_id = r.product_id
WHERE r.rev_rank <= 100 AND r.margin_pct < 15 ORDER BY r.rev_rank;

-- Q6. Top 10 loss-making customers
SELECT o.customer_unique_id, c.customer_state, COUNT(DISTINCT o.order_id) orders,
       ROUND(SUM(oi.net_revenue)) revenue, ROUND(SUM(oi.gross_profit)) profit
FROM order_items oi JOIN orders o ON o.order_id = oi.order_id
JOIN customers c ON c.customer_unique_id = o.customer_unique_id
GROUP BY o.customer_unique_id, c.customer_state HAVING SUM(oi.gross_profit) < 0
ORDER BY profit LIMIT 10;

-- Q7. Regional (customer state) leakage ranking
SELECT c.customer_state, ROUND(SUM(oi.net_revenue)) revenue, ROUND(SUM(oi.gross_profit)) profit,
       ROUND(100*SUM(oi.gross_profit)/SUM(oi.net_revenue),2) margin_pct,
       ROUND(SUM(oi.revenue_leakage_amount)) leakage,
       ROUND(100*SUM(oi.shipping_cost)/SUM(oi.net_revenue),1) freight_pct_of_revenue,
       RANK() OVER (ORDER BY SUM(oi.revenue_leakage_amount) DESC) leakage_rank
FROM order_items oi JOIN orders o ON o.order_id = oi.order_id
JOIN customers c ON c.customer_unique_id = o.customer_unique_id
GROUP BY c.customer_state ORDER BY leakage_rank;

-- Q8. States with margin below the company average (subquery)
SELECT c.customer_state, ROUND(SUM(oi.net_revenue)) revenue,
       ROUND(100*SUM(oi.gross_profit)/SUM(oi.net_revenue),2) margin_pct
FROM order_items oi JOIN orders o ON o.order_id = oi.order_id
JOIN customers c ON c.customer_unique_id = o.customer_unique_id
GROUP BY c.customer_state
HAVING 100*SUM(oi.gross_profit)/SUM(oi.net_revenue) < (SELECT 100*SUM(gross_profit)/SUM(net_revenue) FROM order_items)
ORDER BY margin_pct;

-- Q9. Channel proxy: same-state vs cross-state fulfilment
SELECT CASE WHEN oi.seller_state = c.customer_state THEN 'Same-state' ELSE 'Cross-state' END route_type,
       COUNT(*) line_items, ROUND(SUM(oi.net_revenue)) revenue,
       ROUND(100*SUM(oi.shipping_cost)/SUM(oi.net_revenue),1) freight_pct,
       ROUND(100*SUM(oi.gross_profit)/SUM(oi.net_revenue),2) margin_pct,
       ROUND(100*SUM(oi.revenue_leakage_amount)/SUM(oi.gross_revenue),2) leakage_pct
FROM order_items oi JOIN orders o ON o.order_id = oi.order_id
JOIN customers c ON c.customer_unique_id = o.customer_unique_id
GROUP BY route_type;

-- Q10. Channel proxy: seller state profitability (DENSE_RANK, worst first)
SELECT seller_state, COUNT(*) line_items, ROUND(SUM(net_revenue)) revenue, ROUND(SUM(gross_profit)) profit,
       ROUND(100*SUM(gross_profit)/SUM(net_revenue),2) margin_pct,
       DENSE_RANK() OVER (ORDER BY SUM(gross_profit)/SUM(net_revenue)) margin_rank
FROM order_items GROUP BY seller_state HAVING COUNT(*) >= 100 ORDER BY margin_rank;

-- Q11. Which discount levels push margin below the 15% threshold
SELECT CASE WHEN discount_amount = 0 THEN '0 No discount'
            WHEN discount_amount/gross_revenue <= 0.05 THEN '1 Up to 5%'
            WHEN discount_amount/gross_revenue <= 0.10 THEN '2 5-10%'
            WHEN discount_amount/gross_revenue <= 0.20 THEN '3 10-20%'
            ELSE '4 Above 20%' END discount_band,
       COUNT(*) line_items, ROUND(SUM(net_revenue)) revenue,
       ROUND(100*SUM(gross_profit)/SUM(net_revenue),2) margin_pct,
       ROUND(100*AVG(below_margin_threshold),1) pct_line_items_below_15
FROM order_items GROUP BY discount_band ORDER BY discount_band;

-- Q12. Customer segments and discount rate (one-time vs repeat vs loyal)
WITH cust AS (
  SELECT customer_unique_id, COUNT(DISTINCT order_id) n FROM orders GROUP BY customer_unique_id)
SELECT CASE WHEN c.n = 1 THEN 'One-time' WHEN c.n <= 3 THEN 'Repeat (2-3)' ELSE 'Loyal (4+)' END segment,
       COUNT(DISTINCT c.customer_unique_id) customers,
       ROUND(100*SUM(oi.discount_amount)/SUM(oi.gross_revenue),2) discount_rate_pct,
       ROUND(100*SUM(oi.gross_profit)/SUM(oi.net_revenue),2) margin_pct
FROM order_items oi JOIN orders o ON o.order_id = oi.order_id
JOIN cust c ON c.customer_unique_id = o.customer_unique_id
GROUP BY segment;

-- Q13. Product-level price anomalies (price >50% away from product list price)
SELECT oi.order_id, oi.product_id, p.category, oi.price, p.list_price,
       ROUND(100*(oi.price - p.list_price)/p.list_price,1) price_gap_pct
FROM order_items oi JOIN products p ON p.product_id = oi.product_id
WHERE oi.product_id IN (SELECT product_id FROM order_items GROUP BY product_id HAVING COUNT(*) >= 5)
  AND ABS(oi.price - p.list_price)/p.list_price > 0.5
ORDER BY ABS(oi.price - p.list_price) DESC LIMIT 50;

-- Q14. Order-level anomalies: discount above 50% of gross value
WITH ord AS (
  SELECT order_id, SUM(gross_revenue) gross, SUM(discount_amount) disc, SUM(gross_profit) profit
  FROM order_items GROUP BY order_id)
SELECT order_id, ROUND(gross,2) gross, ROUND(disc,2) discount, ROUND(100*disc/gross,1) discount_pct, ROUND(profit,2) profit
FROM ord WHERE disc/gross > 0.5 ORDER BY discount_pct DESC, gross DESC LIMIT 50;

-- Q15. Refund impact on profit
SELECT ROUND(SUM(gross_profit)) profit_after_refunds,
       ROUND(SUM(gross_profit + refund_amount)) profit_before_refunds,
       ROUND(SUM(refund_amount)) refunds,
       ROUND(100*SUM(refund_amount)/SUM(net_revenue),2) refund_pct_of_revenue
FROM order_items;

-- Q16. Refunds by reason
SELECT return_reason, COUNT(*) line_items, ROUND(SUM(refund_amount)) refunded
FROM returns GROUP BY return_reason;

-- Q17. Refund rate by category (categories with 200+ line_items)
SELECT p.category, COUNT(*) line_items, SUM(r.order_id IS NOT NULL) refunded_line_items,
       ROUND(100*SUM(r.order_id IS NOT NULL)/COUNT(*),2) refund_rate_pct,
       ROUND(SUM(oi.refund_amount)) refund_value
FROM order_items oi JOIN products p ON p.product_id = oi.product_id
LEFT JOIN returns r ON r.order_id = oi.order_id AND r.order_item_id = oi.order_item_id
GROUP BY p.category HAVING COUNT(*) >= 200 ORDER BY refund_rate_pct DESC LIMIT 10;

-- Q18. Shipping cost share of price vs margin
SELECT CASE WHEN sc.freight_pct < 10 THEN '1 Under 10%' WHEN sc.freight_pct < 20 THEN '2 10-20%'
            WHEN sc.freight_pct < 30 THEN '3 20-30%' WHEN sc.freight_pct < 50 THEN '4 30-50%'
            ELSE '5 Above 50%' END freight_band,
       COUNT(*) line_items, ROUND(SUM(oi.net_revenue)) revenue, ROUND(SUM(oi.shipping_cost)) freight,
       ROUND(100*SUM(oi.gross_profit)/SUM(oi.net_revenue),2) margin_pct
FROM order_items oi JOIN shipping_costs sc ON sc.order_id = oi.order_id AND sc.order_item_id = oi.order_item_id
GROUP BY freight_band ORDER BY freight_band;

-- Q19. Monthly revenue, margin and month-over-month change (LAG)
WITH m AS (
  SELECT d.ym, SUM(oi.net_revenue) revenue, SUM(oi.gross_profit) profit
  FROM order_items oi JOIN orders o ON o.order_id = oi.order_id
  JOIN date_dim d ON d.full_date = o.purchase_date
  WHERE d.ym BETWEEN '2017-01' AND '2018-08' GROUP BY d.ym)
SELECT ym, ROUND(revenue) revenue, ROUND(profit) profit,
       ROUND(100*profit/revenue,2) margin_pct,
       ROUND(100*profit/revenue - LAG(100*profit/revenue) OVER (ORDER BY ym),2) margin_change_pp,
       ROUND(100*(revenue - LAG(revenue) OVER (ORDER BY ym))/LAG(revenue) OVER (ORDER BY ym),1) mom_revenue_pct
FROM m ORDER BY ym;

-- Q20. Three least profitable categories in each state (ROW_NUMBER)
WITH x AS (
  SELECT c.customer_state, p.category, SUM(oi.net_revenue) revenue, SUM(oi.gross_profit) profit
  FROM order_items oi JOIN orders o ON o.order_id = oi.order_id
  JOIN customers c ON c.customer_unique_id = o.customer_unique_id
  JOIN products p ON p.product_id = oi.product_id
  GROUP BY c.customer_state, p.category),
r AS (SELECT *, ROW_NUMBER() OVER (PARTITION BY customer_state ORDER BY profit) rn FROM x)
SELECT customer_state, category, ROUND(revenue) revenue, ROUND(profit) profit, rn
FROM r WHERE rn <= 3 ORDER BY customer_state, rn;