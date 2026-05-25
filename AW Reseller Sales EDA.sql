/*====================================
	SECTION 1 : Data Inspection
=====================================*/

--1. Tables
SELECT 
	TABLE_NAME,
	TABLE_TYPE
FROM INFORMATION_SCHEMA.TABLES; 

--2. Columns
SELECT 
	TABLE_NAME, 
	COLUMN_NAME, 
	DATA_TYPE,
	IS_NULLABLE,
	COLUMN_DEFAULT
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'FactResellerSales';

--3. Constraints
SELECT 
	TABLE_NAME,
	COLUMN_NAME,
	CONSTRAINT_NAME
FROM INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE
WHERE TABLE_NAME = 'FactResellerSales';

--4. Overview
SELECT TOP 100 * FROM FactResellerSales;

/*====================================
	SECTION 2 : Data Quality Check
=====================================*/

--1. Nulls and Zeros in key columns
SELECT 
	--Attributes
	SUM(CASE WHEN SalesOrderNumber IS NULL THEN 1 ELSE 0 END) AS Null_SalesOrderNumber,
	SUM(CASE WHEN SalesOrderLineNumber IS NULL THEN 1 ELSE 0 END) AS Null_SalesOrderLineNumber,
	SUM(CASE WHEN ProductKey IS NULL THEN 1 ELSE 0 END) AS Null_ProductKey,
	SUM(CASE WHEN ResellerKey IS NULL THEN 1 ELSE 0 END) AS Null_ResellerKey,
	SUM(CASE WHEN SalesTerritoryKey IS NULL THEN 1 ELSE 0 END) AS Null_TerritoryKey,
	SUM(CASE WHEN PromotionKey IS NULL THEN 1 ELSE 0 END) AS Null_Promotion_Key,
	SUM(CASE WHEN OrderDate IS NULL THEN 1 ELSE 0 END) Null_OrderDate,
	-- Measures
	SUM(CASE WHEN SalesAmount = 0 THEN 1 ELSE 0 END) AS Zero_Sales,
	SUM(CASE WHEN TotalProductCost = 0 THEN  1 ELSE 0 END) AS Zero_Cost,
	SUM(CASE WHEN OrderQuantity = 0 THEN 1 ELSE 0 END) AS Zero_Quantity
FROM FactResellerSales;
-- No Nulls and Zeros 

--2. Duplicates 
SELECT *
FROM(
	SELECT
		*,
		ROW_NUMBER() OVER(PARTITION BY SalesOrderLineNumber , SalesOrderNumber ORDER BY OrderDate) AS rn
	FROM FactResellerSales)t
WHERE rn > 1;
--No Duplicates

--3. Data Consistency 
--3.a. OrderDate should be before ShipDate and ShipDate before DueDate
SELECT 
	OrderDate,
	ShipDate,
	DueDate
FROM FactResellerSales
WHERE OrderDate > ShipDate 
	OR ShipDate > DueDate;
-- Date is consistent

--3.b.SalesAmount should equal (UnitPrice * OrderQuantity) - DiscountAmount
SELECT 
	SUM(SalesAmount) AS Total_Sales,
	SUM(UnitPrice * OrderQuantity - DiscountAmount)  AS Total_Sales_Check,
	SUM(SalesAmount) - SUM(UnitPrice * OrderQuantity - DiscountAmount)  AS Diff
FROM FactResellerSales;
-- Data validated , the diff is ~0.04 across 80M (Minor floating point rounding)

/*====================================
	SECTION 3 : Data Profiling
=====================================*/

--1. OrderDate Range
SELECT 
	MIN(OrderDate) AS Earliest_Date,
	MAX(OrderDate) AS Latest_Date,
	DATEDIFF(Year,MIN(OrderDate),MAX(OrderDate)) AS Year_Range
FROM FactResellerSales;
-- Date Range from 29-12-2010 to 29-11-2013 , 3 Years

--2. Data Summary
SELECT 
	COUNT(*) AS Total_Rows,
	COUNT(DISTINCT SalesOrderLineNumber) AS OrderLine_Count,
	COUNT(DISTINCT SalesOrderNumber) AS Orders_Count,
	COUNT(DISTINCT ProductKey) AS Products_Count,
	COUNT(DISTINCT ResellerKey) AS Resellers_Count
FROM FactResellerSales;

--3. Statistical Summary of SalesAmount (Sales Data Distribution)
WITH Statistical_Metrics AS (
SELECT 
	MIN(SalesAmount) AS Min,
	MAX(SalesAmount) AS Max,
	MAX(SalesAmount) - MIN(SalesAmount) AS Range,
	AVG(SalesAmount) AS Mean,
	VAR(SalesAmount) AS Var,
	STDEV(SalesAmount) AS Std_Dev
FROM FactResellerSales 
), Median AS (
	SELECT DISTINCT
		PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY SalesAmount) OVER() AS Median 
	FROM FactResellerSales)
SELECT 
	s.Min,
	s.Max,
	s.Range,
	s.Mean,
	m.Median,
	s.Var,
	s.Std_Dev
FROM Statistical_Metrics s
CROSS JOIN Median m;
/*
- Right Skewed distribution as mean (1322) is much higher than median (462)	
	reflecting that most transactions are relatively small in value and limited number of large value transactions increase the overall average
-- High variability in sales as standard deviation (2124) is larger than mean and confirm that is not normally distributed
-- Range 27892.245 ( min 1.37 and max 27893.619) sales scattered across enormous range
*/

--4. Outlier Detection
WITH Quartiles AS (
    SELECT
        SalesAmount,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY SalesAmount) OVER() AS Q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY SalesAmount) OVER() AS Q3
    FROM FactResellerSales
), IQR_Calc AS (
    SELECT
        SalesAmount,
        Q1,
		Q3,
        Q3 - Q1 AS IQR
    FROM Quartiles)
SELECT 
    COUNT(*) AS Total_Rows,
    COUNT(CASE WHEN SalesAmount <  (Q1 - 1.5 * IQR) OR SalesAmount >  (Q3 + 1.5 * IQR) THEN 1 END) AS Outlier_Count,
    COUNT(CASE WHEN SalesAmount >= (Q1 - 1.5 * IQR)  AND SalesAmount <= (Q3 + 1.5 * IQR) THEN 1 END) AS Clean_Count,
    ROUND(100.0 * COUNT(CASE WHEN SalesAmount <  (Q1 - 1.5 * IQR) OR SalesAmount >  (Q3 + 1.5 * IQR) THEN 1 END) / COUNT(*), 2) AS Outlier_Pct,
    ROUND(AVG(SalesAmount), 2) AS Mean_With_Outliers,
    ROUND(AVG(CASE WHEN SalesAmount >= (Q1 - 1.5*IQR) AND SalesAmount <= (Q3 + 1.5*IQR) THEN SalesAmount END), 2) AS Mean_Without_Outliers,
    ROUND(MIN(Q1 - 1.5*IQR), 2) AS Lower_Fence,
    ROUND(MAX(Q3 + 1.5*IQR), 2) AS Upper_Fence,
    ROUND(MIN(Q1), 2) AS Q1,
    ROUND(MAX(Q3), 2) AS Q3
FROM IQR_Calc;

/*
- Outlier pct 10.9% (6626 out of 60855 rows) nearly 1 out of 9 is statisitical outlier 
	as 6626 exceeded the upper fence (3473) and lower fence is negative so no low end outliers exist 
	reflecting real large order not data errors
- outliers distorting the mean as mean without outliers drop from 1322 to 720
*/

/*====================================
	SECTION 4 : Retail Sales EDA
=====================================*/

/*--------------------------------------------
	4.1. Sales and Profit Trend over time
---------------------------------------------*/

--1. Anuual Sales and Volume trend with YoY Growth
WITH Sales_Metrics AS (
	SELECT
		YEAR(OrderDate) AS Calendar_Year,
		ROUND(SUM(SalesAmount),1) AS Total_Sales,
		SUM(OrderQuantity) AS Total_Quantity
	FROM FactResellerSales
	GROUP BY YEAR(OrderDate)
), Prev_Metrics AS (
	SELECT
		*,
		LAG(Total_Sales,1) OVER(ORDER BY Calendar_Year) AS PY_Sales,
		LAG(Total_Quantity,1) OVER(ORDER BY Calendar_Year) AS PY_Quantity
	FROM Sales_Metrics )
SELECT 
	Calendar_Year,
	Total_Sales,
	ROUND((Total_Sales - PY_Sales) * 100.0 / NULLIF(PY_Sales,0),1) AS YoY_Sales_Growth,
	Total_Quantity,
	ROUND((Total_Quantity - PY_Quantity) * 100.0 / NULLIF(PY_Quantity,0),1) AS YoY_Quantity_Growth,
	ROUND(Total_Sales /Total_Quantity,1) AS Average_Selling_Price
FROM Prev_Metrics;

/*
Findings:
- Reseller sales grew consistently over the years increasing from $18M in 2011 reaching $33.5M in 2013 indicating strong business expansion
- However sales continued to grow, YoY Growth decelrated from +55% in 2012 to +19% in 2013 suggesting potential market maturation or slowing expansion momentum 
- Sales Volume supported sales growth as total qunatity sold increased from 28.6K to 103.7K units in 2013 reflecting strong demand growth
- Volume growth exceed Sales Growth implying decline in average selling price from $636.7 to $323.9
- YoY growth in 2011 is invalid as 2010 is partial year (1 Month only) as 2011 acting as baseline
*/

--2. Monthly Sales and Volume trend in 2013 with MoM Growth
WITH Sales_Metrics AS (
	SELECT
		YEAR(OrderDate) AS Calendar_Year,
		MONTH(OrderDate) AS Calendar_Month,
		ROUND(SUM(SalesAmount),1) AS Total_Sales,
		SUM(OrderQuantity) AS Total_Quantity
	FROM FactResellerSales
	GROUP BY YEAR(OrderDate) , Month(OrderDate)
), Prev_Sales AS (
	SELECT
		*,
		SUM(Total_Sales) OVER (PARTITION BY Calendar_Year ORDER BY Calendar_Month) AS Cumulative_Sales,
		LAG(Total_Sales,1) OVER(ORDER BY Calendar_Year, Calendar_Month) AS PY_Sales
	FROM Sales_Metrics )
SELECT 
	Calendar_Month,
	Total_Sales,
	ROUND((Total_Sales - PY_Sales) * 100.0 / NULLIF(PY_Sales,0),1) AS MoM_Sales_Growth,
	Cumulative_Sales,
	Total_Quantity
FROM Prev_Sales
WHERE Calendar_Year = 2013;

/*
Findings:
- cumulative sales increase throught 2013 (Jan-Nov) as growing from $4.2M in Jan to $33.6M by Nov
- sales exhibited a recurring cycle pattern where the start of each qaurter showed a strong MoM sales growth 
	that appeared in Jan (+58%) , April (+52%) , July (+62%) , Oct (+50%)  reflected on increased volume in these months
	followed by stablization in  or sharp decline in growth at the end of quarter that showed in March (-43.6%) , June (-52.6%) and Sep (-19%) 
	with decreased total quanity sold suggesting stocking liquidation by Reseller 
- July recorded the highest MoM growth +62% while March recorded the lowest MoM Growth -43.6%
- Jan recorded $4.2M as the highest month by sales and volume (15K units) while June was the lowest month by sales at $1.7M and volume (4.6K units)
*/

--3. Annual Profit Trend
SELECT 
	Year(OrderDate) AS Calendar_Year,
	ROUND(SUM(SalesAmount),1) AS Total_Sales,
	ROUND(SUM(DiscountAmount),1) AS Total_Discount,
	ROUND(SUM(TotalProductCost),1) AS Total_Cost,
	ROUND(SUM(SalesAmount - TotalProductCost),2) AS Gross_Profit,
	ROUND(SUM(SalesAmount - TotalProductCost) * 100.0
		/ NULLIF(SUM(SalesAmount),0),1) AS Gross_Margin_Pct
FROM FactResellerSales
GROUP BY YEAR(OrderDate)
ORDER BY Calendar_Year;

/*
Findings:
- Gross Profit improved from $29K in 2011 to $915K in 2012 but deteriorated significally in 2013 to reach -$491.9K 
	and that was reflected on gross margin pct increasing from 0.16% in 2011 to 3.25% in 2012 then declining to -1.46% in 2013
	as result of total cost ($34M) exceeded total sales ($33.5M) highliting cost pressure issues
-  Total Cost increased consistently each year starting from $18M in 2011 till it reached $34M which representig 1.9x growth
	and exceeded the sales growth by 1.9x growth
- Discounts increased the struggle as it increased from ($103K) in 2012 to ($265K) which exceed sales growth by more than 8x
*/

--4. Monthly Profit Trend in 2013
SELECT 
	MONTH(OrderDate) AS Calendar_Month,
	ROUND(SUM(SalesAmount),1) AS Total_Sales,
	ROUND(SUM(DiscountAmount),1) AS Total_Discount,
	ROUND(SUM(TotalProductCost),1) AS Total_Cost,
	ROUND(SUM(SalesAmount - TotalProductCost),1) AS Gross_Profit,
	ROUND(SUM(SalesAmount - TotalProductCost) * 100.0
		/ NULLIF(SUM(SalesAmount),0),1) AS Gross_Margin_Pct
FROM FactResellerSales
WHERE YEAR(OrderDate) = 2013
GROUP BY MONTH(OrderDate)
ORDER BY Calendar_Month;

/*
Findings:
- Gross Margin performance remained weak throughout 2013 with profitability fluctuating around break-even levels for most months
- Q1 recorded negative gross margins with Jan (-5.95%) and Feb (-6.87%) due to high costs ($4.5M and $4.3M respectively) and discounts ($93.6K and $105.9K respectively)
- Profitability slighlty improved in Q2 and Q3 as gross margins turned positive however margin remained extremely thin ranging from 0.2% and 0.9%
- Q4 gross margin deteriorated in Oct (-0.8%) and Nov (-0.4%) indicating profitability pressure at year end
- Total costs throught 2013 remained very close or exceeded total sales resulting in compressed margins
*/

/*-------------------------------
	4.2. Product Performance
--------------------------------*/

--1. Sales and volume distribution acorss Product Category in 2013
WITH Category_Metrics AS (
	SELECT
		YEAR(r.OrderDate) AS Calendar_Year,
		c.EnglishProductCategoryName AS Category,
		ROUND(SUM(r.SalesAmount),1) AS CY_Sales,
		SUM(OrderQuantity) AS CY_Quantity
	FROM FactResellerSales r
	LEFT JOIN DimProduct p ON r.ProductKey = p.ProductKey
	LEFT JOIN DimProductSubcategory s ON  p.ProductSubcategoryKey = s.ProductSubcategoryKey
	LEFT JOIN DimProductCategory c ON s.ProductCategoryKey = c.ProductCategoryKey
	GROUP BY c.EnglishProductCategoryName, Year(r.OrderDate)
), Prev_Sales AS ( 
	SELECT
		*,
		LAG(CY_Sales,1) OVER (PARTITION BY Category ORDER BY Calendar_Year) AS PY_Sales,
		LAG(CY_Quantity,1) OVER (PARTITION BY Category ORDER BY Calendar_Year) AS PY_Quantity
	FROM Category_Metrics)
SELECT 
	Category,
	CY_Sales,
	ROUND(CY_Sales * 100.0 / NULLIF(SUM(CY_Sales) OVER(),0),2) AS Sales_Share_Pct,
	PY_Sales,
	ROUND((CY_Sales - PY_Sales) * 100.0 / NULLIF(PY_Sales,0),2) AS YoY_Sales_Growth,
	CY_Quantity,
	PY_Quantity,
	ROUND((CY_Quantity - PY_Quantity) * 100.0 / NULLIF(PY_Quantity,0),2) AS YoY_Quantity_Growth
FROM Prev_Sales
WHERE Calendar_Year = 2013
ORDER BY CY_Sales DESC;

/*
Findings:
- Bikes dominated sales in 2013 generating $26.9M and contributing to 80% of total sales with YoY sales growth +19.5% and Volume of 31.6K units with YoY quantity growth +13%
- Componnets ranked 2nd in sales by reaching $537K contributing to 16% of total sales with YoY sales growth +13% and YoY quantity growth 26% reahing 24.3K units sold
- Clothes recorded the highest sales volume with 32.3K units despite low sales contribution 2.6% of total sales and it showed volume growth by +26.2%
- Accesories showed the strongest growth performance across all categories with YoY Sales Growth of +161% reaching $378.0K and YoY Quantity Growth 92% with 15.3K units
- Clothes and Components appear to follow volume driven strategy while bikes operate as sales backbone of the business
*/

--2.Category Profitability in 2013 
SELECT
	c.EnglishProductCategoryName AS Category,
	ROUND(SUM(r.SalesAmount),1) AS Total_Sales,
	ROUND(SUM(DiscountAmount),1) AS Total_Discount,
	ROUND(SUM(TotalProductCost),1) AS Total_Cost,
	ROUND(SUM(r.SalesAmount - r.TotalProductCost),1) AS Gross_Profit,
	ROUND(SUM(r.SalesAmount - r.TotalProductCost) * 100.0
		/ NULLIF(SUM(r.SalesAmount),0),1) AS Gross_Margin_Pct
FROM FactResellerSales r
LEFT JOIN DimProduct p ON r.ProductKey = p.ProductKey
LEFT JOIN DimProductSubcategory s ON  p.ProductSubcategoryKey = s.ProductSubcategoryKey
LEFT JOIN DimProductCategory c ON s.ProductCategoryKey = c.ProductCategoryKey
WHERE YEAR(OrderDate) = 2013
GROUP BY c.EnglishProductCategoryName
ORDER BY Gross_Margin_Pct DESC;

/*
Findings:
- Accesories achieved the highest profitability across all categories with gross margin 36% reflects high margin products and low cost
- Bikes recorded the only negative gross margin with -3.8% despite being the highest contributor to sales. total cost $27M exceeded the total sales
	resulting profit loss of $1M and it appears to be cost driven loss rather than discount driven as disocunt represent less than 1% of sales
	reflecting pricing or production cost issues 
- Clothes and Components generate moderate profitability with margins around 6%
- Accesories drive margin while Bikes drive sales 
*/

--3. Top products contributing to sales and Profitability
SELECT 
	*,
	ROW_NUMBER() OVER (Partition By Category ORDER BY Total_Sales DESC) AS rn
FROM (
	SELECT 
	c.EnglishProductCategoryName AS Category,
	s.EnglishProductSubcategoryName AS Subcategory,
	P.ModelName,
	ROUND(SUM(r.SalesAmount),1) AS Total_Sales,
	ROUND(SUM(r.SalesAmount - r.TotalProductCost),1) AS Gross_Profit,
	ROUND(SUM(r.SalesAmount - r.TotalProductCost) * 100.0
		/ NULLIF(SUM(r.SalesAmount),0),1) AS Gross_Margin_Pct
	FROM FactResellerSales r
	LEFT JOIN DimProduct p ON r.ProductKey = p.ProductKey
	LEFT JOIN DimProductSubcategory s ON  p.ProductSubcategoryKey = s.ProductSubcategoryKey
	LEFT JOIN DimProductCategory c ON s.ProductCategoryKey = c.ProductCategoryKey	
	WHERE YEAR(OrderDate) = 2013
	GROUP BY c.EnglishProductCategoryName, s.EnglishProductSubcategoryName, p.ModelName)t ;


/*
- Bikes Sales led by Mountain-200 with $6.6M and showed psoitive gross margin 8.6% generating $569K profit
	Followed by Touring-1000 with $6.3M amd Road-350-W with $3.3M However Touring and Road bikes recorded negative gross margin around -6% and -16% respectively
- Components showed the broadest product portfolio (40 out of 63 sold in 2013) containg Frames and smaller parts
	HL Mountain Frames led the sales reaching $125K with margin 8.7% followed by HL Touring Frame with $122K and HL Road Frame with $54K however touring and road frames showed margins near 0-1%
	small components part achieve moderate sales led by the highest sales HL Crankset ($36K) and had stable margins around 26% 
- Accesories was the most profitable category overall with high margins around 36% and Hitch Rack led the sales by $183k followed by Helmets sport-100 Helmets with $118K and hydration pack $60K
- Clothing showed mixed margins as products such as Women's Mountain Shorts , Classic Vests, Racing Socks and Gloves achieved strong margins around 35% leading sales by Women's Mountain shorts $243K 
	followed by vests 205k and gloves $47K 
	while products as jerseys (Long and short sleeve) combined generated relatively high sales ($353K) but serve negative margins -31% also caps regarfdless genrating lowest sales ($13K) has -32% margin
- Mountain Bikes and Components has Positive margins and leading sales while Touring and Road has high sales but poor profitability need cost or pricing adjusments 
	Acccesories added to cross-selling as has highest profitbailiy besides to smaller part components 
*/

/*-------------------------------------------------
	4.3. Reseller and Country Sales Performance
--------------------------------------------------*/

--1. Sales Distribution Across Business Types and YoY Growth in 2013
With Current_Sales AS ( 
	SELECT 
		r.BusinessType,
		YEAR(OrderDate) AS Calendar_Year,
		ROUND(SUM(SalesAmount),1) AS CY_Sales,
		SUM(OrderQuantity) AS CY_Quantity
	FROM FactResellerSales s
	LEFT JOIN DimReseller r ON s.ResellerKey = r.ResellerKey
	GROUP BY r.BusinessType, Year(OrderDate)
), Prev_Sales AS ( 
	SELECT
		*,
		LAG(CY_Sales,1) OVER (PARTITION BY BusinessType ORDER BY Calendar_Year) AS PY_Sales,
		LAG(CY_Quantity,1) OVER (PARTITION BY BusinessType ORDER BY Calendar_Year) AS PY_Quantity
	FROM Current_Sales)
SELECT 
	BusinessType,
	CY_Sales,
	ROUND(CY_Sales * 100.0 / NULLIF(SUM(CY_Sales) OVER(),0),2) AS Sales_Share_Pct,
	PY_Sales,
	ROUND((CY_Sales - PY_Sales) * 100.0 / NULLIF(PY_Sales,0),2) AS YoY_Sales_Growth,
	CY_Quantity,
	PY_Quantity,
	ROUND((CY_Quantity - PY_Quantity) * 100.0 / NULLIF(PY_Quantity,0),2) AS YoY_Quantity_Growth
FROM Prev_Sales
WHERE Calendar_Year = 2013
ORDER BY CY_Sales DESC;

/*
Findings:
- Warehouse business dominated sales in 2013 at $16.4M (48.9% Sales Share) followed by Valued Added Reseller at $14.4M (43%) and Speciality bike Shops comes last at $2.7M (8% Sales Share)
- All three business showed double digit YoY Growth in Sales and Quantity confirming broad channel expansion not driven by single business type
- Speciality Bike Shop showed the strongest growth momemntum with sales increasing by +35% from $2M t0 $2.7M supported by highest YoY volume growth by +52.6% from 7.5K to 11.5K units
	despite being small segment suggesting strong emerging momentum in specilaity retail
- Value Added Reseller YoY Sales Growth 11% despite major growth in volume growth 28% suggesting product mix shift toward lower price items 
- Warehouse showed showed YoY sales growth 24.7% that closely alligned with volume growth 22.7% 
*/

--2. Top Reseller contributing to 80% sales in 2013
WITH Reseller_Sales AS (
	SELECT 
		r.BusinessType,
		r.ResellerName,
		t.SalesTerritoryCountry AS Country,
		ROUND(SUM(SalesAmount),2) AS Total_Sales
	FROM FactResellerSales s
	LEFT JOIN DimReseller r ON s.ResellerKey = r.ResellerKey
	  LEFT JOIN DimSalesTerritory t ON s.SalesTerritoryKey = t.SalesTerritoryKey
	WHERE YEAR(s.OrderDate) = 2013
	GROUP BY r.BusinessType, 
			 r.ResellerName,
			 t.SalesTerritoryCountry
),Cumulative AS ( 
	SELECT 
		*,
		ROUND(SUM(Total_Sales) OVER(ORDER BY Total_Sales DESC),2) AS Cumulative_Sales,
		ROUND(SUM(Total_Sales) OVER(),2) AS Grand_Total,
		ROW_NUMBER() OVER (Partition By BusinessType ORDER BY Total_Sales DESC) AS Resellers_rank,
		ROW_NUMBER() OVER (Partition By Country ORDER BY Total_Sales DESC) AS Country_rank
	FROM Reseller_Sales )
SELECT 
	BusinessType,
	ResellerName,
	Resellers_rank,
	Country,
	Country_rank,
	Total_Sales,
	Cumulative_Sales,
	ROUND(Cumulative_Sales * 100.0 / NULLIF(Grand_Total,0) ,2) AS Cumulative_Pct,
	CASE 
		WHEN Cumulative_Sales * 100.0 / NULLIF(Grand_Total,0) <= 80.0
		THEN 'Top 80% Sales'
		ELSE '20% Sales'
	END AS Pareto_Flag
FROM Cumulative
ORDER BY Total_Sales DESC;

/*
Findings:
- 146 out of 489 resellers (29.9% of resellers base) are contributing to 80% of Sales ranging between $437K to $106k within the top 80% Sales segment
- RoadWay Bicycle Supply ranked first with total sales of $436.9K in France followed by Field Trip Store ($427.3K) and Brakes and Gears ($397.2K) in United States
	all top three belong to Value Added Reseller Business type
- Top 80% Sales Segment was composed of Warehouse (76 Resllers) and Value Added Reseller (70 Resllers) Business types
- The resellers in top 80% segment was concentrated into United States (91 Resellers) and Canada (21 Resellers) 
	followed by United Kingdom and France (10 Resellers), Germany (8 Resellers) and Australia (6 Resellers)
*/

--3. Sales and Profit distribution across countries in 2013
With Current_Sales AS ( 
	SELECT 
		t.SalesTerritoryCountry AS Country,
		YEAR(s.OrderDate) AS Calendar_Year,
		COUNT(DISTINCT r.ResellerKey) AS Resellers_Count,
		ROUND(SUM(s.SalesAmount),2) AS CY_Sales,
		SUM(s.OrderQuantity) AS CY_Quantity,
		ROUND(SUM(s.SalesAmount - s.TotalProductCost),2) AS Gross_Profit,
		ROUND(SUM(s.SalesAmount - s.TotalProductCost) * 100.0
			/ NULLIF(SUM(s.SalesAmount),0),2) AS Gross_Margin_Pct
	FROM FactResellerSales s
	LEFT JOIN DimSalesTerritory t ON s.SalesTerritoryKey = t.SalesTerritoryKey
	LEFT JOIN DimReseller r ON s.ResellerKey = r.ResellerKey
	GROUP BY t.SalesTerritoryCountry, Year(OrderDate)
), Prev_Sales AS ( 
	SELECT
		*,
		LAG(CY_Sales,1) OVER (PARTITION BY Country ORDER BY Calendar_Year) AS PY_Sales,
		LAG(CY_Quantity,1) OVER (PARTITION BY Country ORDER BY Calendar_Year) AS PY_Quantity
	FROM Current_Sales)
SELECT 
	Country,
	Resellers_Count,
	CY_Sales,
	ROUND(CY_Sales * 100.0 / NULLIF(SUM(CY_Sales) OVER(),0),2) AS Sales_Share_Pct,
	PY_Sales,
	ROUND((CY_Sales - PY_Sales) * 100.0 / NULLIF(PY_Sales,0),2) AS YoY_Sales_Growth,
	CY_Quantity,
	PY_Quantity,
	ROUND((CY_Quantity - PY_Quantity) * 100.0 / NULLIF(PY_Quantity,0),2) AS YoY_Qauntity_Growth,
	Gross_Profit,
	Gross_Margin_Pct
FROM Prev_Sales
WHERE Calendar_Year = 2013
ORDER BY CY_Sales DESC;

/*
Findings:
- United States dominated sales in 2013 generating $19.2M (57% Sales Share) supported by the largest quantity sold (56K units) and largest number of resellers (278 resellers) 
- Canada ranked second with $5M in sales in 2013 (15.4% Sales Share) with quantity sold (18K units) and 78 resellers 
	both United States and Canada reflecting 72% of sales share confirming heavy sales concentration in North America
- Despite quantity growth in US by +2.7% and Canada +7.8% , Uinted States and Canada decilned in sales  (-2% and -5% respectively) suggesting maturity and saturation in core reseller base
- European markets showed strong YoY Growth as Germany +902% , France +125% , UK +84%  aligned with volume growth in France +118% and United Kingdom +83%
	and huge growth in Germancy +776% coming from small base 456 to reach 6.6K units suggesting these markets transitioning from emerging to growth stage despite low share pct but promising
- Australia showed massive YoY Growth +2999% coming from small base $50K reached to $1.5M contributing to smallest sales share pct (4.6%) 
	supported with huge quantity sold growth from 124 to 4.8K units (+3790%)
- All Countries showed negative profitability with highest loss in Australia (-6%) , Euoprean Market ~ -3% while US and Canada near zero 
*/