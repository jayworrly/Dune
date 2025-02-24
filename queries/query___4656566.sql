-- already part of a query repo
-- Query ID: 4656566

WITH contract_interactions AS (
    SELECT 
        value/1e18 as avax_value  
    FROM avalanche_c.traces
    WHERE success = TRUE 
    AND call_type = 'call'
    AND "to" IN (
        0x11522c62712C4791Db1258B8A8dC96e2E71453C9,
        0x37fA512CEc716B795A9026F68699F67238e5034e,
        0x1F49ddf43d2590811A44210F89552F314fF07b2e
    )
),

avax_prices AS (
    SELECT 
        price as avax_price
    FROM prices.usd
    WHERE symbol = 'AVAX'
    ORDER BY minute DESC
    LIMIT 1
),

total_revenue AS (
    SELECT 
        SUM(ci.avax_value) as total_avax,
        ROUND(SUM(ci.avax_value * ap.avax_price), 2) as total_usd
    FROM contract_interactions ci
    CROSS JOIN avax_prices ap
)

SELECT 
    total_usd as "Total Revenue"
FROM total_revenue;