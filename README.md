# Adventure Works Reseller Sales - Exploratory Data Analysis

# Project Overview
SQL-Based EDA on AdventureWorks DW reseller channel - analysing 60K+ transactions across sales trends, product profitability, reseller performance, and geographic distribution using SQL Server
covering data quality validation, statistical profiling and sales perofrmance analysis  
**Tool**: SQL Server(T-SQL)  
**Dataset**: AdventureWorksDW2025 -FactResellerSales and related dimension tables  
**Source** [Microsoft Learn](https://learn.microsoft.com/en-us/sql/samples/adventureworks-install-configure)  
**EDA SQL File** Attached in files  

## Objective
This project analyzes reseller sales data covering the full dataset period
(December 2010 – November 2013), with a focus on 2013 performance, to identify:
- Which products generate the highest revenue
- Which products are profitable or underperforming
- Sales growth trends over time
- Sales concentration across categories
- Business types and reseller contribution to total sales
- Geographical sales distribution and profitability

# Project Structure
1.Data Inspection - Schema exploration (Tables, Columns and Constraints)  
2.Data Quality Check - Null Checks, Duplicate detection and data logic validation  
3.Data Profiling - Date Range, statistical distribution and outlier detection   
4.Reseller Sales EDA  
  4.1.Sales and Profit Trend - Annual and monthly sales trends, YoY/MoM growth, gross margin analysis  
  4.2.Category and product-level sales, profitability, and margin breakdown  
  4.3.Business type distribution, Pareto reseller analysis, country-level performance  

# Techniques Used
- Window Functions - LAG, ROW_NUMBER, SUM OVER
- Common Table Expressions (CTE) and Subquery 
- Statistical SQL Functions
- JOIN Operations

# Analysis Demonstrated 
- YoY and MoM growth calculations
- Pareto (80/20) analysis
- Profitability analysis
- Product performance evaluation
- Sales contribution analysis across resellers and countries
- Statistical profiling and outlier detection

# Key Business Insights 

### 1.Sales & Profit Trend

**Annual Sales Trend**
- Sales grew consistently from $18M (2011) to $33.5M (2013 YTD NOV), but YoY growth decelerated from +55% to +19%, signaling potential market maturation.
- Average selling price declined from $637 (2011) to $324 (2013) as Volume growth significantly outpaced sales growth (units sold rose from 28.6K in 2011 to 103.7K in 2013) indicating a product mix shift toward lower-priced items.

**Monthly Sales Cycle (2013)**
- Sales followed a recurring quarterly cycle as strong MoM growth at the start of each quarter (Jan +58%, Apr +52%, Jul +62%, Oct +50%) followed by sharp declines at quarter-end (Mar −44%, Jun −53%, Sep −19%), This pattern suggests reseller bulk ordering at quarter open and inventory liquidation at quarter close.
- January was the strongest month ($4.2M, 15K units) while June was the weakest ($1.7M, 4.6K units).

**Profitability**
- Gross profit improved from $29K (2011) to $915K (2012) but then collapsed to −$491.9K in 2013 and gross margin turned negative in 2013 (-1.46%) as total costs ($34M) exceeded total sales ($33.5M). 
- Monthly 2013 data shows Q1 was the most loss-making (Jan −5.95%, Feb −6.87%), driven by high costs and peak discounting. Q2–Q3 margins turned slightly positive margin (0.2% to 0.9%) before deteriorating again in Q4 (-0.4% to -0.8%).

### 2.Product Performance

**Category Sales and Profitability in 2013**
- Bikes dominate sales generating $26.9M and contributing to 80% of total sales However recorded the only negative gross margin (−3.8%) as Total cost ($27M) exceeded total sales, resulting in a $1M gross loss. Discounts represent less than 1% of bike sales pointing to a cost or pricing issue.
- Clothing and Components follow a volume-driven strategy with high units but low sales contribution and generated moderate margins around +6%.
- Accessories showed the strongest growth momentum (+161% sales, +92% volume) from a small base and achieved the highest gross margin at +36% (high-margin products with low production cost) indicating an emerging opportunity.

**Top Products (2013)**
- Mountain-200 led Bikes with $6.6M and a positive gross margin of +8.6% ($569K profit) - the only major bike model generating healthy returns.
- Touring-1000 ($6.3M) and Road-350-W ($3.3M) showed strong sales but negative margins (−6% and −16%), indicating pricing or production cost issues on these specific models.
- Hitch Rack led Accessories at $183K with high margins, followed by Sport-100 Helmets ($118K) - ideal cross-sell targets.
- In Clothing, Women's Mountain Shorts ($243K, +35% margin) and Classic Vests ($205K, ) performed strongly, while Long/Short Sleeve Jerseys combined generated $353K in sales but a −31% margin — a significant loss-maker.

### 3. Resellers & Geography

**Business Type Distribution (2013)**
- All three channels showed double-digit YoY growth — expansion is broad-based, not channel-concentrated.
- Specialty Bike Shops, while the smallest segment, showed the strongest momentum (+35% sales, +52.6% volume), suggesting an emerging high-growth channel.
- Value Added Resellers grew volume by +28% but sales by only +11%, indicating a product mix shift toward lower-priced items within this business type.

**Pareto Analysis — Top Resellers**
- Just 146 out of 489 resellers (29.9%) generate 80% of total sales — a classic Pareto concentration.
- Top 3 resellers: RoadWay Bicycle Supply (France) at $436.9K, followed by Field Trip Store ($427.3K) and Brakes and Gears ($397.2K) — all in the Value Added Reseller category.
- The top 80% segment is composed of Warehouse (76 resellers) and Value Added Reseller (70 resellers), with heavy geographic concentration in the United States (91 resellers) and Canada (21 resellers).

**Geopgraphy Sales Distribution and Profitability (2013)**
- North America (US + Canada) accounts for 72% of sales but both markets are declining in revenue despite volume growth — a clear sign of market saturation and price compression in the core reseller base.
- European markets are transitioning from emerging to growth stage: Germany grew +902% (volume +776%), France +125%, UK +84% — all from small bases but showing strong trajectory.
- Australia is the biggest emerging story: from $50K to $1.5M (+2,999%) with volume growing from 124 to 4.8K units (+3,790%) — the fastest-growing market in the portfolio.
- All countries showed negative gross profitability: highest loss in Australia (−6%), European markets around −3%, while US and Canada are near breakeven — suggesting the cost problem is global, not market-specific.

## Strategic Summary
- **Revenue vs. Profit** - Sales grew 86% over 3 years but the business turned loss-making in 2013. Cost growth exceeded sales.
- **Bikes Problem** - The flagship category drives 80% of revenue but generates a net loss. Mountain-200 is the exception — Touring and Road lines need cost or pricing review.
- **Accessories Opportunity** - Highest margin category (+36%) with the fastest growth (+161%). Strong cross-sell potential alongside Bikes.
- **Channel Momentum** - Specialty Bike Shops are the fastest-growing channel despite being smallest — worth investment to scale.
- **Reseller Concentration** - 30% of resellers drive 80% of revenue — retention and account management of these 146 resellers is critical.
- **Geographic Shift** - Core North American markets are saturating. Europe and Australia are high-growth emerging markets and represent the next expansion frontier.
