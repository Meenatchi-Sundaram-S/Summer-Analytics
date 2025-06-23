USE InventoryDB;
WITH ProductMovement AS (
    SELECT
        ProductID,
        Category,
        SUM(UnitsSold) AS Total_Units_Sold
    FROM inventory_forecasting
    GROUP BY ProductID, Category
),

RankedProducts AS (
    SELECT
        ProductID,
        Category,
        Total_Units_Sold,
        NTILE(3) OVER (ORDER BY Total_Units_Sold DESC) AS MovementTier
    FROM ProductMovement
)

SELECT
    ProductID,
    Category,
    Total_Units_Sold,
    CASE 
        WHEN MovementTier = 1 THEN 'Fast-Moving'
        WHEN MovementTier = 2 THEN 'Medium-Moving'
        ELSE 'Slow-Moving'
    END AS Product_Speed
FROM RankedProducts;
SELECT
    Category,
    ProductID,
    -- Reorder Level
    ROUND(MAX(UnitsSold) * 7, 0) AS Reorder_Level,

    -- Minimum Level
    ROUND((MAX(UnitsSold) * 7) - (AVG(UnitsSold) * 5), 0) AS Minimum_Level,

    -- Maximum Level
    ROUND((MAX(UnitsSold) * 7) + 100 - (MIN(UnitsSold) * 3), 0) AS Maximum_Level,

    -- Average Stock Level
    ROUND(((MAX(UnitsSold) * 7) - (AVG(UnitsSold) * 5)) + (100 / 2.0), 0) AS Average_Stock_Level,

    -- Danger Level
    ROUND(AVG(UnitsSold) * 3, 0) AS Danger_Level

FROM inventory_forecasting
GROUP BY ProductID, Category;
WITH SeasonalDemand AS (
    SELECT
        Seasonality,
        Category,
        ROUND(SUM(UnitsSold) / COUNT(DISTINCT Date), 2) AS Avg_Daily_Seasonal_Usage
    FROM inventory_forecasting
    GROUP BY Seasonality, Category
),

SeasonalInventoryStatus AS (
    SELECT
        f.Seasonality,
        f.Category,
        ROUND(AVG(f.Inventory), 2) AS Avg_Inventory_Level,
        ROUND(d.Avg_Daily_Seasonal_Usage * 7, 2) AS Seasonal_Reorder_Point,
        CASE
            WHEN AVG(f.Inventory) <= d.Avg_Daily_Seasonal_Usage * 7 THEN 'Restock Needed'
            ELSE 'Sufficient Stock'
        END AS Inventory_Status
    FROM inventory_forecasting f
    JOIN SeasonalDemand d 
        ON f.Seasonality = d.Seasonality AND f.Category = d.Category
    GROUP BY f.Seasonality, f.Category, d.Avg_Daily_Seasonal_Usage
)

SELECT *
FROM SeasonalInventoryStatus;

WITH DailyAvgUsage AS (
    SELECT
        ProductID,
        ROUND(AVG(UnitsSold) / 30.0, 2) AS DailyUsage
    FROM inventory_forecasting
    WHERE Date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
    GROUP BY ProductID
)

SELECT
    f.ProductID,
    f.StoreID,
    f.Inventory,
    ROUND(d.DailyUsage * 7, 2) AS ReorderPoint,
    CASE
        WHEN f.Inventory <= (d.DailyUsage * 7) THEN 'Restock Needed'
        ELSE 'Sufficient Stock'
    END AS RestockAlert
FROM inventory_forecasting f
JOIN DailyAvgUsage d ON f.ProductID = d.ProductID;
SELECT
    Category,
    ROUND(AVG(Inventory / NULLIF(UnitsSold, 0)), 2) AS Avg_Inventory_Turnover
FROM inventory_forecasting
GROUP BY Category;
SELECT
    Category,
    ROUND(AVG(ABS(DemandForecast - UnitsSold)), 2) AS AvgForecastError
FROM inventory_forecasting
GROUP BY Category;
SELECT
    Weather,
    SUM(UnitsSold) AS TotalUnitsSold,
    ROUND(AVG(UnitsSold), 2) AS AvgUnitsSold
FROM inventory_forecasting
GROUP BY Weather;
SELECT
    HolidayPromo,
    AVG(UnitsSold) AS AvgSales,
    AVG(Discount) AS AvgDiscount
FROM inventory_forecasting
GROUP BY HolidayPromo;
SELECT
    Category,
    ROUND(AVG(Inventory), 2) AS Average_Inventory_Level
FROM inventory_forecasting
GROUP BY Category;
SELECT
    Category,
    ProductID,
    MAX(Date) AS Last_Sold_Date,
    CURDATE() AS Today,
    DATEDIFF(CURDATE(), MAX(Date)) AS Estimated_Inventory_Age_Days
FROM inventory_forecasting
WHERE UnitsSold > 0
GROUP BY Category, ProductID;