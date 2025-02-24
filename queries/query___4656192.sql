-- already part of a query repo
-- Query ID: 4656192

WITH platform_activity AS (
   SELECT
       DATE_TRUNC('day', block_time) as date,
       COUNT(*) as daily_transactions,
       SUM(value/1e18) as daily_volume_native
   FROM avalanche_c.transactions
   WHERE "to" IN (
        0x11522c62712C4791Db1258B8A8dC96e2E71453C9,
        0x37fA512CEc716B795A9026F68699F67238e5034e,
        0x1F49ddf43d2590811A44210F89552F314fF07b2e
   )
   GROUP BY 1
),
treasury_inflows AS (
   SELECT
       DATE_TRUNC('day', block_time) as date,
       SUM(value/1e18) as treasury_inflow_avax
   FROM avalanche_c.traces
   WHERE "to" = 0xc926f9EB28Dc04FDe0A8aD865d4709Eb5eA98891
       AND value > 0
   GROUP BY 1
)
SELECT
   t.date,
   t.daily_transactions,
   t.daily_volume_native,
   t.daily_volume_native * p.price as daily_volume_usd,
   COALESCE(i.treasury_inflow_avax, 0) as treasury_inflow_avax,
   COALESCE(i.treasury_inflow_avax * p.price, 0) as treasury_inflow_usd
FROM platform_activity t
LEFT JOIN treasury_inflows i ON t.date = i.date
LEFT JOIN prices.usd p ON p.contract_address = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7
   AND p.minute = DATE_TRUNC('day', t.date)
   AND p.blockchain = 'avalanche_c'
ORDER BY t.date DESC
LIMIT 1000;