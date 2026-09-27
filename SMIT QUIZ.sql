
-- ============================================================
-- TASK 1: Sales Detail Dataset
-- ============================================================
SELECT
    o.order_id,
    o.order_date,
    c.first_name + ' ' + c.last_name AS customer_name,
    s.store_name,
    st.first_name + ' ' + st.last_name AS staff_name,
    p.product_name,
    cat.category_name,
    b.brand_name,
    oi.quantity,
    oi.list_price,
    oi.discount,
    oi.quantity * oi.list_price * (1 - oi.discount) AS net_line_revenue
FROM sales.orders o
INNER JOIN sales.order_items oi ON o.order_id = oi.order_id
INNER JOIN sales.customers c ON o.customer_id = c.customer_id
INNER JOIN sales.stores s ON o.store_id = s.store_id
INNER JOIN sales.staffs st ON o.staff_id = st.staff_id
INNER JOIN production.products p ON oi.product_id = p.product_id
INNER JOIN production.categories cat ON p.category_id = cat.category_id
INNER JOIN production.brands b ON p.brand_id = b.brand_id
WHERE o.order_status = 4
ORDER BY o.order_date DESC;


-- ============================================================
-- TASK 2: Store Performance Summary
-- ============================================================
SELECT
    s.store_name,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(oi.quantity) AS total_units_sold,
    SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_net_revenue,
    SUM(oi.quantity * oi.list_price * (1 - oi.discount)) / COUNT(DISTINCT o.order_id) AS avg_order_value
FROM sales.stores s
INNER JOIN sales.orders o ON s.store_id = o.store_id
INNER JOIN sales.order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 4
GROUP BY s.store_name
ORDER BY total_net_revenue DESC;


-- ============================================================
-- TASK 3: High-Value Customers
-- ============================================================
SELECT
    c.customer_id,
    c.first_name + ' ' + c.last_name AS customer_name,
    COUNT(DISTINCT o.order_id) AS completed_orders,
    SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_spending
FROM sales.customers c
INNER JOIN sales.orders o ON c.customer_id = o.customer_id
INNER JOIN sales.order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 4
GROUP BY c.customer_id, c.first_name, c.last_name
HAVING SUM(oi.quantity * oi.list_price * (1 - oi.discount)) >
(
    -- this subquery calculates the average spending per customer
    SELECT AVG(cust_total)
    FROM
    (
        SELECT SUM(oi2.quantity * oi2.list_price * (1 - oi2.discount)) AS cust_total
        FROM sales.orders o2
        INNER JOIN sales.order_items oi2 ON o2.order_id = oi2.order_id
        WHERE o2.order_status = 4
        GROUP BY o2.customer_id
    ) AS customer_totals
)
ORDER BY total_spending DESC;


-- ============================================================
-- TASK 4: Inventory Risk Report
-- ============================================================
SELECT
    p.product_name,
    s.store_name,
    stk.quantity AS current_quantity,
    cat.category_name,
    b.brand_name
FROM production.stocks stk
INNER JOIN production.products p ON stk.product_id = p.product_id
INNER JOIN production.categories cat ON p.category_id = cat.category_id
INNER JOIN production.brands b ON p.brand_id = b.brand_id
INNER JOIN sales.stores s ON stk.store_id = s.store_id
WHERE stk.quantity < 5
ORDER BY stk.quantity ASC;

-- ============================================================
-- TASK 5: Top 3 Products in Each Category
-- ============================================================
SELECT category_name, product_name, total_units_sold, total_net_revenue, product_rank
FROM
(
    SELECT
        cat.category_name,
        p.product_name,
        SUM(oi.quantity) AS total_units_sold,
        SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_net_revenue,
        DENSE_RANK() OVER (PARTITION BY cat.category_name ORDER BY SUM(oi.quantity * oi.list_price * (1 - oi.discount)) DESC) AS product_rank
    FROM sales.order_items oi
    INNER JOIN sales.orders o ON oi.order_id = o.order_id
    INNER JOIN production.products p ON oi.product_id = p.product_id
    INNER JOIN production.categories cat ON p.category_id = cat.category_id
    WHERE o.order_status = 4
    GROUP BY cat.category_name, p.product_name
) AS ranked_products
WHERE product_rank <= 3
ORDER BY category_name, product_rank;


-- ============================================================
-- TASK 6: Monthly Sales Trend
-- ============================================================
SELECT
    sales_year,
    sales_month,
    total_net_revenue,
    LAG(total_net_revenue) OVER (ORDER BY sales_year, sales_month) AS previous_month_revenue,
    total_net_revenue - LAG(total_net_revenue) OVER (ORDER BY sales_year, sales_month) AS revenue_change
FROM
(
    SELECT
        YEAR(o.order_date) AS sales_year,
        MONTH(o.order_date) AS sales_month,
        SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_net_revenue
    FROM sales.orders o
    INNER JOIN sales.order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 4
    GROUP BY YEAR(o.order_date), MONTH(o.order_date)
) AS monthly_totals
ORDER BY sales_year, sales_month;


-- ============================================================
-- TASK 7: Reusable Reporting View
-- ============================================================
CREATE OR ALTER VIEW sales.vw_customer_sales_summary AS
SELECT
    c.customer_id,
    c.first_name + ' ' + c.last_name AS customer_name,
    COUNT(DISTINCT o.order_id) AS total_completed_orders,
    ISNULL(SUM(oi.quantity), 0) AS total_units_purchased,
    ISNULL(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 0) AS total_net_revenue,
    MAX(o.order_date) AS most_recent_order_date
FROM sales.customers c
LEFT JOIN sales.orders o ON c.customer_id = o.customer_id AND o.order_status = 4
LEFT JOIN sales.order_items oi ON o.order_id = oi.order_id
GROUP BY c.customer_id, c.first_name, c.last_name;
GO

SELECT * FROM sales.vw_customer_sales_summary;


-- ============================================================
-- TASK 8: Safe Data Modification
-- ============================================================
BEGIN TRANSACTION;

SELECT customer_id, phone FROM sales.customers WHERE customer_id = 1;

UPDATE sales.customers
SET phone = '(999) 555-0101'
WHERE customer_id = 1;


SELECT customer_id, phone FROM sales.customers WHERE customer_id = 1;

COMMIT TRANSACTION;


-- ============================================================
-- TASK 9: Store Sales Procedure
-- ============================================================
CREATE OR ALTER PROCEDURE sales.usp_store_sales_report
    @store_id INT,
    @start_date DATE,
    @end_date DATE
AS
BEGIN
    -- first check if the dates make sense
    IF @start_date > @end_date
    BEGIN
        PRINT 'Error: start date cannot be after end date.';
        RETURN;
    END

    SELECT
        p.product_name,
        SUM(oi.quantity) AS total_units_sold,
        SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_net_revenue
    FROM sales.orders o
    INNER JOIN sales.order_items oi ON o.order_id = oi.order_id
    INNER JOIN production.products p ON oi.product_id = p.product_id
    WHERE o.order_status = 4
        AND o.store_id = @store_id
        AND o.order_date BETWEEN @start_date AND @end_date
    GROUP BY p.product_name
    ORDER BY total_net_revenue DESC;
END;
GO

EXEC sales.usp_store_sales_report @store_id = 1, @start_date = '2018-01-01', @end_date = '2018-12-31';


-- ============================================================
-- TASK 10: My Own Insight Query
-- ============================================================
SELECT
    b.brand_name,
    cat.category_name,
    COUNT(DISTINCT o.customer_id) AS unique_buyers,
    SUM(oi.quantity) AS total_units_sold,
    SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_net_revenue
FROM sales.orders o
INNER JOIN sales.order_items oi ON o.order_id = oi.order_id
INNER JOIN production.products p ON oi.product_id = p.product_id
INNER JOIN production.brands b ON p.brand_id = b.brand_id
INNER JOIN production.categories cat ON p.category_id = cat.category_id
WHERE o.order_status = 4
GROUP BY b.brand_name, cat.category_name
ORDER BY total_net_revenue DESC;
