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
