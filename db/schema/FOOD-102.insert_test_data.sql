create or replace procedure stodelov_food.insert_test_data(value integer)
language plpgsql
set search_path = stodelov_food, exts, public
as $$
declare
    v_now timestamp := localtimestamp;
    v_current_month timestamp := date_trunc('month', localtimestamp);
    v_first_month timestamp := date_trunc('month', localtimestamp) - interval '6 months';
    v_cutoff timestamp := localtimestamp - interval '6 months';

    v_streets text[] := array[
        'Ленина', 'Пушкина', 'Лесная', 'Центральная', 'Садовая',
        'Молодёжная', 'Школьная', 'Парковая', 'Новая', 'Советская',
        'Берёзовая', 'Солнечная', 'Зелёная', 'Набережная', 'Полевая',
        'Цветочная', 'Спортивная', 'Северная', 'Южная', 'Мира'
    ];
    v_restaurant_names text[] := array[
        'Пицца Хаус', 'Вкус Востока', 'Суши Мастер', 'Городская кухня', 'Дом пасты',
        'Бургер Клуб', 'Тёплый хлеб', 'Уютное кафе', 'Вкусный двор', 'Траттория',
        'Золотая ложка', 'Пряный мир', 'Семейный обед', 'Бистро на углу', 'Лавка вкуса',
        'Поварёнок', 'Гастро Дом', 'Сытный день', 'Восточный дворик', 'Кухня друзей'
    ];
    v_categories_names text[] := array[
        'Пицца', 'Суши и роллы', 'Бургеры', 'Супы', 'Салаты',
        'Горячие блюда', 'Паста', 'Десерты', 'Напитки', 'Завтраки'
    ];
    v_product_names text[] := array[
        'Маргарита', 'Пепперони', 'Четыре сыра', 'Гавайская пицца', 'Мясная пицца',
        'Филадельфия', 'Калифорния', 'Ролл с огурцом', 'Запечённый ролл', 'Ролл с тунцом',
        'Чизбургер', 'Двойной бургер', 'Бургер с курицей', 'Бекон бургер', 'Острый бургер',
        'Борщ', 'Том-ям', 'Куриный суп', 'Грибной крем-суп', 'Солянка',
        'Цезарь', 'Греческий салат', 'Овощной салат', 'Салат с тунцом', 'Салат с курицей',
        'Курица с рисом', 'Говядина с овощами', 'Стейк из индейки', 'Рыба с картофелем', 'Плов',
        'Карбонара', 'Болоньезе', 'Паста с грибами', 'Паста с креветками', 'Паста с песто',
        'Чизкейк', 'Тирамису', 'Шоколадный торт', 'Медовик', 'Ягодный мусс',
        'Морс', 'Лимонад', 'Апельсиновый сок', 'Капучино', 'Чай с лимоном',
        'Омлет', 'Сырники', 'Овсяная каша', 'Яичница с тостами', 'Блины с творогом'
    ];
    v_min_prices integer[] := array[550, 350, 350, 220, 300, 500, 450, 200, 120, 250];
    v_max_prices integer[] := array[1250, 1100, 850, 500, 750, 1300, 1000, 650, 400, 650];
    v_first_names text[] := array['Иван', 'Пётр', 'Александр', 'Михаил', 'Дмитрий', 'Артём', 'Никита', 'Максим', 'Андрей', 'Сергей'];
    v_last_names text[] := array['Иванов', 'Петров', 'Сидоров', 'Смирнов', 'Кузнецов', 'Попов', 'Васильев', 'Морозов', 'Фёдоров', 'Соколов'];
    v_middle_names text[] := array['Иванович', 'Петрович', 'Александрович', 'Михайлович', 'Дмитриевич', 'Андреевич'];

    v_restaurant_statuses stodelov_food.restaurant_status[] := enum_range(null::stodelov_food.restaurant_status);
    v_product_statuses stodelov_food.product_status[] := enum_range(null::stodelov_food.product_status);
    v_courier_statuses stodelov_food.courier_status[] := enum_range(null::stodelov_food.courier_status);
    v_order_statuses stodelov_food.order_status[] := enum_range(null::stodelov_food.order_status);
    v_order_pay_statuses stodelov_food.order_pay_status[] := enum_range(null::stodelov_food.order_pay_status);
    v_payment_types stodelov_food.payment_type[] := enum_range(null::stodelov_food.payment_type);
    v_payment_statuses stodelov_food.payment_status[] := enum_range(null::stodelov_food.payment_status);
    v_review_types stodelov_food.review_entity_type[] := enum_range(null::stodelov_food.review_entity_type);

    v_clients uuid[] := array[]::uuid[];
    v_client_addresses uuid[] := array[]::uuid[];
    v_restaurants uuid[] := array[]::uuid[];
    v_categories uuid[] := array[]::uuid[];
    v_products uuid[] := array[]::uuid[];
    v_product_prices numeric[] := array[]::numeric[];
    v_couriers uuid[] := array[]::uuid[];

    v_id uuid;
    v_address_id uuid;
    v_order_id uuid;
    v_client_id uuid;
    v_restaurant_id uuid;
    v_courier_id uuid;
    v_product_1 uuid;
    v_product_2 uuid;
    v_review_entity_id uuid;
    v_review_type stodelov_food.review_entity_type;
    v_phone text;
    v_street text;
    v_house text;
    v_apartment text;
    v_cat_index integer;
    v_cat_bucket integer;
    v_product_index integer;
    v_client_index integer;
    v_courier_index integer;
    v_quantity_1 integer;
    v_quantity_2 integer;
    v_price numeric(12,2);
    v_order_amount numeric(24,2);
    v_total_amount numeric(26,2);
    v_order_status stodelov_food.order_status;
    v_pay_status stodelov_food.order_pay_status;
    v_payment_type stodelov_food.payment_type;
    v_month_start timestamp;
    v_day_low date;
    v_day_high date;
    v_order_day date;
    v_order_ts timestamp;
    v_delivery_ts timestamp;
    v_period_start timestamp;
    v_coefficient numeric(2,1);
    v_next_coefficient numeric(2,1);
    v_last_coefficient numeric(2,1);
    v_commission_sum numeric(28,2);
    v_delivery_count bigint;
    v_is_dismissed boolean;
    i integer;
    j integer;
    k integer;
    m integer;
begin
    if value is null or value <= 0 then
        raise exception 'value должен быть положительным целым числом';
    end if;

    for i in 1..value loop
        v_id := exts.uuid_generate_v4();
        loop
            v_phone := '+7' || lpad(floor(random() * 10000000000)::bigint::text, 10, '0');
            exit when not exists (
                select 1 from stodelov_food.client where phone_number = v_phone
            );
        end loop;

        insert into stodelov_food.client (client_id, login, password, phone_number)
        values (v_id, 'client_' || replace(v_id::text, '-', ''), md5(random()::text), v_phone)
        returning client_id into v_id;
        v_clients := array_append(v_clients, v_id);
    end loop;

    for i in 1..value loop
        v_cat_bucket := ((i - 1) % array_length(v_categories_names, 1)) + 1;
        insert into stodelov_food.product_category (product_category_name)
        values (v_categories_names[v_cat_bucket])
        returning product_category_id into v_id;
        v_categories := array_append(v_categories, v_id);
    end loop;

    for i in 1..value loop
        loop
            v_phone := '+7' || lpad(floor(random() * 10000000000)::bigint::text, 10, '0');
            exit when not exists (
                select 1 from stodelov_food.courier where phone_number = v_phone
            );
        end loop;

        v_is_dismissed := value > 1 and i % 10 = 0;
        insert into stodelov_food.courier (
            fio, phone_number, status, hire_date, dismissal_date, coefficient
        ) values (
            v_last_names[1 + floor(random() * array_length(v_last_names, 1))::integer] || ' ' ||
            v_first_names[1 + floor(random() * array_length(v_first_names, 1))::integer] || ' ' ||
            v_middle_names[1 + floor(random() * array_length(v_middle_names, 1))::integer],
            v_phone,
            case when v_is_dismissed then v_courier_statuses[4]
                 else v_courier_statuses[1 + floor(random() * 3)::integer] end,
            v_cutoff::date,
            case when v_is_dismissed then (v_current_month - interval '1 day')::date else null end,
            0.1
        ) returning courier_id into v_id;
        v_couriers := array_append(v_couriers, v_id);
    end loop;

    for i in 1..value loop
        loop
            v_street := v_streets[1 + floor(random() * array_length(v_streets, 1))::integer];
            v_house := (1 + floor(random() * 180)::integer)::text;
            v_apartment := case when random() < 0.5 then null
                                else (1 + floor(random() * 250)::integer)::text end;
            exit when not exists (
                select 1
                from stodelov_food.restaurant r
                join stodelov_food.address a on a.address_id = r.address_id
                where a.street = v_street
                  and a.house_number = v_house
                  and a.apartment_office is not distinct from v_apartment
            );
        end loop;

        insert into stodelov_food.address (street, house_number, apartment_office)
        values (v_street, v_house, v_apartment)
        returning address_id into v_address_id;

        insert into stodelov_food.restaurant (
            restaurant_name, address_id, description, work_start, work_end,
            company_details, rating, status
        ) values (
            v_restaurant_names[1 + floor(random() * array_length(v_restaurant_names, 1))::integer],
            v_address_id,
            'Ресторан с доставкой горячих блюд и напитков',
            make_time(8 + floor(random() * 3)::integer, 0, 0),
            make_time(21 + floor(random() * 3)::integer, 0, 0),
            'Тестовые реквизиты ресторана ' || v_address_id::text,
            null,
            case when i = 1 or random() < 0.8 then v_restaurant_statuses[1]
                 else v_restaurant_statuses[2] end
        ) returning restaurant_id into v_id;
        v_restaurants := array_append(v_restaurants, v_id);
    end loop;

    for i in 1..value loop
        for j in 1..4 loop
            insert into stodelov_food.address (street, house_number, apartment_office)
            values (
                v_streets[1 + floor(random() * array_length(v_streets, 1))::integer],
                (1 + floor(random() * 180)::integer)::text,
                case when random() < 0.2 then null
                     else (1 + floor(random() * 250)::integer)::text end
            ) returning address_id into v_address_id;

            insert into stodelov_food.client_address (client_id, address_id)
            values (v_clients[i], v_address_id);
            v_client_addresses := array_append(v_client_addresses, v_address_id);
        end loop;
    end loop;

    for i in 1..value loop
        for j in 1..5 loop
            v_cat_index := (((i - 1) * 5 + j - 1) % value) + 1;
            v_cat_bucket := ((v_cat_index - 1) % array_length(v_categories_names, 1)) + 1;
            v_product_index := (v_cat_bucket - 1) * 5 + 1 + floor(random() * 5)::integer;
            v_price := (
                v_min_prices[v_cat_bucket] +
                floor(random() * (v_max_prices[v_cat_bucket] - v_min_prices[v_cat_bucket] + 1))::integer
            )::numeric(12,2);

            insert into stodelov_food.product (
                product_name, product_category_id, price, restaurant_id,
                photo_url, rating, status, description
            ) values (
                v_product_names[v_product_index],
                v_categories[v_cat_index],
                v_price,
                v_restaurants[i],
                null,
                null,
                v_product_statuses[1 + floor(random() * array_length(v_product_statuses, 1))::integer],
                'Блюдо приготовлено из свежих ингредиентов'
            ) returning product_id into v_id;
            v_products := array_append(v_products, v_id);
            v_product_prices := array_append(v_product_prices, v_price);
        end loop;
    end loop;

    for i in 1..value loop
        v_restaurant_id := v_restaurants[i];

        for j in 1..5 loop
            v_client_index := ((i + j - 2) % value) + 1;
            v_courier_index := ((i + j - 2) % value) + 1;
            v_client_id := v_clients[v_client_index];
            v_courier_id := v_couriers[v_courier_index];
            v_address_id := v_client_addresses[(v_client_index - 1) * 4 + ((j - 1) % 4) + 1];

            v_product_index := (i - 1) * 5 + j;
            v_product_1 := v_products[v_product_index];
            v_product_2 := v_products[(i - 1) * 5 + (j % 5) + 1];
            v_quantity_1 := 1 + floor(random() * 5)::integer;
            v_quantity_2 := 1 + floor(random() * 5)::integer;
            v_order_amount := v_product_prices[v_product_index] * v_quantity_1 +
                              v_product_prices[(i - 1) * 5 + (j % 5) + 1] * v_quantity_2;

            if v_order_amount * 1.10 < 1000 then
                v_quantity_1 := 5;
                v_quantity_2 := 5;
                v_order_amount := v_product_prices[v_product_index] * v_quantity_1 +
                                  v_product_prices[(i - 1) * 5 + (j % 5) + 1] * v_quantity_2;
            end if;

            v_month_start := v_first_month + (((i - 1) * 5 + j - 1) % 6) * interval '1 month';
            v_day_low := greatest(v_month_start::date, v_cutoff::date + 1);
            v_day_high := (v_month_start + interval '1 month')::date - 2;

            if v_day_low > v_day_high then
                v_month_start := v_month_start + interval '1 month';
                v_day_low := v_month_start::date;
                v_day_high := (v_month_start + interval '1 month')::date - 2;
            end if;

            v_order_day := v_day_low + floor(random() * (v_day_high - v_day_low + 1))::integer;
            v_order_ts := v_order_day::timestamp + interval '10 hours' +
                          floor(random() * 10)::integer * interval '1 hour' +
                          floor(random() * 60)::integer * interval '1 minute';
            v_delivery_ts := v_order_ts + (20 + floor(random() * 101)::integer) * interval '1 minute';

            if j in (1, 2) then
                v_order_status := v_order_statuses[4];
                v_pay_status := v_order_pay_statuses[2];
            elsif j = 3 then
                v_order_status := v_order_statuses[5];
                v_pay_status := v_order_pay_statuses[3];
            elsif j = 4 then
                v_order_status := v_order_statuses[2];
                v_pay_status := v_order_pay_statuses[1];
            else
                v_order_status := case when i % 2 = 0 then v_order_statuses[3]
                                       else v_order_statuses[1] end;
                v_pay_status := v_order_pay_statuses[1];
            end if;

            insert into stodelov_food."order" (
                courier_id, client_id, address_id, restaurant_id,
                order_timestamp, delivery_timestamp, order_amount,
                status, pay_status, description
            ) values (
                v_courier_id, v_client_id, v_address_id, v_restaurant_id,
                v_order_ts,
                case when j in (1, 2) then v_delivery_ts else null end,
                v_order_amount,
                v_order_status,
                v_pay_status,
                'Заказ из двух блюд'
            ) returning order_id, total_amount into v_order_id, v_total_amount;

            insert into stodelov_food.order_structure (order_id, product_id, quantity)
            values (v_order_id, v_product_1, v_quantity_1),
                   (v_order_id, v_product_2, v_quantity_2);

            v_payment_type := v_payment_types[1 + floor(random() * array_length(v_payment_types, 1))::integer];

            if j = 1 then
                insert into stodelov_food.payment (
                    order_id, payment_type, amount, transaction_id, transaction_timestamp, status
                ) values (
                    v_order_id, v_payment_type, v_total_amount,
                    'TX-' || replace(exts.uuid_generate_v4()::text, '-', ''),
                    v_order_ts + interval '1 minute', v_payment_statuses[1]
                );
            elsif j = 2 then
                insert into stodelov_food.payment (
                    order_id, payment_type, amount, transaction_id, transaction_timestamp, status
                ) values (
                    v_order_id, v_payment_type, v_total_amount,
                    'TX-' || replace(exts.uuid_generate_v4()::text, '-', ''),
                    v_order_ts + interval '1 minute', v_payment_statuses[2]
                );
                insert into stodelov_food.payment (
                    order_id, payment_type, amount, transaction_id, transaction_timestamp, status
                ) values (
                    v_order_id,
                    v_payment_types[(array_position(v_payment_types, v_payment_type) % array_length(v_payment_types, 1)) + 1],
                    v_total_amount,
                    'TX-' || replace(exts.uuid_generate_v4()::text, '-', ''),
                    v_order_ts + interval '2 minutes', v_payment_statuses[1]
                );
            elsif j = 3 then
                insert into stodelov_food.payment (
                    order_id, payment_type, amount, transaction_id, transaction_timestamp, status
                ) values (
                    v_order_id, v_payment_type, v_total_amount,
                    'TX-' || replace(exts.uuid_generate_v4()::text, '-', ''),
                    v_order_ts + interval '1 minute', v_payment_statuses[2]
                );
            elsif j = 4 then
                insert into stodelov_food.payment (
                    order_id, payment_type, amount, transaction_id, transaction_timestamp, status
                ) values (
                    v_order_id, v_payment_type, v_total_amount,
                    'TX-' || replace(exts.uuid_generate_v4()::text, '-', ''),
                    v_order_ts + interval '1 minute', v_payment_statuses[3]
                );
            end if;

            if j in (1, 2) then
                for k in 1..case when j = 1 then 3 else 2 end loop
                    if j = 1 then
                        if k = 1 then
                            v_review_type := v_review_types[1];
                            v_review_entity_id := v_product_1;
                        elsif k = 2 then
                            v_review_type := v_review_types[1];
                            v_review_entity_id := v_product_2;
                        else
                            v_review_type := v_review_types[2];
                            v_review_entity_id := v_restaurant_id;
                        end if;
                    elsif k = 1 then
                        v_review_type := v_review_types[1];
                        v_review_entity_id := v_product_1;
                    else
                        v_review_type := v_review_types[3];
                        v_review_entity_id := v_order_id;
                    end if;

                    insert into stodelov_food.review (
                        client_id, review_timestamp, entity_id, entity_type,
                        order_id, description, photo_url, rating
                    ) values (
                        v_client_id,
                        v_delivery_ts + k * interval '5 minutes',
                        v_review_entity_id,
                        v_review_type,
                        v_order_id,
                        'Отзыв после получения заказа',
                        null,
                        1 + floor(random() * 5)::integer
                    );
                end loop;
            end if;
        end loop;
    end loop;

    update stodelov_food.product p
    set rating = (
        select round(avg(r.rating), 3)
        from stodelov_food.review r
        where r.entity_type = v_review_types[1]
          and r.entity_id = p.product_id
    )
    where p.product_id = any(v_products);

    update stodelov_food.restaurant t
    set rating = (
        select round(avg(r.rating), 3)
        from stodelov_food.review r
        where r.entity_type = v_review_types[2]
          and r.entity_id = t.restaurant_id
    )
    where t.restaurant_id = any(v_restaurants);

    for i in 1..value loop
        v_courier_id := v_couriers[i];
        v_is_dismissed := value > 1 and i % 10 = 0;
        v_coefficient := 0.1;

        for m in 0..5 loop
            v_period_start := v_first_month + m * interval '1 month';

            select count(*), coalesce(sum(o.commission), 0)
            into v_delivery_count, v_commission_sum
            from stodelov_food."order" o
            where o.courier_id = v_courier_id
              and o.status = v_order_statuses[4]
              and o.order_timestamp >= v_period_start
              and o.order_timestamp < v_period_start + interval '1 month';

            insert into stodelov_food.courier_pay (
                year, month, courier_id, amount, coefficient_used
            ) values (
                extract(year from v_period_start)::integer,
                extract(month from v_period_start)::integer,
                v_courier_id,
                round(v_commission_sum * v_coefficient, 2),
                v_coefficient
            );

            v_last_coefficient := v_coefficient;
            v_next_coefficient := case
                when v_delivery_count > 500 then 0.5
                when v_delivery_count > 250 then 0.3
                when v_delivery_count > 150 then 0.2
                else 0.1
            end;
            v_coefficient := v_next_coefficient;
        end loop;

        update stodelov_food.courier
        set coefficient = case when v_is_dismissed then v_last_coefficient
                               else v_coefficient end
        where courier_id = v_courier_id;
    end loop;
end;
$$;
