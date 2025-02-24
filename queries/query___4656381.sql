-- already part of a query repo
-- Query ID: 4656381

WITH base_interactions AS (
    SELECT 
        "from" as user_address,
        block_time,
        hash as tx_hash,
        "to" as contract_address
    FROM avalanche_c.transactions
    WHERE success = true 
    AND "to" IN (
        0x11522c62712C4791Db1258B8A8dC96e2E71453C9,
        0x37fA512CEc716B795A9026F68699F67238e5034e,
        0x1F49ddf43d2590811A44210F89552F314fF07b2e
    )
),
first_interactions AS (
    SELECT 
        user_address,
        MIN(DATE_TRUNC('day', block_time)) as first_interaction_date
    FROM base_interactions
    GROUP BY user_address
),
wallet_ids AS (
    SELECT 
        user_address,
        CONCAT('Wallet_', CAST(ROW_NUMBER() OVER (ORDER BY MIN(block_time)) AS VARCHAR)) as wallet_id,
        COUNT(*) as total_interactions
    FROM base_interactions
    GROUP BY user_address
),
-- Monthly cohorts with simpler month calculation
user_cohorts AS (
    SELECT 
        w.wallet_id,
        w.user_address,
        DATE_TRUNC('month', f.first_interaction_date) as cohort_month,
        DATE_TRUNC('month', b.block_time) as activity_month,
        COUNT(DISTINCT DATE_TRUNC('day', b.block_time)) as days_active_in_month,
        COUNT(DISTINCT b.tx_hash) as transactions_in_month,
        (EXTRACT(year FROM DATE_TRUNC('month', b.block_time)) - 
         EXTRACT(year FROM DATE_TRUNC('month', f.first_interaction_date))) * 12 +
        (EXTRACT(month FROM DATE_TRUNC('month', b.block_time)) - 
         EXTRACT(month FROM DATE_TRUNC('month', f.first_interaction_date))) as months_since_join
    FROM wallet_ids w
    JOIN first_interactions f ON w.user_address = f.user_address
    LEFT JOIN base_interactions b ON w.user_address = b.user_address
    GROUP BY 1, 2, 3, 4
),
-- Filter for only 4 months of data
filtered_cohort_activity AS (
    SELECT *
    FROM user_cohorts
    WHERE months_since_join BETWEEN 0 AND 3
),
-- Monthly retention summary
monthly_retention AS (
    SELECT 
        cohort_month,
        months_since_join,
        COUNT(DISTINCT wallet_id) as active_users,
        AVG(days_active_in_month) as avg_active_days,
        AVG(transactions_in_month) as avg_transactions,
        array_join(array_agg(CONCAT(wallet_id, ' (', CAST(transactions_in_month AS VARCHAR), ' txns)')), ', ') as active_wallets
    FROM filtered_cohort_activity
    GROUP BY 1, 2
),
daily_users AS (
    SELECT 
        DATE_TRUNC('day', b.block_time) as day,
        b.user_address,
        w.wallet_id,
        w.total_interactions,
        CASE 
            WHEN DATE_TRUNC('day', b.block_time) = f.first_interaction_date THEN 'New'
            ELSE 'Returning'
        END as user_type
    FROM base_interactions b
    JOIN first_interactions f ON b.user_address = f.user_address
    JOIN wallet_ids w ON b.user_address = w.user_address
    GROUP BY 1, 2, 3, 4, 5
),
daily_summary AS (
    SELECT 
        day,
        COUNT(DISTINCT CASE WHEN user_type = 'New' THEN wallet_id END) as new_users,
        COUNT(DISTINCT CASE WHEN user_type = 'Returning' THEN wallet_id END) as returning_users,
        COUNT(DISTINCT wallet_id) as total_users,
        array_join(array_agg(
            CASE WHEN user_type = 'New' 
            THEN CONCAT(wallet_id, ' (', CAST(total_interactions AS VARCHAR), ' txns)')
            END), ', ') as new_wallet_ids,
        array_join(array_agg(
            CASE WHEN user_type = 'Returning' 
            THEN CONCAT(wallet_id, ' (', CAST(total_interactions AS VARCHAR), ' txns)')
            END), ', ') as returning_wallet_ids
    FROM daily_users
    GROUP BY 1
),
cumulative_metrics AS (
    SELECT 
        d.*,
        SUM(new_users) OVER (ORDER BY day) as cumulative_users
    FROM daily_summary d
)
-- Final combined output
SELECT 
    -- Daily metrics
    cm.day,
    cm.new_users,
    cm.returning_users,
    cm.total_users,
    ROUND(CAST(cm.returning_users AS double) / NULLIF(cm.total_users, 0) * 100, 2) as returning_user_percentage,
    cm.cumulative_users,
    -- Cohort metrics
    mr.cohort_month,
    mr.months_since_join,
    mr.active_users as cohort_active_users,
    ROUND(mr.avg_active_days, 1) as avg_days_active,
    ROUND(mr.avg_transactions, 1) as avg_transactions,
    mr.active_wallets
FROM cumulative_metrics cm
LEFT JOIN monthly_retention mr ON DATE_TRUNC('month', cm.day) = mr.cohort_month
ORDER BY cm.day DESC, mr.months_since_join;