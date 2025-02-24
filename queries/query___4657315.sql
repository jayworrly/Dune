-- already part of a query repo
-- Query ID: 4657315

WITH creator_payments AS (
    SELECT 
        "to" AS creator_wallet, 
        SUM(value) / 1e18 AS total_received_avax
    FROM avalanche_c.traces
    WHERE success = TRUE
    AND call_type = 'call'  -- Contract-based payments
    AND "from" IN (
        0x11522c62712C4791Db1258B8A8dC96e2E71453C9,
        0x37fA512CEc716B795A9026F68699F67238e5034e,
        0x1F49ddf43d2590811A44210F89552F314fF07b2e
    )
    GROUP BY "to"
),

avax_prices AS (
    SELECT 
        price AS avax_price
    FROM prices.usd
    WHERE symbol = 'AVAX'
    ORDER BY minute DESC
    LIMIT 1
),

filtered_payments AS (
    SELECT 
        cp.creator_wallet, 
        cp.total_received_avax
    FROM creator_payments cp
    WHERE cp.creator_wallet <> 0x23bc0b749563936De124f6B02C14A9F3FFE8ABc2  -- Exclude top wallet
)

SELECT 
    ROUND(SUM(fp.total_received_avax), 2) AS "Total AVAX (Excluding Top Wallet)",
    ROUND(SUM(fp.total_received_avax * ap.avax_price), 2) AS "Total USD Value (Excluding Top Wallet)"
FROM filtered_payments fp
CROSS JOIN avax_prices ap;
