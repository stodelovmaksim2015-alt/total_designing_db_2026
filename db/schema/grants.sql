begin;

do $$
begin
    if not exists (select 1 from pg_catalog.pg_roles where rolname = 'inspector') then
        create role inspector with login password 'NetoSQL2025';
    else
        alter role inspector with login password 'NetoSQL2025';
    end if;
end;
$$;

grant all privileges on schema stodelov_food to inspector;
grant usage on schema exts to inspector;
grant all privileges on all tables in schema stodelov_food to inspector;
grant all privileges on all sequences in schema stodelov_food to inspector;
grant execute on all routines in schema stodelov_food to inspector;
grant usage on type
    stodelov_food.restaurant_status,
    stodelov_food.product_status,
    stodelov_food.courier_status,
    stodelov_food.order_status,
    stodelov_food.order_pay_status,
    stodelov_food.payment_type,
    stodelov_food.payment_status,
    stodelov_food.review_entity_type
to inspector;

do $$
begin
    if not has_database_privilege('inspector', current_database(), 'connect') then
        execute format('grant connect on database %I to inspector', current_database());
    end if;

    if not has_schema_privilege('inspector', 'information_schema', 'usage') then
        grant usage on schema information_schema to inspector;
    end if;

    if not has_schema_privilege('inspector', 'pg_catalog', 'usage') then
        grant usage on schema pg_catalog to inspector;
    end if;

    if not has_function_privilege('inspector', 'exts.uuid_generate_v4()', 'execute') then
        grant execute on function exts.uuid_generate_v4() to inspector;
    end if;
end;
$$;

commit;
