create view stodelov_food.how_much_money as
with recursive delivered_by_month as (
    select date_trunc('month', o.delivery_timestamp)::date as month_start,
           sum(o.order_amount) as sum_no_commission,
           sum(o.total_amount) as sum_with_commission
    from stodelov_food."order" o
    where o.status = 'доставлен'
    group by date_trunc('month', o.delivery_timestamp)::date
),
month_bounds as (
    select min(month_start) as first_month, max(month_start) as last_month
    from delivered_by_month
),
months as (
    select first_month as month_start, last_month from month_bounds
    where first_month is not null
    union all
    select (m.month_start + interval '1 month')::date, m.last_month
    from months m
    where m.month_start < m.last_month
),
salaries_by_month as (
    select cp.year, cp.month, sum(cp.amount) as courier_pay
    from stodelov_food.courier_pay cp
    group by cp.year, cp.month
),
monthly_finances as (
    select m.month_start,
           coalesce(d.sum_no_commission, 0::numeric) as sum_no_commission,
           coalesce(d.sum_with_commission, 0::numeric) as sum_with_commission,
           coalesce(d.sum_with_commission, 0::numeric) - coalesce(d.sum_no_commission, 0::numeric) as commission,
           coalesce(s.courier_pay, 0::numeric) as courier_pay
    from months m
    left join delivered_by_month d on d.month_start = m.month_start
    left join salaries_by_month s on s.year = extract(year from m.month_start)::integer
                                 and s.month = extract(month from m.month_start)::integer
),
finances_with_previous as (
    select mf.*, lag(mf.commission) over (order by mf.month_start) as prev_commission
    from monthly_finances mf
)
select to_char(month_start, 'YYYY-MM') as year_month,
       sum_no_commission, sum_with_commission, commission, prev_commission,
       commission - prev_commission as commission_diff,
       courier_pay, commission - courier_pay as net_profit
from finances_with_previous
order by month_start;
