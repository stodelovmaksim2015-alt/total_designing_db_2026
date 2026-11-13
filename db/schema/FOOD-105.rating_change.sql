create or replace function stodelov_food.rating_change()
returns trigger
language plpgsql
as $$
begin
    if tg_op = 'DELETE' then
        if old.entity_type = 'блюдо' then
            update stodelov_food.product p
            set rating = (
                select round(avg(r.rating), 3)
                from stodelov_food.review r
                where r.entity_type = 'блюдо' and r.entity_id = old.entity_id
            )
            where p.product_id = old.entity_id;
        elsif old.entity_type = 'ресторан' then
            update stodelov_food.restaurant t
            set rating = (
                select round(avg(r.rating), 3)
                from stodelov_food.review r
                where r.entity_type = 'ресторан' and r.entity_id = old.entity_id
            )
            where t.restaurant_id = old.entity_id;
        end if;

        return old;
    end if;

    if tg_op = 'UPDATE' then
        if old.entity_type is distinct from new.entity_type
           or old.entity_id is distinct from new.entity_id then
            if old.entity_type = 'блюдо' then
                update stodelov_food.product p
                set rating = (
                    select round(avg(r.rating), 3)
                    from stodelov_food.review r
                    where r.entity_type = 'блюдо' and r.entity_id = old.entity_id
                )
                where p.product_id = old.entity_id;
            elsif old.entity_type = 'ресторан' then
                update stodelov_food.restaurant t
                set rating = (
                    select round(avg(r.rating), 3)
                    from stodelov_food.review r
                    where r.entity_type = 'ресторан' and r.entity_id = old.entity_id
                )
                where t.restaurant_id = old.entity_id;
            end if;
        elsif old.rating is not distinct from new.rating then
            return new;
        end if;
    end if;

    if new.entity_type = 'блюдо' then
        update stodelov_food.product p
        set rating = (
            select round(avg(r.rating), 3)
            from stodelov_food.review r
            where r.entity_type = 'блюдо' and r.entity_id = new.entity_id
        )
        where p.product_id = new.entity_id;
    elsif new.entity_type = 'ресторан' then
        update stodelov_food.restaurant t
        set rating = (
            select round(avg(r.rating), 3)
            from stodelov_food.review r
            where r.entity_type = 'ресторан' and r.entity_id = new.entity_id
        )
        where t.restaurant_id = new.entity_id;
    end if;

    return new;
end;
$$;

create trigger trg_rating_change
after insert or update or delete on stodelov_food.review
for each row
execute function stodelov_food.rating_change();
