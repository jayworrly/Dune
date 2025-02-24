-- already part of a query repo
-- Query ID: 4656653

WITH base_tokens AS (
  SELECT 'AVAX' as Token
  UNION ALL SELECT 'JUICY'
  UNION ALL SELECT 'USDC'
  UNION ALL SELECT 'NOCHILL'
),
avax_transfers AS (
  SELECT "to" AS wallet, SUM(value) / 1e18 AS total_received
  FROM avalanche_c.traces
  WHERE "to" = 0xc926f9EB28Dc04FDe0A8aD865d4709Eb5eA98891 AND success = TRUE
  GROUP BY "to"
), 
avax_spent AS (
  SELECT "from" AS wallet, SUM(value) / 1e18 AS total_sent
  FROM avalanche_c.traces
  WHERE "from" = 0x23BC0B749563936De124f6B02C14A9F3FFE8ABc2 AND success = TRUE
  GROUP BY "from"
), 
juicy_transfers AS (
  SELECT "to" AS wallet, SUM(amount_raw) / 1e18 as total_received
  FROM tokens.transfers
  WHERE "to" = 0x23BC0B749563936De124f6B02C14A9F3FFE8ABc2
    AND contract_address = 0xC654721fBf1F374fd9FfA3385Bba2F4932A6af55
  GROUP BY "to"
), 
juicy_spent AS (
  SELECT "from" AS wallet, SUM(amount_raw) / 1e18 as total_sent
  FROM tokens.transfers
  WHERE "from" = 0x23BC0B749563936De124f6B02C14A9F3FFE8ABc2
    AND contract_address = 0xC654721fBf1F374fd9FfA3385Bba2F4932A6af55
  GROUP BY "from"
),
nochill_transfers AS (
  SELECT "to" AS wallet, SUM(amount_raw) / 1e18 as total_received
  FROM tokens.transfers
  WHERE "to" = 0x23BC0B749563936De124f6B02C14A9F3FFE8ABc2
    AND contract_address = 0xAcFb898Cff266E53278cC0124fC2C7C94C8cB9a5
  GROUP BY "to"
),
nochill_spent AS (
  SELECT "from" AS wallet, SUM(amount_raw) / 1e18 as total_sent
  FROM tokens.transfers
  WHERE "from" = 0x23BC0B749563936De124f6B02C14A9F3FFE8ABc2
    AND contract_address = 0xAcFb898Cff266E53278cC0124fC2C7C94C8cB9a5
  GROUP BY "from"
),
usdc_transfers AS (
  SELECT "to" AS wallet, SUM(amount_raw) / 1e6 as total_received
  FROM tokens.transfers
  WHERE "to" = 0x23BC0B749563936De124f6B02C14A9F3FFE8ABc2
    AND contract_address = 0xA0b86991c6218b36c1d19d4a2e9eb0ce3606eb48
  GROUP BY "to"
), 
usdc_spent AS (
  SELECT "from" AS wallet, SUM(amount_raw) / 1e6 as total_sent
  FROM tokens.transfers
  WHERE "from" = 0x23BC0B749563936De124f6B02C14A9F3FFE8ABc2
    AND contract_address = 0xA0b86991c6218b36c1d19d4a2e9eb0ce3606eb48
  GROUP BY "from"
),
calculated_balances AS (
  SELECT
    'AVAX' as Token,
    COALESCE(at.total_received, 0) - COALESCE(aset.total_sent, 0) AS Balance,
    (SELECT price FROM prices.usd WHERE symbol = 'AVAX' ORDER BY minute DESC LIMIT 1) as Price,
    ROUND((COALESCE(at.total_received, 0) - COALESCE(aset.total_sent, 0)) * 
      (SELECT price FROM prices.usd WHERE symbol = 'AVAX' ORDER BY minute DESC LIMIT 1), 2) AS "USD Value"
  FROM avax_transfers at
  LEFT JOIN avax_spent aset ON at.wallet = aset.wallet
  
  UNION ALL
  
  SELECT
    'JUICY' as Token,
    COALESCE(jt.total_received, 0) - COALESCE(js.total_sent, 0) AS Balance,
    (SELECT price FROM prices.usd WHERE contract_address = 0xC654721fBf1F374fd9FfA3385Bba2F4932A6af55 ORDER BY minute DESC LIMIT 1) as Price,
    ROUND((COALESCE(jt.total_received, 0) - COALESCE(js.total_sent, 0)) * 
      COALESCE((SELECT price FROM prices.usd WHERE contract_address = 0xC654721fBf1F374fd9FfA3385Bba2F4932A6af55 ORDER BY minute DESC LIMIT 1), 0), 2) AS "USD Value"
  FROM juicy_transfers jt
  LEFT JOIN juicy_spent js ON jt.wallet = js.wallet

  UNION ALL

  SELECT
    'NOCHILL' as Token,
    COALESCE(nt.total_received, 0) - COALESCE(ns.total_sent, 0) AS Balance,
    (SELECT price FROM prices.usd WHERE contract_address = 0xAcFb898Cff266E53278cC0124fC2C7C94C8cB9a5 ORDER BY minute DESC LIMIT 1) as Price,
    ROUND((COALESCE(nt.total_received, 0) - COALESCE(ns.total_sent, 0)) * 
      COALESCE((SELECT price FROM prices.usd WHERE contract_address = 0xAcFb898Cff266E53278cC0124fC2C7C94C8cB9a5 ORDER BY minute DESC LIMIT 1), 0), 2) AS "USD Value"
  FROM nochill_transfers nt
  LEFT JOIN nochill_spent ns ON nt.wallet = ns.wallet
  
  UNION ALL
  
  SELECT
    'USDC' as Token,
    COALESCE(ut.total_received, 0) - COALESCE(us.total_sent, 0) AS Balance,
    1 as Price,
    ROUND(COALESCE(ut.total_received, 0) - COALESCE(us.total_sent, 0), 2) AS "USD Value"
  FROM usdc_transfers ut
  LEFT JOIN usdc_spent us ON ut.wallet = us.wallet
)

SELECT
  bt.Token,
  COALESCE(cb.Balance, 0) as Balance,
  COALESCE(cb.Price, CASE WHEN bt.Token = 'USDC' THEN 1 ELSE 0 END) as Price,
  COALESCE(cb."USD Value", 0) as "USD Value"
FROM base_tokens bt
LEFT JOIN calculated_balances cb ON bt.Token = cb.Token
ORDER BY "USD Value" DESC;