SELECT 
	* 
FROM sales
LIMIT 10;


--        20 ADVANCED LEVEL QUESTIONS
--		===============================


--Q 1 Find Top 3 Brands by Revenue Per Year.


SELECT  DISTINCT brand,
		SUM(revenue_usd) AS total_revenue
		FROM sales
		GROUP BY 1
		ORDER BY 2 DESC;

--Q 2️ Identify Customers Giving Low Ratings (<4) But High Revenue (>500 USD)
--Detect anomaly behavior patterns.

SELECT 
    order_id,
    country,
    customer_income_level,
    customer_rating,
    revenue_usd
FROM sales
WHERE customer_rating < 4
  AND revenue_usd > 500;
  
  --multiple order exists
  SELECT 
    country,
    customer_income_level,
    SUM(revenue_usd) AS total_revenue,
    ROUND(AVG(customer_rating),2) AS avg_rating
FROM sales
GROUP BY country, customer_income_level
HAVING AVG(customer_rating) < 4
   AND SUM(revenue_usd) > 500
   ORDER BY 1 ;


--Q 3️  Calculate Rolling 3-Month Revenue Trend includes top brand and revenue during each month


WITH monthly_brand_revenue AS (
    SELECT
        DATE_TRUNC('month', order_date) AS month_date,
        TO_CHAR(DATE_TRUNC('month', order_date), 'MM-YYYY') AS month_year,
        brand,
        SUM(revenue_usd) AS brand_revenue
    FROM sales
    GROUP BY 1,2,3
),

monthly_total_revenue AS (
    SELECT
        month_date,
        month_year,
        SUM(brand_revenue) AS total_month_revenue
    FROM monthly_brand_revenue
    GROUP BY 1,2
),

rolling_revenue AS (
    SELECT
        month_date,
        month_year,
        total_month_revenue,
        SUM(total_month_revenue) OVER (
            ORDER BY month_date
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) AS rolling_3_month_revenue
    FROM monthly_total_revenue
),

top_brand_each_month AS (
    SELECT
        month_date,
        brand,
        brand_revenue,
        RANK() OVER (
            PARTITION BY month_date
            ORDER BY brand_revenue DESC
        ) AS rnk
    FROM monthly_brand_revenue
)

SELECT
    r.month_year,
    r.total_month_revenue,
    r.rolling_3_month_revenue,
    t.brand AS top_brand,
    t.brand_revenue AS top_brand_revenue
FROM rolling_revenue AS r
JOIN top_brand_each_month AS t
    ON r.month_date = t.month_date
WHERE t.rnk = 1
ORDER BY r.month_date;


--Q 4 Find Countries revenue and their Contribution in  Total Revenue


WITH country_revenue AS (
    	SELECT
        country,
        SUM(revenue_usd) AS country_total_revenue
    FROM sales
    GROUP BY country
),

total_revenue AS (
    SELECT
        SUM(revenue_usd) AS overall_revenue
    	FROM sales
)

SELECT
    c.country,
    c.country_total_revenue,
    ROUND((c.country_total_revenue / t.overall_revenue) * 100
			,2) AS revenue_percentage
	FROM country_revenue as c
CROSS JOIN total_revenue as t
ORDER BY revenue_percentage DESC;



--Q 5 Detect Outlier Orders Based on Revenue (Using Z-Score)
--Find unusually high-value orders.


WITH revenue_stats AS (
    SELECT
        AVG(revenue_usd) AS mean_revenue,
        STDDEV(revenue_usd) AS std_revenue
    FROM sales
)

SELECT
    s.order_id,
    s.brand,
    s.country,
    s.revenue_usd,
    ROUND(
        (s.revenue_usd - r.mean_revenue) / r.std_revenue,
        2
    ) AS z_score
FROM sales s
CROSS JOIN revenue_stats r
WHERE ABS((s.revenue_usd - r.mean_revenue) / r.std_revenue) > 2
ORDER BY z_score DESC;


-- Q 6 Rank Sales Channels by Profitability Within Each Country
--Use DENSE_RANK() partitioned by country.


WITH channel_revenue AS (
    SELECT
        country,
        sales_channel,
        SUM(revenue_usd) AS total_revenue
    FROM sales
    GROUP BY country, sales_channel
)

SELECT
    country,
    sales_channel,
    total_revenue,
    DENSE_RANK() OVER (
        PARTITION BY country
        ORDER BY total_revenue DESC
    ) AS revenue_rank
FROM channel_revenue
ORDER BY country, revenue_rank;

-- Q 7 Find Brand With Highest Average Discount But Lowest Rating

--Use aggregation + filtering logic.



WITH brand_summary AS (
    SELECT
        brand,
        AVG(discount_percent) AS avg_discount,
        AVG(customer_rating) AS avg_rating
    FROM sales
    GROUP BY brand
),

ranked_brands AS (
   	    SELECT
        brand,
        ROUND(avg_discount, 2) AS avg_discount,
        ROUND(avg_rating, 2) AS avg_rating,
        RANK() OVER (ORDER BY avg_discount DESC) AS discount_rank,
        RANK() OVER (ORDER BY avg_rating ASC) AS rating_rank
    FROM brand_summary
)

SELECT *
FROM ranked_brands
WHERE discount_rank = 1
     OR rating_rank = 1;

 -- Q 8 Calculate Repeat Brand Purchases Within Same Country
--Identify brand loyalty patterns.



WITH brand_orders AS (
    SELECT
        country,
        brand,
        COUNT(order_id) AS brand_orders
    FROM sales
    GROUP BY 1,2
),

country_total AS (
    SELECT
        country,
        COUNT(order_id) AS total_orders
    FROM sales
    GROUP BY 1
)

SELECT
    b.country,
    b.brand,
    b.brand_orders,
    ROUND( b.brand_orders * 100.0 / c.total_orders, 2
   		 ) AS brand_order_percentage
FROM brand_orders AS b
JOIN country_total AS c
    ON b.country = c.country
WHERE b.brand_orders > 1
ORDER BY b.country, brand_order_percentage DESC;


--Q 9Compare Revenue Between Online vs Retail Store by Year
--Pivot-style conditional aggregation.


WITH yearly_revenue AS (
    SELECT
        EXTRACT(YEAR FROM order_date) AS year,
        SUM(CASE WHEN sales_channel = 'Online' 
                 THEN revenue_usd ELSE 0 END) AS online_revenue,
        SUM(CASE WHEN sales_channel = 'Retail Store' 
                 THEN revenue_usd ELSE 0 END) AS retail_revenue
    FROM sales
    GROUP BY year
)

SELECT
    year,
    online_revenue,
    retail_revenue,
    (online_revenue - retail_revenue) AS revenue_difference,
    ROUND(
        (online_revenue - retail_revenue) * 100.0 
        / (retail_revenue), 2
   		 ) AS percent_difference
FROM yearly_revenue
ORDER BY year;



--Q 10 Find the Most Popular Size by Gender
--Use grouping + ranking.


WITH size_summary AS (
    SELECT
        gender,
        size,
        SUM(units_sold) AS total_units
    FROM sales
    GROUP BY gender, size
),

ranked_sizes AS (
    SELECT
       	 *,
       	 DENSE_RANK() OVER (
           			 PARTITION BY gender
           			 ORDER BY total_units DESC ) AS size_rank
    FROM size_summary
)

SELECT
    gender,
    size,
    total_units
FROM ranked_sizes
WHERE size_rank = 1
ORDER BY gender;



--Q 11 Identify Countries Where Online Sales > Retail Sales
--Compare channel performance using CASE logic.



WITH channel_revenue AS (
    SELECT
        country,
        sales_channel,
        SUM(revenue_usd) AS total_revenue
	    FROM sales
	    GROUP BY country, sales_channel
)

SELECT *
FROM (
    SELECT
        country,
        sales_channel,
        total_revenue,
        RANK() OVER (
            PARTITION BY country
            ORDER BY total_revenue DESC
        ) AS channel_rank
    FROM channel_revenue
) ranked
WHERE channel_rank = 1
AND sales_channel = 'Online'
ORDER BY country;


-- Q 12 Calculate Customer Lifetime Revenue by Income Level
--Use SUM over partition.


WITH clv AS (
	SELECT 
		customer_income_level,
		SUM(revenue_usd) AS total_revenue
	FROM sales
	GROUP BY 1
)
	SELECT 
		customer_income_level,
		total_revenue,
		DENSE_RANK () OVER(
		ORDER BY total_revenue DESC )
		AS RANKK
		FROM clv
		
--Q 13 Find Month With Highest Revenue Growth %
--Month-over-month growth calculation.



WITH monthly_revenue AS (
	SELECT 
	TO_CHAR (order_date,'yyyy-mm') AS year_month,
	SUM(revenue_usd) AS current_revenue,
	COUNT(units_sold) as total_units_sold
	FROM sales
	GROUP BY 1
	ORDER BY 1

),
previous_revenue AS (
	SELECT 
	year_month,
	total_units_sold,
	current_revenue,
	LAG (current_revenue) OVER (ORDER BY year_month ) AS previous_month_revenue
	FROM monthly_revenue
)

SELECT 
		year_month,
		total_units_sold,
		current_revenue,
		previous_month_revenue,
		current_revenue - previous_month_revenue AS revenue_diff,
		ROUND(
				(current_revenue - previous_month_revenue)*100 / previous_month_revenue 
				,2) AS mom_growth_percentage
FROM 
		previous_revenue


--Q 14  Identify Brand Dominance Per Country
--Find brand with maximum revenue per country.


SELECT  * 
FROM (
	SELECT 
		brand,
		country,
		SUM(revenue_usd) AS total_revenue,
		DENSE_RANK() OVER (PARTITION BY country ORDER BY SUM(revenue_usd) DESC ) AS rnk
		FROM sales
		GROUP BY 1,2
   ) t

WHERE rnk =1;



		--=== market share %
WITH brand_country_revenue AS (
    SELECT
        country,
        brand,
        SUM(revenue_usd) AS total_revenue
    FROM sales
    GROUP BY country, brand
)

SELECT
    country,
    brand,
    total_revenue,
    ROUND(
        total_revenue * 100.0
        / SUM(total_revenue) OVER (PARTITION BY country),
        2
    ) AS market_share_percentage,
    RANK() OVER (
        PARTITION BY country
        ORDER BY total_revenue DESC
    ) AS revenue_rank
FROM brand_country_revenue
ORDER BY country, revenue_rank;
	

SELECT 
	* 
FROM sales
LIMIT 10;
--Q 15Calculate Discount Effectiveness
--Compare average revenue before vs after discount groups.


SELECT 
	CASE
		 WHEN discount_percent =0 THEN 'NO DISCOUNT'
		 WHEN discount_percent BETWEEN 0 AND 10 THEN ' LOW_DISCOUNT'
		 WHEN discount_percent  BETWEEN 10 AND 20 THEN 'MEDIUM_DISCOUNT'
		 ELSE 'HIGH DISCOUNT'
	END AS discount_level,

		COUNT(*) AS total_orders,
		SUM(units_sold) AS total_units,
    	SUM(revenue_usd) AS total_revenue,
   		ROUND(AVG(revenue_usd), 2) AS avg_revenue_per_order
FROM SALES
		GROUP BY 1
		ORDER BY 1

--Q16 Detect Seasonal Category Trends
--Find which category peaks in which quarter.

--EACH QUARETR TREND
SELECT * FROM( 
	SELECT 
	EXTRACT (QUARTER FROM ORDER_DATE ) AS QUARTER,
	CATEGORY,
	SUM(REVENUE_USD) AS TOTAL_REVENUE,
	DENSE_RANK() OVER (PARTITION BY  EXTRACT (QUARTER FROM ORDER_DATE ) 
					   ORDER BY SUM(REVENUE_USD) DESC )
					   AS RNK
FROM SALES 
	GROUP BY 1,2
	ORDER BY 1,3 DESC
) T
WHERE RNK = 1


--=====

--WHICH  CATEGORY TREND IN WHICH QUARTER

WITH category_quarter_revenue AS (
    SELECT
        category,
        EXTRACT(QUARTER FROM order_date) AS quarter,
        SUM(revenue_usd) AS total_revenue
	    FROM sales
	    GROUP BY category, quarter
)

SELECT *
		FROM (
	    SELECT
        category,
        quarter,
        total_revenue,
        RANK() OVER (PARTITION BY category
     				 ORDER BY total_revenue DESC
        ) AS rnk
   		FROM category_quarter_revenue
) t
WHERE rnk = 1
ORDER BY category;


--Q17Find Payment Method Preference by Country
--Rank payment methods by usage frequency.


SELECT 
* 
FROM 
(
	 SELECT
		country,
		payment_method,
		COUNT(*) AS total_orders,
		SUM(revenue_usd) AS total_revenue,
		DENSE_RANK() OVER
			(PARTITION BY country 
			 ORDER BY SUM(revenue_usd) DESC ) 
			 AS rnk
	FROM sales
	GROUP BY 1,2
) t
 WHERE rnk = 1




--Q18 Identify High Revenue but Low Units Sold Products
--Detect premium product positioning.

	
WITH product_summary AS (
    SELECT
        brand,
        model_name,
        SUM(units_sold) AS total_units,
        SUM(revenue_usd) AS total_revenue,
        ROUND(SUM(revenue_usd) / SUM(units_sold),2) AS avg_price_per_unit
    FROM sales
    GROUP BY 1,2
)

SELECT *
FROM (
    SELECT *,
          ROUND(AVG(avg_price_per_unit) OVER (), 2) AS overall_avg_price
    FROM product_summary
) t
WHERE avg_price_per_unit > overall_avg_price
ORDER BY avg_price_per_unit DESC;


--Q 19 Calculate Revenue Contribution by Income Level Per Brand
--Nested aggregation problem.



---======Show Dominant Income Segment Per Brand


WITH brand_revenue AS (
    SELECT
        brand,
        customer_income_level,
        SUM(revenue_usd) AS total_revenue
    FROM sales
    GROUP BY brand, customer_income_level
)

SELECT
    brand,
    customer_income_level,
    total_revenue,
    ROUND(
        total_revenue * 100.0
        / SUM(total_revenue) OVER (PARTITION BY brand),
        2
    ) AS income_level_percentage
FROM brand_revenue
ORDER BY brand, income_level_percentage DESC;


---Q 20 Find the Top Income Segment for Each Brand

WITH brand_revenue AS (
SELECT
        brand,
        customer_income_level,
        SUM(revenue_usd) AS total_revenue
FROM sales
    	GROUP BY brand, customer_income_level
),

brand_percentage AS (
  	   SELECT
        brand,
        customer_income_level,
        total_revenue,
        ROUND(
           	 total_revenue * 100.0
            / SUM(total_revenue) OVER (PARTITION BY brand),  2 ) AS income_level_percentage
    FROM brand_revenue
),

ranked_data AS (
    SELECT *,
           ROW_NUMBER() OVER (
           PARTITION BY brand
           ORDER BY income_level_percentage DESC ) AS rn
    FROM brand_percentage
)

SELECT
    brand,
    customer_income_level,
    total_revenue,
    income_level_percentage
FROM ranked_data
WHERE rn = 1
ORDER BY brand;


-- 			END OF THE PROJECT
--			AUTHOR | PRINCE_PANDEY

