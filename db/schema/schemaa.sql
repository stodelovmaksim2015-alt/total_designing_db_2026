begin;

create schema if not exists stodelov_food;

create schema if not exists exts;

create extension if not exists "uuid-ossp" with schema exts;

create extension if not exists btree_gist with schema exts;

set search_path to stodelov_food, exts, public;

create type stodelov_food.restaurant_status as enum ('активен', 'неактивен');
create type stodelov_food.product_status as enum ('доступно', 'нет_в_наличии', 'архив');
create type stodelov_food.courier_status as enum ('свободен', 'занят', 'на_доставке', 'уволен');
create type stodelov_food.order_status as enum ('создан', 'готовится', 'в_доставке', 'доставлен', 'отменён');
create type stodelov_food.order_pay_status as enum ('ожидает', 'оплачен', 'ошибка');
create type stodelov_food.payment_type as enum ('карта', 'наличные', 'безнал');
create type stodelov_food.payment_status as enum ('успех', 'ошибка', 'в_обработке');
create type stodelov_food.review_entity_type as enum ('блюдо', 'ресторан', 'заказ');

create table stodelov_food.client (
    client_id uuid primary key default exts.uuid_generate_v4(),
    login varchar(100) not null,
    password varchar(32) not null,
    phone_number varchar(20) not null,
    constraint uq_client_login unique (login),
    constraint uq_client_phone_number unique (phone_number)
);

create table stodelov_food.address (
    address_id uuid primary key default exts.uuid_generate_v4(),
    street varchar(150) not null,
    house_number varchar(20) not null,
    apartment_office varchar(20)
);

create table stodelov_food.client_address (
    client_id uuid not null,
    address_id uuid not null,
    constraint pk_client_address primary key (client_id, address_id),
    constraint fk_client_address_client foreign key (client_id) references stodelov_food.client (client_id),
    constraint fk_client_address_address foreign key (address_id) references stodelov_food.address (address_id)
);

create table stodelov_food.restaurant (
    restaurant_id uuid primary key default exts.uuid_generate_v4(),
    restaurant_name varchar(150) not null,
    address_id uuid not null,
    description text not null,
    work_start time not null,
    work_end time not null,
    company_details text not null,
    rating numeric(4,3),
    status stodelov_food.restaurant_status not null,
    constraint uq_restaurant_address unique (address_id),
    constraint fk_restaurant_address foreign key (address_id) references stodelov_food.address (address_id),
    constraint chk_restaurant_rating check (rating between 0 and 5),
    constraint chk_restaurant_work_time check (work_end > work_start)
);

create table stodelov_food.product_category (
    product_category_id uuid primary key default exts.uuid_generate_v4(),
    product_category_name varchar(100) not null
);

create table stodelov_food.product (
    product_id uuid primary key default exts.uuid_generate_v4(),
    product_name varchar(150) not null,
    product_category_id uuid not null,
    price numeric(12,2) not null,
    restaurant_id uuid not null,
    photo_url text,
    rating numeric(4,3) default null,
    status stodelov_food.product_status not null,
    description text not null,
    constraint fk_product_category foreign key (product_category_id) references stodelov_food.product_category (product_category_id),
    constraint fk_product_restaurant foreign key (restaurant_id) references stodelov_food.restaurant (restaurant_id),
    constraint chk_product_price check (price >= 0),
    constraint chk_product_rating check (rating between 0 and 5)
);

create table stodelov_food.courier (
    courier_id uuid primary key default exts.uuid_generate_v4(),
    fio varchar(150) not null,
    phone_number varchar(20) not null,
    status stodelov_food.courier_status not null,
    hire_date date not null,
    dismissal_date date,
    coefficient numeric(2,1) not null default 0.1,
    constraint chk_courier_coefficient check (coefficient between 0.1 and 0.5),
    constraint chk_courier_dismissal_date check (dismissal_date is null or dismissal_date >= hire_date),
    constraint chk_courier_dismissal_status check (status <> 'уволен' or dismissal_date is not null)
);

create table stodelov_food.courier_pay (
    year integer not null,
    month integer not null,
    courier_id uuid not null,
    amount numeric(28,2) not null,
    coefficient_used numeric(2,1) not null,
    constraint pk_courier_pay primary key (year, month, courier_id),
    constraint fk_courier_pay_courier foreign key (courier_id) references stodelov_food.courier (courier_id),
    constraint chk_courier_pay_month check (month between 1 and 12),
    constraint chk_courier_pay_amount check (amount >= 0),
    constraint chk_courier_pay_coefficient check (coefficient_used between 0.1 and 0.5)
);

create table stodelov_food."order" (
    order_id uuid primary key default exts.uuid_generate_v4(),
    courier_id uuid not null,
    client_id uuid not null,
    address_id uuid not null,
    restaurant_id uuid not null,
    order_timestamp timestamp not null default localtimestamp,
    delivery_timestamp timestamp,
    order_amount numeric(24,2) not null,
    commission numeric(26,2) generated always as (order_amount * 0.10) stored not null,
    total_amount numeric(26,2) generated always as (order_amount + order_amount * 0.10) stored not null,
    status stodelov_food.order_status not null,
    pay_status stodelov_food.order_pay_status not null,
    description text not null,
    constraint fk_order_courier foreign key (courier_id) references stodelov_food.courier (courier_id),
    constraint fk_order_client foreign key (client_id) references stodelov_food.client (client_id),
    constraint fk_order_address foreign key (address_id) references stodelov_food.address (address_id),
    constraint fk_order_restaurant foreign key (restaurant_id) references stodelov_food.restaurant (restaurant_id),
    constraint fk_order_client_address foreign key (client_id, address_id) references stodelov_food.client_address (client_id, address_id),
    constraint chk_order_total_amount check (total_amount >= 1000),
    constraint chk_order_delivery_after_creation check (delivery_timestamp is null or delivery_timestamp >= order_timestamp),
    constraint chk_order_delivery_required check (status <> 'доставлен' or delivery_timestamp is not null)
);

create table stodelov_food.order_structure (
    order_id uuid not null,
    product_id uuid not null,
    quantity numeric(12,3) not null,
    constraint pk_order_structure primary key (order_id, product_id),
    constraint fk_order_structure_order foreign key (order_id) references stodelov_food."order" (order_id),
    constraint fk_order_structure_product foreign key (product_id) references stodelov_food.product (product_id),
    constraint chk_order_structure_quantity check (quantity > 0)
);

create table stodelov_food.payment (
    payment_id uuid primary key default exts.uuid_generate_v4(),
    order_id uuid not null,
    payment_type stodelov_food.payment_type not null,
    amount numeric(26,2) not null,
    transaction_id text not null,
    transaction_timestamp timestamp not null,
    status stodelov_food.payment_status not null,
    constraint fk_payment_order foreign key (order_id) references stodelov_food."order" (order_id),
    constraint uq_payment_transaction_id unique (transaction_id)
);

alter table stodelov_food.payment
add constraint payment_one_success
exclude using gist (order_id with =)
where (status = 'успех');

create table stodelov_food.review (
    review_id uuid primary key default exts.uuid_generate_v4(),
    client_id uuid not null,
    review_timestamp timestamp not null,
    entity_id uuid not null,
    entity_type stodelov_food.review_entity_type not null,
    order_id uuid not null,
    description text not null,
    photo_url text,
    rating numeric(4,3) not null,
    constraint fk_review_client foreign key (client_id) references stodelov_food.client (client_id),
    constraint fk_review_order foreign key (order_id) references stodelov_food."order" (order_id),
    constraint uq_review_order_entity unique (order_id, entity_type, entity_id),
    constraint chk_review_rating check (rating between 1 and 5)
);



create or replace function stodelov_food.check_payment_amount()
returns trigger
language plpgsql
as $$
declare
    v_total numeric(26,2);
begin
    select o.total_amount into v_total
    from stodelov_food."order" o
    where o.order_id = new.order_id
    for share;

    if not found then
        raise exception 'заказ % не найден', new.order_id;
    end if;

    if new.amount <> v_total then
        raise exception 'сумма платежа % не соответствует сумме заказа %', new.amount, v_total;
    end if;

    return new;
end;
$$;

create trigger trg_payment_amount
before insert or update of order_id, amount
on stodelov_food.payment
for each row
execute function stodelov_food.check_payment_amount();

create or replace function stodelov_food.check_order_payment_amount()
returns trigger
language plpgsql
as $$
begin
    if exists (
        select 1
        from stodelov_food.payment p
        where p.order_id = new.order_id
          and p.amount <> new.total_amount
    ) then
        raise exception 'новая сумма заказа не соответствует существующим платежам';
    end if;

    return new;
end;
$$;

create trigger trg_order_payment_amount
after update of order_amount
on stodelov_food."order"
for each row
when (old.total_amount is distinct from new.total_amount)
execute function stodelov_food.check_order_payment_amount();



create or replace function stodelov_food.check_order_structure_restaurant()
returns trigger
language plpgsql
as $$
declare
    v_order_restaurant uuid;
    v_product_restaurant uuid;
begin
    select restaurant_id into v_order_restaurant
    from stodelov_food."order"
    where order_id = new.order_id
    for share;

    select restaurant_id into v_product_restaurant
    from stodelov_food.product
    where product_id = new.product_id
    for share;

    if v_order_restaurant is distinct from v_product_restaurant then
        raise exception 'блюдо не принадлежит ресторану заказа';
    end if;

    return new;
end;
$$;

create trigger trg_order_structure_restaurant
before insert or update of order_id, product_id
on stodelov_food.order_structure
for each row
execute function stodelov_food.check_order_structure_restaurant();

create or replace function stodelov_food.check_order_restaurant_update()
returns trigger
language plpgsql
as $$
declare
    v_restaurant_id uuid;
begin
    for v_restaurant_id in
        select p.restaurant_id
        from stodelov_food.order_structure os
        join stodelov_food.product p on p.product_id = os.product_id
        where os.order_id = new.order_id
        for share of p
    loop
        if v_restaurant_id <> new.restaurant_id then
            raise exception 'ресторан заказа не соответствует его блюдам';
        end if;
    end loop;

    return new;
end;
$$;

create trigger trg_order_restaurant_update
before update of restaurant_id
on stodelov_food."order"
for each row
when (old.restaurant_id is distinct from new.restaurant_id)
execute function stodelov_food.check_order_restaurant_update();

create or replace function stodelov_food.check_product_restaurant_update()
returns trigger
language plpgsql
as $$
declare
    v_restaurant_id uuid;
begin
    for v_restaurant_id in
        select o.restaurant_id
        from stodelov_food.order_structure os
        join stodelov_food."order" o on o.order_id = os.order_id
        where os.product_id = new.product_id
        for share of o
    loop
        if v_restaurant_id <> new.restaurant_id then
            raise exception 'блюдо уже используется в заказе другого ресторана';
        end if;
    end loop;

    return new;
end;
$$;

create trigger trg_product_restaurant_update
before update of restaurant_id
on stodelov_food.product
for each row
when (old.restaurant_id is distinct from new.restaurant_id)
execute function stodelov_food.check_product_restaurant_update();



create or replace function stodelov_food.check_review_target()
returns trigger
language plpgsql
as $$
declare
    v_client_id uuid;
    v_restaurant_id uuid;
begin
    select o.client_id, o.restaurant_id
    into v_client_id, v_restaurant_id
    from stodelov_food."order" o
    where o.order_id = new.order_id
    for share;

    if not found then
        raise exception 'заказ % не существует', new.order_id;
    end if;

    if new.client_id <> v_client_id then
        raise exception 'клиент не является владельцем заказа';
    end if;

    if new.entity_type = 'блюдо' then
        perform 1
        from stodelov_food.order_structure os
        where os.order_id = new.order_id
          and os.product_id = new.entity_id
        for share;

        if not found then
            raise exception 'блюдо отсутствует в составе заказа';
        end if;

    elsif new.entity_type = 'ресторан' then
        if new.entity_id <> v_restaurant_id then
            raise exception 'ресторан не соответствует ресторану заказа';
        end if;

    elsif new.entity_type = 'заказ' then
        if new.entity_id <> new.order_id then
            raise exception 'отзыв относится к другому заказу';
        end if;

    else
        raise exception 'недопустимый тип объекта отзыва';
    end if;

    return new;
end;
$$;

create trigger trg_review_target
before insert or update of client_id, order_id, entity_type, entity_id
on stodelov_food.review
for each row
execute function stodelov_food.check_review_target();

create or replace function stodelov_food.check_order_review_integrity()
returns trigger
language plpgsql
as $$
begin
    if exists (
        select 1
        from stodelov_food.review r
        where r.order_id = new.order_id
          and (
              r.client_id is distinct from new.client_id
              or (
                  r.entity_type = 'ресторан'
                  and r.entity_id is distinct from new.restaurant_id
              )
          )
    ) then
        raise exception 'изменение заказа нарушает принадлежность существующих отзывов';
    end if;

    return new;
end;
$$;

create trigger trg_order_review_integrity
before update of client_id, restaurant_id
on stodelov_food."order"
for each row
when (
    old.client_id is distinct from new.client_id
    or old.restaurant_id is distinct from new.restaurant_id
)
execute function stodelov_food.check_order_review_integrity();

create or replace function stodelov_food.check_order_structure_review()
returns trigger
language plpgsql
as $$
begin
    if tg_op = 'UPDATE' then
        if old.order_id = new.order_id
           and old.product_id = new.product_id then
            return new;
        end if;
    end if;

    if exists (
        select 1
        from stodelov_food.review r
        where r.order_id = old.order_id
          and r.entity_type = 'блюдо'
          and r.entity_id = old.product_id
    ) then
        raise exception 'нельзя удалить или заменить блюдо, на которое существует отзыв';
    end if;

    if tg_op = 'DELETE' then
        return old;
    end if;

    return new;
end;
$$;

create trigger trg_order_structure_review_delete
before delete on stodelov_food.order_structure
for each row
execute function stodelov_food.check_order_structure_review();

create trigger trg_order_structure_review_update
before update of order_id, product_id
on stodelov_food.order_structure
for each row
execute function stodelov_food.check_order_structure_review();



create or replace function stodelov_food.check_order_has_items()
returns trigger
language plpgsql
as $$
declare
    v_order_id uuid;
begin
    if tg_table_name = 'order' then
        v_order_id := new.order_id;
    else
        v_order_id := old.order_id;
    end if;

    if exists (
        select 1
        from stodelov_food."order"
        where order_id = v_order_id
    ) and not exists (
        select 1
        from stodelov_food.order_structure
        where order_id = v_order_id
    ) then
        raise exception 'заказ % должен содержать хотя бы одну позицию', v_order_id;
    end if;

    return null;
end;
$$;

create constraint trigger trg_order_has_items
after insert on stodelov_food."order"
deferrable initially deferred
for each row
execute function stodelov_food.check_order_has_items();

create constraint trigger trg_order_structure_has_items
after delete or update of order_id
on stodelov_food.order_structure
deferrable initially deferred
for each row
execute function stodelov_food.check_order_has_items();

create or replace function stodelov_food.lock_order_for_items()
returns trigger
language plpgsql
as $$
begin
    if tg_op = 'INSERT' then
        perform 1
        from stodelov_food."order"
        where order_id = new.order_id
        for no key update;

        return new;

    elsif tg_op = 'DELETE' then
        perform 1
        from stodelov_food."order"
        where order_id = old.order_id
        for no key update;

        return old;

    else
        perform 1
        from stodelov_food."order"
        where order_id in (old.order_id, new.order_id)
        order by order_id
        for no key update;

        return new;
    end if;
end;
$$;

create trigger trg_order_structure_lock_items
before insert or update of order_id or delete
on stodelov_food.order_structure
for each row
execute function stodelov_food.lock_order_for_items();


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


create or replace procedure stodelov_food.erase_test_data()
language plpgsql
as $$
begin
    delete from stodelov_food.review;
    delete from stodelov_food.payment;
    delete from stodelov_food.order_structure;
    delete from stodelov_food.courier_pay;
    delete from stodelov_food."order";
    delete from stodelov_food.product;
    delete from stodelov_food.client_address;
    delete from stodelov_food.restaurant;
    delete from stodelov_food.product_category;
    delete from stodelov_food.courier;
    delete from stodelov_food.client;
    delete from stodelov_food.address;
end;
$$;

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




commit;




