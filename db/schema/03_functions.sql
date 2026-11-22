-- 03_functions.sql
SET search_path TO andrienko_food, exts;

CREATE OR REPLACE PROCEDURE erase_test_data()
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM review;
    DELETE FROM payment;
    DELETE FROM order_structure;
    DELETE FROM "order";
    DELETE FROM courier_pay;
    DELETE FROM product;
    DELETE FROM product_category;
    DELETE FROM restaurant;
    DELETE FROM client_address;
    DELETE FROM courier;
    DELETE FROM client;
    DELETE FROM address;
END;
$$;

CREATE OR REPLACE PROCEDURE insert_test_data(value int)
LANGUAGE plpgsql
AS $$
DECLARE
    i int;
    j int;
    rec record;
    v_client_id uuid;
    v_addr_id uuid;
    v_rest_id uuid;
    v_cour_id uuid;
    v_cat_id uuid;
    v_prod_id uuid;
    v_order_id uuid;
    v_amount numeric(12,2);
    v_comm numeric(12,2);
    v_total numeric(12,2);
    v_ts timestamp;
    v_deliv_ts timestamp;
    v_status order_status;
    v_pay order_pay_status;
    v_cour_status courier_status;
    v_dismissal date;
    v_year int;
    v_month int;
BEGIN
    -- Клиенты (телефон уникальный через i)
    FOR i IN 1..value LOOP
        INSERT INTO client (login, password, phone_number)
        VALUES (
            'client' || i || '_' || substr(md5(random()::text || clock_timestamp()::text), 1, 6),
            md5(random()::text),
            '79' || lpad((100000000 + i + floor(random()*1000))::text, 9, '0')
        ) ON CONFLICT (phone_number) DO NOTHING;
    END LOOP;

    -- Адреса
    FOR i IN 1..(value*5) LOOP
        INSERT INTO address (street, house_number, apartment_office)
        VALUES (
            'ул. ' || (ARRAY['Ленина','Мира','Пушкина','Гагарина','Советская'])[1+floor(random()*5)::int] || ' ' || i,
            (1+floor(random()*150))::text,
            CASE WHEN random() > 0.4 THEN (1+floor(random()*80))::text ELSE NULL END
        );
    END LOOP;

    -- Курьеры (телефон уникальный + правильная дата увольнения)
    FOR i IN 1..value LOOP
        v_cour_status := (enum_range(NULL::courier_status))[1 + floor(random()*4)::int];
        v_dismissal := CASE WHEN v_cour_status = 'уволен' THEN current_date - (floor(random()*60))::int ELSE NULL END;

        INSERT INTO courier (fio, phone_number, status, hire_date, dismissal_date, coefficient)
        VALUES (
            'Курьер ' || i,
            '78' || lpad((100000000 + i + floor(random()*1000))::text, 9, '0'),
            v_cour_status,
            current_date - (30 + floor(random()*150))::int,
            v_dismissal,
            0.1 + floor(random()*4)*0.1
        ) ON CONFLICT (phone_number) DO NOTHING;
    END LOOP;

    UPDATE courier SET status = 'свободен', dismissal_date = NULL
    WHERE ctid = (SELECT ctid FROM courier LIMIT 1);

    -- Категории
    FOR i IN 1..value LOOP
        INSERT INTO product_category (product_category_name)
        VALUES ('Категория_' || i || '_' || substr(md5(random()::text),1,4));
    END LOOP;

    -- Рестораны
    FOR i IN 1..value LOOP
        SELECT address_id INTO v_addr_id FROM address OFFSET (i-1) LIMIT 1;
        INSERT INTO restaurant (restaurant_name, address_id, description, work_start, work_end, company_details, status)
        VALUES (
            'Ресторан ' || i, v_addr_id, 'Описание ресторана ' || i,
            '09:00'::time + (floor(random()*3)||' hours')::interval,
            '21:00'::time + (floor(random()*2)||' hours')::interval,
            'ИНН ' || (1000000000 + floor(random()*900000000))::text, 'активен'
        );
    END LOOP;

    -- Продукты
    FOR i IN 1..(value*5) LOOP
        SELECT restaurant_id INTO v_rest_id FROM restaurant ORDER BY random() LIMIT 1;
        SELECT product_category_id INTO v_cat_id FROM product_category ORDER BY random() LIMIT 1;
        INSERT INTO product (product_name, product_category_id, price, restaurant_id, status, description)
        VALUES (
            'Блюдо ' || i, v_cat_id, round((100 + random()*900)::numeric, 2),
            v_rest_id, (enum_range(NULL::product_status))[1 + floor(random()*3)::int],
            'Описание блюда ' || i
        );
    END LOOP;

    -- client_address (гарантируем хотя бы 1 адрес на клиента)
    FOR rec IN SELECT client_id FROM client LOOP
        FOR j IN 1..2 LOOP
            SELECT address_id INTO v_addr_id
            FROM address
            WHERE address_id NOT IN (SELECT address_id FROM restaurant)
              AND address_id NOT IN (SELECT address_id FROM client_address WHERE client_id = rec.client_id)
            ORDER BY random() LIMIT 1;
            IF v_addr_id IS NOT NULL THEN
                INSERT INTO client_address (client_id, address_id) VALUES (rec.client_id, v_addr_id)
                ON CONFLICT DO NOTHING;
            END IF;
        END LOOP;
    END LOOP;

    -- Заказы
    FOR i IN 1..(value*5) LOOP
        SELECT client_id INTO v_client_id FROM client ORDER BY random() LIMIT 1;
        SELECT address_id INTO v_addr_id FROM client_address WHERE client_id = v_client_id ORDER BY random() LIMIT 1;
        IF v_addr_id IS NULL THEN CONTINUE; END IF;

        SELECT restaurant_id INTO v_rest_id FROM restaurant ORDER BY random() LIMIT 1;
        SELECT courier_id INTO v_cour_id FROM courier WHERE status <> 'уволен' ORDER BY random() LIMIT 1;
        IF v_cour_id IS NULL THEN CONTINUE; END IF;

        v_amount := round((900 + random()*3000)::numeric, 2);
        v_comm := round(v_amount * 0.10, 2);
        v_total := v_amount + v_comm;
        IF v_total < 1000 THEN 
            v_total := 1000; 
            v_amount := round(v_total / 1.1, 2); 
            v_comm := v_total - v_amount; 
        END IF;

        v_ts := now() - (random()*180 || ' days')::interval;
        v_status := (enum_range(NULL::order_status))[1 + floor(random()*5)::int];
        v_deliv_ts := CASE WHEN v_status = 'доставлен' THEN v_ts + (random()*120 || ' minutes')::interval ELSE NULL END;
        v_pay := CASE WHEN random() > 0.15 THEN 'оплачен' ELSE 'ожидает' END;

        INSERT INTO "order" (courier_id, client_id, address_id, restaurant_id,
                             order_timestamp, delivery_timestamp,
                             order_amount, commission, total_amount, status, pay_status)
        VALUES (v_cour_id, v_client_id, v_addr_id, v_rest_id,
                v_ts, v_deliv_ts, v_amount, v_comm, v_total, v_status, v_pay)
        RETURNING order_id INTO v_order_id;

        -- Позиции (гарантируем хотя бы одну)
        FOR j IN 1..(1+floor(random()*3))::int LOOP
            SELECT product_id INTO v_prod_id FROM product WHERE restaurant_id = v_rest_id ORDER BY random() LIMIT 1;
            IF v_prod_id IS NOT NULL THEN
                INSERT INTO order_structure (order_id, product_id, quantity)
                VALUES (v_order_id, v_prod_id, round((0.5 + random()*3)::numeric, 2))
                ON CONFLICT DO NOTHING;
            END IF;
        END LOOP;

        INSERT INTO payment (order_id, payment_type, amount, transaction_id, transaction_time, status)
        VALUES (v_order_id, (enum_range(NULL::payment_type))[1 + floor(random()*3)::int],
                v_total, 'TXN-' || substr(md5(random()::text || i::text), 1, 16),
                v_ts + (random()*30 || ' minutes')::interval, 'успех');
    END LOOP;

    -- Отзывы (только если есть позиции)
    FOR i IN 1..(value*5) LOOP
        SELECT o.order_id, o.client_id INTO v_order_id, v_client_id
        FROM "order" o
        WHERE o.status = 'доставлен'
          AND EXISTS (SELECT 1 FROM order_structure os WHERE os.order_id = o.order_id)
        ORDER BY random() LIMIT 1;

        IF v_order_id IS NOT NULL THEN
            SELECT product_id INTO v_prod_id FROM order_structure WHERE order_id = v_order_id ORDER BY random() LIMIT 1;
            IF v_prod_id IS NOT NULL THEN
                INSERT INTO review (client_id, entity_id, entity_type, order_id, rating, description)
                VALUES (v_client_id, v_prod_id, 'блюдо', v_order_id, 1 + floor(random()*5), 'Отзыв ' || i);
            END IF;
        END IF;
    END LOOP;

    -- courier_pay
    FOR rec IN SELECT courier_id, coefficient FROM courier LOOP
        FOR m IN 0..5 LOOP
            v_year := extract(year from (current_date - (m || ' months')::interval))::int;
            v_month := extract(month from (current_date - (m || ' months')::interval))::int;
            SELECT COALESCE(sum(commission), 0) INTO v_comm
            FROM "order"
            WHERE courier_id = rec.courier_id AND status = 'доставлен'
              AND extract(year from order_timestamp) = v_year
              AND extract(month from order_timestamp) = v_month;

            INSERT INTO courier_pay (year, month, courier_id, amount, coefficient_used)
            VALUES (v_year, v_month, rec.courier_id, round(v_comm * rec.coefficient, 2), rec.coefficient)
            ON CONFLICT DO NOTHING;
        END LOOP;
    END LOOP;
END;
$$;

CREATE OR REPLACE PROCEDURE add_product(
    p_restaurant_id uuid, p_product_category_id uuid, p_name varchar, p_price numeric,
    p_rating numeric DEFAULT NULL, p_status product_status DEFAULT 'доступно',
    p_description text DEFAULT NULL, p_photo_url text DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO product (restaurant_id, product_category_id, product_name, price, rating, status, description, photo_url)
    VALUES (p_restaurant_id, p_product_category_id, p_name, p_price, p_rating, p_status, p_description, p_photo_url);
EXCEPTION
    WHEN foreign_key_violation THEN RAISE EXCEPTION 'Ресторан или категория не существуют';
    WHEN check_violation THEN RAISE EXCEPTION 'Нарушено ограничение (цена или рейтинг)';
END;
$$;

CREATE OR REPLACE PROCEDURE courier_salary()
LANGUAGE plpgsql
AS $$
DECLARE
    rec record; v_count int; v_new_coeff numeric(3,2); v_amount numeric(12,2);
    v_year int := extract(year from current_date)::int;
    v_month int := extract(month from current_date)::int;
BEGIN
    FOR rec IN SELECT courier_id, coefficient, status FROM courier LOOP
        SELECT count(*) INTO v_count FROM "order"
        WHERE courier_id = rec.courier_id AND status = 'доставлен'
          AND extract(year from order_timestamp) = v_year AND extract(month from order_timestamp) = v_month;

        v_amount := round(COALESCE((SELECT sum(commission) FROM "order"
            WHERE courier_id = rec.courier_id AND status = 'доставлен'
              AND extract(year from order_timestamp) = v_year AND extract(month from order_timestamp) = v_month), 0) * rec.coefficient, 2);

        INSERT INTO courier_pay (year, month, courier_id, amount, coefficient_used)
        VALUES (v_year, v_month, rec.courier_id, v_amount, rec.coefficient)
        ON CONFLICT (year, month, courier_id) DO UPDATE SET amount = EXCLUDED.amount, coefficient_used = EXCLUDED.coefficient_used;

        IF rec.status <> 'уволен' THEN
            v_new_coeff := CASE WHEN v_count <= 150 THEN 0.1 WHEN v_count <= 250 THEN 0.2 WHEN v_count <= 500 THEN 0.3 ELSE 0.5 END;
            UPDATE courier SET coefficient = v_new_coeff WHERE courier_id = rec.courier_id;
        END IF;
    END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION get_statistic()
RETURNS TABLE (
    restaurant_name text,
    best_product_name text,
    total_amount numeric,
    avg_amount numeric,
    best_user text
)
LANGUAGE sql STABLE
AS $$
    WITH delivered AS (
        SELECT o.restaurant_id, o.order_id, o.total_amount, o.client_id, os.product_id, os.quantity
        FROM "order" o JOIN order_structure os ON os.order_id = o.order_id
        WHERE o.status = 'доставлен'
    ),
    rest_stats AS (
        SELECT restaurant_id, sum(total_amount) AS total_amount, avg(total_amount) AS avg_amount
        FROM "order" WHERE status = 'доставлен' GROUP BY restaurant_id
    ),
    best_prod AS (
        SELECT DISTINCT ON (d.restaurant_id) d.restaurant_id, p.product_name
        FROM delivered d JOIN product p ON p.product_id = d.product_id
        GROUP BY d.restaurant_id, p.product_id, p.product_name
        ORDER BY d.restaurant_id, sum(d.quantity) DESC
    ),
    best_cli AS (
        SELECT DISTINCT ON (o.restaurant_id) o.restaurant_id, c.login
        FROM "order" o JOIN client c ON c.client_id = o.client_id
        WHERE o.status = 'доставлен'
        GROUP BY o.restaurant_id, c.client_id, c.login
        ORDER BY o.restaurant_id, count(*) DESC
    )
    SELECT r.restaurant_name::text,
           bp.product_name::text,
           rs.total_amount,
           rs.avg_amount,
           bc.login::text
    FROM restaurant r
    LEFT JOIN rest_stats rs ON rs.restaurant_id = r.restaurant_id
    LEFT JOIN best_prod bp ON bp.restaurant_id = r.restaurant_id
    LEFT JOIN best_cli bc ON bc.restaurant_id = r.restaurant_id;
$$;