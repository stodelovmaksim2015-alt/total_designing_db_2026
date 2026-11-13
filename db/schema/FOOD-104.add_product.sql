create or replace procedure stodelov_food.add_product(
    p_product_name varchar(150),
    p_product_category_id uuid,
    p_price numeric(12,2),
    p_restaurant_id uuid,
    p_photo_url text,
    p_rating numeric(4,3),
    p_status stodelov_food.product_status,
    p_description text
)
language plpgsql
as $$
begin
    if p_restaurant_id is not null and not exists (
        select 1 from stodelov_food.restaurant
        where restaurant_id = p_restaurant_id
    ) then
        raise exception 'Ресторан с ID % не существует', p_restaurant_id;
    end if;

    if p_product_category_id is not null and not exists (
        select 1 from stodelov_food.product_category
        where product_category_id = p_product_category_id
    ) then
        raise exception 'Категория с ID % не существует', p_product_category_id;
    end if;

    if p_price < 0 then
        raise exception 'Цена блюда не может быть отрицательной: %', p_price;
    end if;

    if p_rating is not null and p_rating not between 0 and 5 then
        raise exception 'Рейтинг блюда должен быть от 0 до 5: %', p_rating;
    end if;

    insert into stodelov_food.product (
        product_name, product_category_id, price, restaurant_id,
        photo_url, rating, status, description
    ) values (
        p_product_name, p_product_category_id, p_price, p_restaurant_id,
        p_photo_url, p_rating, p_status, p_description
    );
end;
$$;
