-- Window Functions Queries for Analysis
-- This file contains all analytical queries using window functions
-- 1. RANKING FUNCTIONS: Top customers by revenue in each region
WITH customer_revenue AS (
    SELECT 
        c.region,
        c.customer_id,
        c.name,
        SUM(t.amount) as total_revenue,
        ROW_NUMBER() OVER (PARTITION BY c.region ORDER BY SUM(t.amount) DESC) as row_num,
        RANK() OVER (PARTITION BY c.region ORDER BY SUM(t.amount) DESC) as revenue_rank,
        DENSE_RANK() OVER (PARTITION BY c.region ORDER BY SUM(t.amount) DESC) as dense_rank,
        -- FIX: CAST to NUMERIC before ROUNDING
        ROUND(CAST(PERCENT_RANK() OVER (PARTITION BY c.region ORDER BY SUM(t.amount) DESC) AS NUMERIC) * 100, 2) as percent_rank
    FROM transactions t
    JOIN customers c ON t.customer_id = c.customer_id
    GROUP BY c.region, c.customer_id, c.name
)
SELECT *
FROM customer_revenue
WHERE revenue_rank <= 5
ORDER BY region, revenue_rank;

-- Aggregate Functions: Running totals and moving averages
WITH monthly_sales AS (
    SELECT 
        -- Keep this as a date (month truncated), not text
        DATE_TRUNC('month', sale_date) AS sales_month,
        SUM(amount) AS monthly_sales
    FROM transactions
    GROUP BY DATE_TRUNC('month', sale_date)
)
SELECT 
    -- You can still format as YYYY-MM for readability
    TO_CHAR(sales_month, 'YYYY-MM') AS sales_month_label,
    monthly_sales,

    -- Running total
    SUM(monthly_sales) OVER (
        ORDER BY sales_month 
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_total,

    -- 3-month moving average (row-based: last 2 + current)
    ROUND(
        AVG(monthly_sales) OVER (
            ORDER BY sales_month 
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ), 2
    ) AS moving_avg_3month_rows,

    -- 3-month moving average (calendar-based: 2 months back + current)
    ROUND(
        AVG(monthly_sales) OVER (
            ORDER BY sales_month 
            RANGE BETWEEN INTERVAL '2 months' PRECEDING AND CURRENT ROW
        ), 2
    ) AS moving_avg_3month_range,

    -- Minimum in 3-row window (prev, current, next)
    MIN(monthly_sales) OVER (
        ORDER BY sales_month 
        ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING
    ) AS min_in_window,

    -- Maximum in 3-row window (prev, current, next)
    MAX(monthly_sales) OVER (
        ORDER BY sales_month 
        ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING
    ) AS max_in_window

FROM monthly_sales
ORDER BY sales_month;
-- Navigation Functions: Month-over-month growth analysis
WITH monthly_sales AS (
    SELECT 
        -- Extract year-month as a label (e.g., "2025-01").
        -- Note: TO_CHAR produces text, but since we only need ordering and labels, it's fine.
        TO_CHAR(sale_date, 'YYYY-MM') AS sales_month,
        
        -- Aggregate monthly total sales
        SUM(amount) AS total_sales
    FROM transactions
    GROUP BY TO_CHAR(sale_date, 'YYYY-MM')
)
SELECT 
    sales_month,

    -- Current month's sales
    total_sales AS current_month_sales,

    -- Sales from the previous month (LAG = look backwards)
    LAG(total_sales) OVER (ORDER BY sales_month) AS previous_month_sales,

    -- Sales from the next month (LEAD = look forwards)
    LEAD(total_sales) OVER (ORDER BY sales_month) AS next_month_sales,

    -- Growth % from previous to current month
    -- Formula: (current - previous) / previous * 100
    ROUND(
        ((total_sales - LAG(total_sales) OVER (ORDER BY sales_month)) 
        / NULLIF(LAG(total_sales) OVER (ORDER BY sales_month), 0)) * 100, 
    2) AS growth_percentage_from_previous,

    -- Growth % from current to next month
    -- Formula: (next - current) / current * 100
    ROUND(
        ((LEAD(total_sales) OVER (ORDER BY sales_month) - total_sales) 
        / NULLIF(total_sales, 0)) * 100, 
    2) AS growth_percentage_to_next

FROM monthly_sales
ORDER BY sales_month;
-- Distribution Functions: Customer segmentation by spending
WITH customer_spending AS (
    SELECT 
        c.customer_id,
        c.name,
        c.region,
        
        -- Total money spent by each customer
        SUM(t.amount) AS total_spent,
        
        -- Number of transactions per customer
        COUNT(t.transaction_id) AS transaction_count
    FROM transactions t
    JOIN customers c ON t.customer_id = c.customer_id
    GROUP BY c.customer_id, c.name, c.region
)
SELECT 
    customer_id,
    name,
    region,
    total_spent,
    transaction_count,

    -- Divide customers into 4 groups (quartiles) by spending
    NTILE(4) OVER (ORDER BY total_spent DESC) AS spending_quartile,

    -- Cumulative distribution: % of customers with spending <= current
    ROUND((CUME_DIST() OVER (ORDER BY total_spent))::numeric * 100, 2) 
        AS cumulative_distribution_percent,

    -- Percent rank: % of customers with lower spending (excludes equals)
    ROUND((PERCENT_RANK() OVER (ORDER BY total_spent))::numeric * 100, 2) 
        AS percent_rank

FROM customer_spending
ORDER BY total_spent DESC;
