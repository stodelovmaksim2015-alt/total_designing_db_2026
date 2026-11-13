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




commit;




