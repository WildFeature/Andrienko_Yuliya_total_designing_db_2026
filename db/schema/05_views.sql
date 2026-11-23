-- 05_views.sql
SET search_path TO andrienko_food, exts;

CREATE OR REPLACE VIEW how_much_money AS
WITH RECURSIVE months AS (
    SELECT date_trunc('month', min(order_timestamp))::date AS m
    FROM "order"
    WHERE status = 'доставлен'
    UNION ALL
    SELECT (m + interval '1 month')::date
    FROM months
    WHERE m < (
        SELECT date_trunc('month', max(order_timestamp))::date
        FROM "order"
        WHERE status = 'доставлен'
    )
),
agg AS (
    SELECT
        date_trunc('month', order_timestamp)::date AS m,
        sum(order_amount) AS sum_no_commission,
        sum(total_amount) AS sum_with_commission,
        sum(commission) AS commission
    FROM "order"
    WHERE status = 'доставлен'
    GROUP BY 1
),
pay AS (
    SELECT
        make_date(year, month, 1) AS m,
        sum(amount) AS courier_pay
    FROM courier_pay
    GROUP BY 1
)
SELECT
    to_char(months.m, 'YYYY-MM') AS year_month,
    COALESCE(agg.sum_no_commission, 0) AS sum_no_commission,
    COALESCE(agg.sum_with_commission, 0) AS sum_with_commission,
    COALESCE(agg.commission, 0) AS commission,
    lag(COALESCE(agg.commission, 0)) OVER (ORDER BY months.m) AS prev_commission,
    COALESCE(agg.commission, 0) - lag(COALESCE(agg.commission, 0)) OVER (ORDER BY months.m) AS commission_diff,
    COALESCE(pay.courier_pay, 0) AS courier_pay,
    COALESCE(agg.commission, 0) - COALESCE(pay.courier_pay, 0) AS net_profit
FROM months
LEFT JOIN agg ON agg.m = months.m
LEFT JOIN pay ON pay.m = months.m
ORDER BY months.m;
