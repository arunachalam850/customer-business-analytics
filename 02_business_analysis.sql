USE business_analytics;

-- Q1 Revenue by month
SELECT DATE_FORMAT(order_datetime,'%Y-%m') AS month,
       SUM(order_total) AS revenue
FROM orders
WHERE order_status IN ('Completed','Returned')
GROUP BY 1
ORDER BY 1;

-- Q2 Monthly YoY growth
WITH monthly AS (
    SELECT DATE_FORMAT(order_datetime,'%Y-%m') AS month,
           SUM(order_total) AS revenue
    FROM orders
    WHERE order_status IN ('Completed','Returned')
    GROUP BY 1
)
SELECT month, revenue,
       LAG(revenue,12) OVER (ORDER BY month) AS prior_year_revenue,
       ROUND((revenue / NULLIF(LAG(revenue,12) OVER (ORDER BY month),0)-1)*100,2) AS yoy_growth_pct
FROM monthly
ORDER BY month;

-- Q3 Top 10 customers by revenue
SELECT c.customer_id, c.customer_name,
       SUM(o.order_total) AS revenue
FROM customers c
JOIN orders o ON o.customer_id=c.customer_id
WHERE o.order_status IN ('Completed','Returned')
GROUP BY c.customer_id, c.customer_name
ORDER BY revenue DESC
LIMIT 10;

-- Q4 Customers whose spend decreased >30% YoY
WITH yearly AS (
    SELECT customer_id,
           YEAR(order_datetime) AS yr,
           SUM(order_total) AS revenue
    FROM orders
    WHERE order_status IN ('Completed','Returned')
    GROUP BY customer_id, YEAR(order_datetime)
),
paired AS (
    SELECT customer_id, yr, revenue,
           LAG(revenue) OVER (PARTITION BY customer_id ORDER BY yr) AS prior_year_revenue
    FROM yearly
)
SELECT customer_id, yr, revenue, prior_year_revenue,
       ROUND((revenue/prior_year_revenue-1)*100,2) AS yoy_change_pct
FROM paired
WHERE prior_year_revenue > 0
  AND revenue < prior_year_revenue * 0.70
ORDER BY yoy_change_pct;

-- Q5 Category profitability
SELECT p.category,
       SUM(oi.net_line_sales) AS revenue,
       SUM(oi.quantity * p.unit_cost) AS product_cost,
       SUM(oi.net_line_sales - oi.quantity*p.unit_cost) AS gross_profit,
       ROUND(100 * SUM(oi.net_line_sales - oi.quantity*p.unit_cost) / NULLIF(SUM(oi.net_line_sales),0),2) AS margin_pct
FROM order_items oi
JOIN products p ON p.product_id=oi.product_id
JOIN orders o ON o.order_id=oi.order_id
WHERE o.order_status IN ('Completed','Returned')
GROUP BY p.category
ORDER BY gross_profit DESC;

-- Q6 Discount impact: compare margin bands
SELECT
    CASE
      WHEN oi.discount_pct < 10 THEN '<10%'
      WHEN oi.discount_pct < 20 THEN '10-20%'
      WHEN oi.discount_pct < 30 THEN '20-30%'
      ELSE '30%+'
    END AS discount_band,
    SUM(oi.net_line_sales) AS revenue,
    ROUND(100 * SUM(oi.net_line_sales - oi.quantity*p.unit_cost) / NULLIF(SUM(oi.net_line_sales),0),2) AS margin_pct
FROM order_items oi
JOIN products p ON p.product_id=oi.product_id
JOIN orders o ON o.order_id=oi.order_id
WHERE o.order_status IN ('Completed','Returned')
GROUP BY 1
ORDER BY 1;

-- Q7 RFM-style customer segmentation
WITH base AS (
    SELECT c.customer_id,
           DATEDIFF(CURDATE(), MAX(o.order_datetime)) AS recency_days,
           COUNT(DISTINCT o.order_id) AS frequency,
           SUM(o.order_total) AS monetary
    FROM customers c
    JOIN orders o ON o.customer_id=c.customer_id
    WHERE o.order_status IN ('Completed','Returned')
    GROUP BY c.customer_id
),
seg AS (
    SELECT *,
      NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
      NTILE(5) OVER (ORDER BY frequency) AS f_score,
      NTILE(5) OVER (ORDER BY monetary) AS m_score
    FROM base
)
SELECT *,
       CASE
         WHEN r_score >=4 AND f_score >=4 AND m_score >=4 THEN 'Champions'
         WHEN r_score >=3 AND f_score >=3 THEN 'Loyal'
         WHEN r_score <=2 AND f_score >=3 THEN 'At Risk'
         WHEN r_score <=2 AND f_score <=2 THEN 'Lost'
         ELSE 'Potential Loyalist'
       END AS customer_segment
FROM seg;

-- Q8 Repeat customer rate
WITH order_counts AS (
    SELECT customer_id, COUNT(DISTINCT order_id) AS orders_count
    FROM orders
    WHERE order_status IN ('Completed','Returned')
    GROUP BY customer_id
)
SELECT ROUND(100 * SUM(orders_count>1) / COUNT(*),2) AS repeat_customer_pct
FROM order_counts;

-- Q9 Return rate by category
SELECT p.category,
       COUNT(DISTINCT r.return_id) AS returns,
       COUNT(DISTINCT oi.order_id) AS orders,
       ROUND(100 * COUNT(DISTINCT r.return_id) / NULLIF(COUNT(DISTINCT oi.order_id),0),2) AS return_rate_pct
FROM returns r
JOIN products p ON p.product_id=r.product_id
JOIN order_items oi ON oi.product_id=r.product_id
GROUP BY p.category
ORDER BY return_rate_pct DESC;

-- Q10 Support performance
SELECT issue_type,
       COUNT(*) AS tickets,
       ROUND(AVG(resolution_hours),2) AS avg_resolution_hours,
       ROUND(AVG(csat),2) AS avg_csat
FROM support_tickets
GROUP BY issue_type
ORDER BY tickets DESC;
