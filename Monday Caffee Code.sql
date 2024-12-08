DROP TABLE IF EXISTS city;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS sales;


CREATE TABLE city
(
	city_id INT PRIMARY KEY,
	city_name VARCHAR(15),
	population BIGINT,
	estimated_rent FLOAT,
	city_rank INT
);

CREATE TABLE customers
(
	customer_id INT PRIMARY KEY,
	customer_name VARCHAR(25),	
	city_id INT,
	CONSTRAINT fk_city FOREIGN KEY (city_id) REFERENCES city(city_id)
	
);


CREATE TABLE products
(
	product_id INT PRIMARY KEY,
	product_name VARCHAR(35),
	price FLOAT
	
);


CREATE TABLE sales
(
	sale_id	INT PRIMARY KEY,
	sale_date	VARCHAR(50),
	product_id	INT,
	customer_id	INT,
	total FLOAT,
	rating INT,
	CONSTRAINT fk_products FOREIGN KEY (product_id) REFERENCES products(product_id),
	CONSTRAINT fk_customers FOREIGN KEY (customer_id) REFERENCES customers(customer_id) 
);

--Monday Caffee --Data Analysis
SELECT * FROM city
SELECT * FROM products
SELECT * FROM customers
SELECT * FROM sales


--Repots & Data Analysis
-- Q.1 Coffee Consumers Count
-- How many people in each city are estimated to consume coffee, given that 25% of the population does?

SELECT 
	city_name,
	ROUND((population*0.25)/1000000,2) AS coffee_consumers_in_millions

FROM city
ORDER BY 2 DESC

-- -- Q.2
-- Total Revenue from Coffee Sales
-- What is the total revenue generated from coffee sales across all cities in the last quarter of 2023?
--responseb1
SELECT 
	
	SUM(total)
FROM sales
WHERE to_date(sale_date, 'yyyy-mm-dd') BETWEEN '2023-10-01' AND '2023-12-31'

--or
/*
WHERE 
	EXTRACT(YEAR FROM s.sale_date)  = 2023
	AND
	EXTRACT(quarter FROM s.sale_date) = 4
*/

SELECT
	c.city_name,
	SUM(s.total) AS city_sales
FROM sales s
JOIN customers cus
ON cus.customer_id=s.customer_id
JOIN city c
ON c.city_id=cus.city_id
WHERE 
	to_date(sale_date, 'yyyy-mm-dd') BETWEEN '2023-10-01'AND '2023-12-31'
GROUP BY 1
ORDER by 2 DESC



-- Q.3
-- Sales Count for Each Product
-- How many units of each coffee product have been sold?


SELECT
	product_name,
	COUNT(sale_id) AS total_order

FROM sales s
JOIN products p
ON s.product_id = p.product_id
GROUP by 1
ORDER by 2

-- Q.4
-- Average Sales Amount per City
-- What is the average sales amount per customer in each city?

-- city abd total sale
-- no cx in each these city

SELECT
	c.city_name,
	SUM(s.total),
	COUNT(DISTINCT(cus.customer_id)),
	round(SUM(s.total)::Numeric/COUNT(DISTINCT(cus.customer_id)),2)
FROM sales s
JOIN customers cus
ON cus.customer_id=s.customer_id
JOIN city c
ON c.city_id=cus.city_id
GROUP BY 1
ORDER BY 4 DESC


-- -- Q.5
-- City Population and Coffee Consumers (25%)
-- Provide a list of cities along with their populations and estimated coffee consumers.
-- return city_name, total current cx, estimated coffee consumers (25%)


SELECT 
    city_name,
    ROUND((c.population * 0.25) / 1000000, 2) AS coffee_consumers_in_millions,
    COUNT(DISTINCT cus.customer_id) AS unique_customers
FROM city c
JOIN customers cus 
ON cus.city_id = c.city_id
JOIN sales s 
ON s.customer_id = cus.customer_id
GROUP BY 1, c.population
ORDER BY 1;

-- -- Q6
-- Top Selling Products by City
-- What are the top 3 selling products in each city based on sales volume?

SELECT *
FROM (
SELECT
	city_name,
	product_name,
	COUNT(s.sale_id) AS total_orders,
	DENSE_RANK() OVER(PARTITION BY c.city_name ORDER BY COUNT(s.sale_id) DESC) as rank
FROM city c
JOIN customers cus 
ON cus.city_id = c.city_id
JOIN sales s 
ON s.customer_id = cus.customer_id
JOIN products p
ON s.product_id = p.product_id
GROUP BY 1, 2)
WHERE rank <= 3


-- Q.7
-- Customer Segmentation by City
-- How many unique customers are there in each city who have purchased coffee products?

SELECT
	city_name,
	COUNT(DISTINCT(cus.customer_id))
FROM city c
JOIN customers cus 
ON cus.city_id = c.city_id
JOIN sales s 
ON s.customer_id = cus.customer_id
WHERE s.product_id BETWEEN 1 AND 14
GROUP BY 1


-- -- Q.8
-- Average Sale vs Rent
-- Find each city and their average sale per customer and avg rent per customer


SELECT
	c.city_name,
	estimated_rent,
	COUNT(DISTINCT(cus.customer_id)) AS total_cus,
	round(SUM(s.total)::Numeric/COUNT(DISTINCT cus.customer_id),2) AS Average_Sale_per_cus,
	ROUND(estimated_rent::numeric/COUNT(DISTINCT cus.customer_id),2) AS avg_rent_per_cus
FROM sales s
JOIN customers cus
ON cus.customer_id = s.customer_id
JOIN city c
ON c.city_id = cus.city_id
GROUP BY 1,2
ORDER BY 1 DESC


-- Q.9
-- Monthly Sales Growth
-- Sales growth rate: Calculate the percentage growth (or decline) in sales over different time periods (monthly)
-- by each city

WITH 
date_table AS (
    SELECT 
        TO_DATE(sale_date, 'yyyy-mm-dd') AS date,
        sale_id,
		total
    FROM sales
),
monthly_sales_growth AS (
    SELECT 
        ci.city_name,
        EXTRACT(MONTH FROM dt.date) AS month,
        EXTRACT(YEAR FROM dt.date) AS year,
        SUM(dt.total) AS total_sale,
        LAG(SUM(dt.total), 1) OVER (
            PARTITION BY ci.city_name 
            ORDER BY EXTRACT(YEAR FROM dt.date), EXTRACT(MONTH FROM dt.date)
        ) AS last_month_sale
    FROM date_table AS dt
    JOIN sales AS s ON dt.sale_id = s.sale_id
    JOIN customers AS c ON c.customer_id = s.customer_id
    JOIN city AS ci ON ci.city_id = c.city_id
    GROUP BY 
        ci.city_name, 
        EXTRACT(YEAR FROM dt.date), 
        EXTRACT(MONTH FROM dt.date)
)
SELECT
    city_name,
    month,
    year,
    total_sale AS cr_month_sale,
    last_month_sale,
    ROUND((total_sale - last_month_sale)::NUMERIC /last_month_sale::numeric * 100, 2) AS growth_ratio
FROM monthly_sales_growth
WHERE last_month_sale IS NOT NULL
ORDER BY city_name, year, month;


-- Q.10
-- Market Potential Analysis
-- Identify top 3 city based on highest sales, return city name, total sale, total rent, total customers, estimated coffee consumer


SELECT 
  city_name,
  SUM(s.total) AS total_revenue,
  COUNT(DISTINCT s.customer_id) AS total_customer,
  estimated_rent AS total_rent,
  ROUND(SUM(s.total)::NUMERIC / COUNT(DISTINCT s.customer_id), 2) AS avg_sale_pr_cx,
  ROUND((population * 0.25) / 1000000, 3) AS estimated_coffee_consumer_in_millions,
  ROUND(estimated_rent::NUMERIC / COUNT(DISTINCT s.customer_id), 2) AS avg_rent_per_cx
 FROM sales AS s
 JOIN customers AS c ON s.customer_id = c.customer_id
 JOIN city AS ci ON ci.city_id = c.city_id
 GROUP BY city_name, estimated_rent, population
 ORDER BY total_revenue DESC





