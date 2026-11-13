create or replace function stodelov_food.get_statistic()
returns table (
    restaurant_name varchar(150),
    best_product_name varchar(150),
    total_amount numeric,
    avg_amount numeric,
    best_user varchar(100)
)
language sql
as $$
    with delivered_orders as materialized (
        select o.order_id, o.restaurant_id, o.client_id, o.total_amount
        from stodelov_food."order" o
        where o.status = 'доставлен'
    ),
    financial_stats as (
        select restaurant_id, sum(total_amount) as total_amount,
               avg(total_amount) as avg_amount
        from delivered_orders
        group by restaurant_id
    ),
    product_quantities as (
        select d.restaurant_id, os.product_id, sum(os.quantity) as total_quantity
        from delivered_orders d
        join stodelov_food.order_structure os on os.order_id = d.order_id
        group by d.restaurant_id, os.product_id
    ),
    best_products as (
        select distinct on (restaurant_id) restaurant_id, product_id
        from product_quantities
        order by restaurant_id, total_quantity desc, random()
    ),
    client_orders as (
        select restaurant_id, client_id, count(*) as order_count
        from delivered_orders
        group by restaurant_id, client_id
    ),
    best_clients as (
        select distinct on (restaurant_id) restaurant_id, client_id
        from client_orders
        order by restaurant_id, order_count desc, random()
    )
    select r.restaurant_name, p.product_name,
           coalesce(fs.total_amount, 0::numeric), fs.avg_amount, c.login
    from stodelov_food.restaurant r
    left join financial_stats fs on fs.restaurant_id = r.restaurant_id
    left join best_products bp on bp.restaurant_id = r.restaurant_id
    left join stodelov_food.product p on p.product_id = bp.product_id
    left join best_clients bc on bc.restaurant_id = r.restaurant_id
    left join stodelov_food.client c on c.client_id = bc.client_id
    order by r.restaurant_name, r.restaurant_id;
$$;
