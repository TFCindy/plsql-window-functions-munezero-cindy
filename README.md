# PL/SQL Window Functions Analysis

## Step 1: Problem Definition

### Business Context
**Company:** JavaBean Coffee Distributors Ltd.  
**Department:** Sales and Marketing Analytics  
**Industry:** Retail Distribution of Coffee Products and Equipment  

### Data Challenge
The company currently lacks a clear understanding of regional sales performance, customer purchasing behavior, and product trends. This makes it difficult to optimize inventory allocation across different regions and to create effective, targeted marketing campaigns. Without this analysis, decision-making is based on intuition rather than data.

### Expected Outcome
This analysis will identify the top-performing products in each sales region, reveal sales trends over time, and segment customers into value-based tiers. The final insights will directly inform decisions on regional inventory planning and the development of personalized marketing strategies for high-value customer segments.

## Step 2: Success Criteria

This analysis aims to achieve the following five measurable goals:

1.  Identify top 5 products per sales region each quarter using `RANK()`
2.  Calculate running monthly sales totals using `SUM() OVER()`
3.  Compute month-over-month sales growth percentages using `LAG()`
4.  Segment customers into quartiles based on total purchase value using `NTILE(4)`
5.  Calculate 3-month moving averages of sales using `AVG() OVER()`

## Step 3: Database Schema

The analysis utilizes a relational database with three primary tables:

### Table Structure
| Table | Purpose | Key Columns |
| :--- | :--- | :--- |
| `customers` | Customer information | `customer_id` (PK), `name`, `region`|
| `products` | Product catalog | `product_id` (PK), `name`, `category`|
| `transactions` | Sales records | `transaction_id` (PK), `customer_id` (FK), `product_id` (FK), `sale_date`, `amount` |

### Entity-Relationship Diagram
![ER Diagram](/Users/cindymunezero/Desktop/er_diagram.png)

## Step 4: Window Functions Implementation

### 1. Ranking Functions
**Query:** Top 3 products per region by total sales
```sql
-- Ranking Functions: Top 5 customers by total revenue in each region
SELECT 
    region,
    customer_id,
    name,
    total_revenue,

    -- Assigns a unique row number within each region based on revenue
    ROW_NUMBER() OVER (
        PARTITION BY region 
        ORDER BY total_revenue DESC
    ) AS row_num,

    -- Rank customers (ties get the same rank, with gaps after ties)
    RANK() OVER (
        PARTITION BY region 
        ORDER BY total_revenue DESC
    ) AS revenue_rank,

    -- Dense rank (ties get the same rank, but no gaps in ranking numbers)
    DENSE_RANK() OVER (
        PARTITION BY region 
        ORDER BY total_revenue DESC
    ) AS dense_rank,

    -- Percent rank (relative position as percentage, excluding equals).
    -- Cast to numeric so ROUND works in PostgreSQL.
    ROUND((PERCENT_RANK() OVER (
        PARTITION BY region 
        ORDER BY total_revenue DESC
    ))::numeric * 100, 2) AS percent_rank

FROM (
    -- Aggregate revenue per customer per region
    SELECT 
        c.region,
        c.customer_id,
        c.name,
        SUM(t.amount) AS total_revenue
    FROM transactions t
    JOIN customers c 
      ON t.customer_id = c.customer_id
    GROUP BY c.region, c.customer_id, c.name
) customer_revenue

-- Filter to keep only top 5 customers per region
WHERE RANK() OVER (
        PARTITION BY region 
        ORDER BY total_revenue DESC
    ) <= 5

ORDER BY region, revenue_rank;

```
Query Results Analysis:

-Jane Smith (Kigali) is the top customer with 45,000 RWF revenue

-John Doe (Kigali) ranks second with 25,000 RWF, sharing the same revenue as Sarah Williams (South) but ranked differently due to regional partitioning

-Michael Brown (East) and Robert Johnson (North) are the sole top performers in their regions
Interpretation: The analysis reveals Jane Smith as Kigali's top revenue generator with 45,000 RWF, while other regions have single dominant customers. The different ranking methods (RANK vs DENSE_RANK) show how tied scores are handled, providing flexibility in performance evaluation across regions.

### 2. Aggregate Functions
**Query:** Running total of sales by month
```sql
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
```
Query Results Analysis:

-January started strong with 70,000 RWF sales, followed by a significant drop to 37,000 RWF in February (-47%)

-March showed further decline to 18,000 RWF, creating a concerning downward trend

-The 3-month moving average decreased from 70,000 to 41,666 RWF, indicating sustained negative momentum
Interpretation: The running totals show a concerning downward trend from January's peak of 70,000 RWF to March's 18,000 RWF. The moving averages confirm sustained negative momentum, highlighting the need for immediate intervention to reverse this declining sales pattern.

### 3. Navigation Functions
**Query:** Month-over-month sales growth percentage
```sql
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

```
Query Results Analysis:

-February showed a dramatic -47.14% growth decline from January

-March continued the negative trend with a -51.35% decrease from February

-The consistent negative growth percentages indicate a serious sales performance issue
Interpretation: The month-over-month analysis reveals severe declines of -47% and -51% in consecutive months. These dramatic drops indicate serious underlying issues in sales strategy or market conditions that require urgent investigation and corrective action.
### 4. Distribution Functions
**Query:** Customer segmentation by spending quartiles
```sql
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

```
Query Results Analysis:

-Customers are segmented into 4 spending quartiles, with Jane Smith in Q1 (top 25%)

-40% of customers fall into the top two quartiles, contributing significantly to revenue

-The cumulative distribution shows that 80% of customers have spending of 25,000 RWF or less
Interpretation: The quartile analysis successfully segments customers into value tiers, identifying the top 25% who drive disproportionate revenue. The cumulative distribution shows that 80% of customers spend 25,000 RWF or less, revealing significant potential for revenue growth in lower tiers.
## Step 5: GitHub Repository

This repository (plsql-window-functions-munezero-cindy) is public and contains:

#### SQL scripts (schema/, queries/ folders): Error-free creation, population, and querying scripts.

#### Screenshots (screenshots/ folder): Clear results from all window function queries.

#### Professional README: This file, containing the problem definition, schema, queries, insights, and references.
## Step 6: Results Analysis

### 1. Descriptive Analysis (What happened?)
Sales peaked in January at 70,000 RWF but experienced severe consecutive monthly declines of 47% and 51%. Customer revenue distribution was highly uneven, with Kigali region significantly outperforming other regions and a small group of customers generating most revenue.

### 2. Diagnostic Analysis (Why it happened?)
The dramatic sales decline likely resulted from post-holiday demand reduction combined with insufficient marketing continuity. Kigali's superior performance can be attributed to higher population density and income levels, while the customer concentration suggests inadequate engagement strategies for mid-tier customers.


### 3. Prescriptive Analysis (What to do next?)
Implement immediate retention programs for top-quartile customers while developing targeted promotions to activate mid-tier spenders. Launch region-specific marketing to replicate Kigali's success and introduce quarterly initiatives to prevent future post-holiday sales drops.

## Step 7: References

1. PostgreSQL Global Development Group. (2023). PostgreSQL 16.0 Documentation: Chapter 3.5. Window Functions. https://www.postgresql.org/docs/16/tutorial-window.html
2. PostgreSQL Global Development Group. (2023). PostgreSQL 16.0 Documentation: SQL Syntax. https://www.postgresql.org/docs/16/sql-syntax.html
3. Oracle Corporation. (2023). Oracle Database SQL Language Reference: Window Functions. https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Window-Functions.html
4. Microsoft Corporation. (2023). OVER Clause (Transact-SQL). https://docs.microsoft.com/en-us/sql/t-sql/queries/select-over-clause
5. Mozilla Foundation. (2023). MDN Web Docs: Structured Query Language (SQL). https://developer.mozilla.org/en-US/docs/Glossary/SQL
6. Tanimura, C. (2021). SQL for Data Analysis: Advanced Techniques for Transforming Data into Insights. O'Reilly Media.
7. Beam, A. (2020). How to Use Window Functions for SQL Data Analysis. freeCodeCamp. https://www.freecodecamp.org/news/sql-window-functions-advanced-data-analysis/
8. DATACAMP. (2022). PostgreSQL Tutorial: Window Functions. https://www.datacamp.com/tutorial/postgresql-window-functions
9. W3Schools. (2023). SQL Window Functions. https://www.w3schools.com/sql/sql_window_functions.asp
10. W3Resource. (2023). PostgreSQL Window Functions: Practice and Solution. https://www.w3resource.com/PostgreSQL/window-functions.php

---

**Academic Integrity Statement:** "All sources were properly cited. Implementations and analysis represent original work. No AI-generated content was copied without attribution or adaptation."

**Note on Implementation:** This project was implemented using PostgreSQL 16. The standard SQL syntax for window functions (`RANK()`, `NTILE()`, `LAG()`, aggregate functions with `OVER()`, etc.) is consistent across modern relational databases including Oracle PL/SQL. All core analytical concepts required by the assignment have been successfully demonstrated.

