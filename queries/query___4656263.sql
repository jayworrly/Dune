-- already part of a query repo
-- Query ID: 4656263

WITH contract_interactions AS (
  SELECT
    "from" AS user_address,
    value / 1e18 AS avax_value,
    block_time,
    hash AS tx_hash,
    "to" AS contract_address
  FROM avalanche_c.transactions
  WHERE
    success = TRUE
    AND "to" IN (0x11522c62712C4791Db1258B8A8dC96e2E71453C9, 
    0x37fA512CEc716B795A9026F68699F67238e5034e,
    0x1F49ddf43d2590811A44210F89552F314fF07b2e)
), user_activity AS (
  SELECT
    user_address,
    COUNT(DISTINCT tx_hash) AS total_transactions,
    COUNT(DISTINCT DATE_TRUNC('day', block_time)) AS active_days,
    SUM(avax_value) AS total_avax_sent,
    MIN(block_time) AS first_interaction,
    MAX(block_time) AS latest_interaction,
    COUNT(DISTINCT contract_address) AS contracts_interacted
  FROM contract_interactions
  GROUP BY
    user_address
), avax_prices /* Add AVAX price data for USD conversion */ AS (
  SELECT
    DATE_TRUNC('hour', minute) AS hour,
    AVG(price) AS avax_price
  FROM prices.usd
  WHERE
    symbol = 'AVAX'
  GROUP BY
    1
), user_rankings /* Calculate activity scores and rankings */ AS (
  SELECT
    ua.*,
    total_avax_sent * ap.avax_price AS total_usd_value,
    (
      (
        total_transactions * 0.4
      ) + (
        active_days * 0.3
      ) + (
        contracts_interacted * 0.3
      )
    ) /* Create an activity score based on multiple factors */ AS activity_score,
    ROW_NUMBER() OVER (ORDER BY total_transactions DESC) AS tx_rank,
    ROW_NUMBER() OVER (ORDER BY total_avax_sent DESC) AS volume_rank
  FROM user_activity AS ua
  LEFT JOIN avax_prices AS ap
    ON DATE_TRUNC('hour', ua.latest_interaction) = ap.hour
), contract_breakdown /* Add contract-specific breakdown */ AS (
  SELECT
    user_address,
    contract_address,
    COUNT(DISTINCT tx_hash) AS contract_transactions,
    SUM(avax_value) AS contract_avax_sent
  FROM contract_interactions
  GROUP BY
    user_address,
    contract_address
)
SELECT
  ur.user_address,
  ur.total_transactions,
  ur.active_days,
  ROUND(ur.total_avax_sent, 4) AS total_avax_sent,
  ROUND(ur.total_usd_value, 2) AS total_usd_value,
  ur.first_interaction,
  ur.latest_interaction,
  ur.contracts_interacted,
  ROUND(ur.activity_score, 2) AS activity_score,
  ur.tx_rank,
  ur.volume_rank,
  MAX(
    CASE
      WHEN cb.contract_address = 0x11522c62712C4791Db1258B8A8dC96e2E71453C9
      THEN cb.contract_transactions
      ELSE 0
    END
  ) AS contract_1_transactions,
  MAX(
    CASE
      WHEN cb.contract_address = 0x37fA512CEc716B795A9026F68699F67238e5034e
      THEN cb.contract_transactions
      ELSE 0
    END
  ) AS contract_2_transactions
FROM user_rankings AS ur
LEFT JOIN contract_breakdown AS cb
  ON ur.user_address = cb.user_address
WHERE
  ur.tx_rank <= 100 /* Show top 100 most active users */
GROUP BY
  ur.user_address,
  ur.total_transactions,
  ur.active_days,
  ur.total_avax_sent,
  ur.total_usd_value,
  ur.first_interaction,
  ur.latest_interaction,
  ur.contracts_interacted,
  ur.activity_score,
  ur.tx_rank,
  ur.volume_rank
ORDER BY
  ur.activity_score DESC