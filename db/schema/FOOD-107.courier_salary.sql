create or replace procedure stodelov_food.courier_salary()
language plpgsql
as $$
declare
    v_month_start timestamp := date_trunc('month', localtimestamp);
    v_month_end timestamp := date_trunc('month', localtimestamp) + interval '1 month';
    v_year integer := extract(year from localtimestamp)::integer;
    v_month integer := extract(month from localtimestamp)::integer;
    v_courier record;
    v_delivery_count bigint;
    v_commission_sum numeric;
    v_coefficient numeric(2,1);
    v_next_coefficient numeric(2,1);
begin
    for v_courier in
        select c.courier_id, c.status, c.coefficient
        from stodelov_food.courier c
        order by c.courier_id
        for update of c
    loop
        select count(*), coalesce(sum(o.commission), 0)
        into v_delivery_count, v_commission_sum
        from stodelov_food."order" o
        where o.courier_id = v_courier.courier_id
          and o.status = 'доставлен'
          and o.delivery_timestamp >= v_month_start
          and o.delivery_timestamp < v_month_end;

        select coalesce((
            select cp.coefficient_used
            from stodelov_food.courier_pay cp
            where cp.year = v_year and cp.month = v_month and cp.courier_id = v_courier.courier_id
        ), v_courier.coefficient) into v_coefficient;

        v_next_coefficient := case
            when v_delivery_count > 500 then 0.5
            when v_delivery_count > 250 then 0.3
            when v_delivery_count > 150 then 0.2
            else 0.1
        end;

        insert into stodelov_food.courier_pay (year, month, courier_id, amount, coefficient_used)
        values (v_year, v_month, v_courier.courier_id, round(v_commission_sum * v_coefficient, 2), v_coefficient)
        on conflict (year, month, courier_id) do update
        set amount = excluded.amount, coefficient_used = excluded.coefficient_used;

        if v_courier.status <> 'уволен' then
            update stodelov_food.courier
            set coefficient = v_next_coefficient
            where courier_id = v_courier.courier_id;
        end if;
    end loop;
end;
$$;
