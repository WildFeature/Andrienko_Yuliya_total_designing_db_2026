-- 03_functions.sql
SET search_path TO andrienko_food, exts;

CREATE OR REPLACE PROCEDURE erase_test_data()
LANGUAGE sql
AS $$
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
$$;

CREATE OR REPLACE PROCEDURE add_product(
    p_restaurant_id uuid,
    p_product_category_id uuid,
    p_name varchar,
    p_price numeric,
    p_description text,
    p_rating numeric DEFAULT NULL,
    p_status product_status DEFAULT 'доступно',
    p_photo_url text DEFAULT NULL
)
LANGUAGE sql
AS $$
    INSERT INTO product (
        restaurant_id,
        product_category_id,
        product_name,
        price,
        description,
        rating,
        status,
        photo_url
    )
    VALUES (
        p_restaurant_id,
        p_product_category_id,
        p_name,
        p_price,
        p_description,
        p_rating,
        p_status,
        p_photo_url
    );
$$;

CREATE OR REPLACE FUNCTION get_statistic()
RETURNS TABLE (
    restaurant_name text,
    best_product_name text,
    total_amount numeric,
    avg_amount numeric,
    best_user text
)
LANGUAGE sql
STABLE
AS $$
    WITH delivered_orders AS (
        SELECT
            order_id,
            restaurant_id,
            client_id,
            total_amount
        FROM "order"
        WHERE status = 'доставлен'
    ),
    rest_stats AS (
        SELECT
            restaurant_id,
            sum(total_amount) AS total_amount,
            avg(total_amount) AS avg_amount
        FROM delivered_orders
        GROUP BY restaurant_id
    ),
    prod_agg AS (
        SELECT
            d.restaurant_id,
            p.product_id,
            p.product_name,
            sum(os.quantity) AS qty
        FROM delivered_orders d
        JOIN order_structure os ON os.order_id = d.order_id
        JOIN product p ON p.product_id = os.product_id
        GROUP BY d.restaurant_id, p.product_id, p.product_name
    ),
    best_prod AS (
        SELECT
            restaurant_id,
            (array_agg(product_name ORDER BY qty DESC, product_id))[1] AS best_product_name
        FROM prod_agg
        GROUP BY restaurant_id
    ),
    user_agg AS (
        SELECT
            d.restaurant_id,
            c.client_id,
            c.login,
            count(*) AS cnt
        FROM delivered_orders d
        JOIN client c ON c.client_id = d.client_id
        GROUP BY d.restaurant_id, c.client_id, c.login
    ),
    best_usr AS (
        SELECT
            restaurant_id,
            (array_agg(login ORDER BY cnt DESC, client_id))[1] AS best_user
        FROM user_agg
        GROUP BY restaurant_id
    )
    SELECT
        r.restaurant_name::text,
        bp.best_product_name::text,
        COALESCE(rs.total_amount, 0),
        COALESCE(rs.avg_amount, 0),
        bu.best_user::text
    FROM restaurant r
    LEFT JOIN rest_stats rs ON rs.restaurant_id = r.restaurant_id
    LEFT JOIN best_prod bp ON bp.restaurant_id = r.restaurant_id
    LEFT JOIN best_usr bu ON bu.restaurant_id = r.restaurant_id;
$$;


CREATE OR REPLACE PROCEDURE courier_salary()
LANGUAGE plpgsql
SET search_path TO andrienko_food, exts
AS $$
DECLARE
    rec record;
    v_count int;
    v_new_coeff numeric(3,2);
    v_amount numeric(10,2);
    v_year int := extract(year FROM current_date)::int;
    v_month int := extract(month FROM current_date)::int;
BEGIN
    FOR rec IN
        SELECT courier_id, coefficient, status
        FROM courier
    LOOP
        SELECT
            count(*),
            COALESCE(sum(commission), 0)
        INTO v_count, v_amount
        FROM "order"
        WHERE courier_id = rec.courier_id
          AND status = 'доставлен'
          AND extract(year FROM order_timestamp) = v_year
          AND extract(month FROM order_timestamp) = v_month;

        v_amount := round(v_amount * rec.coefficient, 2);

        INSERT INTO courier_pay (year, month, courier_id, amount, coefficient_used)
        VALUES (v_year, v_month, rec.courier_id, v_amount, rec.coefficient)
        ON CONFLICT (year, month, courier_id)
        DO UPDATE SET
            amount = EXCLUDED.amount,
            coefficient_used = EXCLUDED.coefficient_used;

        IF rec.status <> 'уволен' THEN
            v_new_coeff := CASE
                WHEN v_count <= 150 THEN 0.1
                WHEN v_count <= 250 THEN 0.2
                WHEN v_count <= 500 THEN 0.3
                ELSE 0.5
            END;

            UPDATE courier
            SET coefficient = v_new_coeff
            WHERE courier_id = rec.courier_id;
        END IF;
    END LOOP;
END;
$$;

CREATE OR REPLACE PROCEDURE insert_test_data(value int)
LANGUAGE plpgsql
SET search_path TO andrienko_food, exts
AS $$
DECLARE
    v_alphabet text := 'абвгдеёжзийклмнопрстуфхцчшщъыьэюя';
    i int;
    j int;
    v_idx int;
    v_id uuid;

    v_cat_ids uuid[] := '{}';
    v_cour_ids uuid[] := '{}';
    v_rest_addr_ids uuid[] := '{}';
    v_client_addr_ids uuid[] := '{}';
    v_rest_ids uuid[] := '{}';
    v_client_ids uuid[] := '{}';
    v_prod_ids uuid[] := '{}';
    v_prod_rest_ids uuid[] := '{}';
    v_prod_prices numeric[] := '{}';

    v_cour_statuses courier_status[];
    v_cour_status courier_status;
    v_hire_date date;
    v_dismissal_date date;
    v_coeff numeric(3,2);

    v_work_start time;
    v_work_end time;

    v_client_id uuid;
    v_addr_id uuid;
    v_rest_id uuid;
    v_cour_id uuid;
    v_order_id uuid;

    v_rest_prods uuid[];
    v_rest_prices numeric[];
    v_chosen_prods uuid[];
    v_chosen_qtys numeric[];
    v_items_cnt int;
    v_prod_idx int;
    v_qty numeric(5,3);
    v_price numeric(6,2);

    v_order_amount numeric(10,2);
    v_commission numeric(10,2);
    v_total_amount numeric(10,2);
    v_order_ts timestamp;
    v_deliv_ts timestamp;
    v_order_status order_status;
    v_pay_status order_pay_status;
    v_pay_type payment_type;
    v_p_status payment_status;

    v_order_statuses order_status[] := enum_range(NULL::order_status);
    v_pay_statuses order_pay_status[] := enum_range(NULL::order_pay_status);
    v_pay_types payment_type[] := enum_range(NULL::payment_type);
    v_prod_statuses product_status[] := enum_range(NULL::product_status);
    v_rest_statuses restaurant_status[] := enum_range(NULL::restaurant_status);
    v_review_types review_entity_type[] := enum_range(NULL::review_entity_type);

    v_rev_type review_entity_type;
    v_rev_entity_id uuid;
    v_rev_keys text[] := '{}';
    v_rev_key text;
    v_rev_created int := 0;
    v_attempts int := 0;

    v_deliv_orders uuid[] := '{}';
    v_deliv_clients uuid[] := '{}';
    v_deliv_rests uuid[] := '{}';

    v_month_rec record;
    v_comm_sum numeric(10,2);
    v_deliv_cnt int;
BEGIN
    IF value IS NULL OR value <= 0 THEN
        RETURN;
    END IF;

    -- 1. Справочник категорий (value * 1)
    FOR i IN 1..value LOOP
        INSERT INTO product_category (product_category_id, product_category_name)
        VALUES (
            exts.uuid_generate_v4(),
            repeat(
                substring(v_alphabet, 1, greatest(1, ceil(random() * 15)::int)),
                greatest(1, ceil(random() * 2)::int)
            ) || '_' || substr(md5(random()::text || clock_timestamp()::text), 1, 8)
        )
        RETURNING product_category_id INTO v_id;

        v_cat_ids := array_append(v_cat_ids, v_id);
    END LOOP;

    -- 2. Курьеры (value * 1, минимум один активный по BR-6.6)
    v_cour_statuses := enum_range(NULL::courier_status);
    FOR i IN 1..value LOOP
        IF i = 1 THEN
            v_cour_status := 'свободен'::courier_status;
        ELSE
            v_cour_status := v_cour_statuses[greatest(1, ceil(random() * cardinality(v_cour_statuses))::int)];
        END IF;

        v_hire_date := current_date - (180 + floor(random() * 365)::int);
        IF v_cour_status = 'уволен'::courier_status THEN
            v_dismissal_date := greatest(v_hire_date, current_date - floor(random() * 150)::int);
        ELSE
            v_dismissal_date := NULL;
        END IF;

        INSERT INTO courier (
            courier_id, last_name, first_name, middle_name,
            phone_number, status, hire_date, dismissal_date, coefficient
        )
        VALUES (
            exts.uuid_generate_v4(),
            repeat(substring(v_alphabet, 1, greatest(1, ceil(random() * 12)::int)), greatest(1, ceil(random() * 2)::int)),
            repeat(substring(v_alphabet, 1, greatest(1, ceil(random() * 10)::int)), 1),
            CASE WHEN random() > 0.3
                 THEN repeat(substring(v_alphabet, 1, greatest(1, ceil(random() * 12)::int)), 1)
                 ELSE NULL
            END,
            '7' || substr(replace(exts.uuid_generate_v4()::text, '-', ''), 1, 10),
            v_cour_status,
            v_hire_date,
            v_dismissal_date,
            0.1
        )
        RETURNING courier_id INTO v_id;

        v_cour_ids := array_append(v_cour_ids, v_id);
    END LOOP;

    -- 3. Адреса (value * 5: первые value под рестораны, остальные value * 4 под клиентов по BR-11.7)
    FOR i IN 1..(value * 5) LOOP
        INSERT INTO address (address_id, street, house_number, apartment_office)
        VALUES (
            exts.uuid_generate_v4(),
            repeat(substring(v_alphabet, 1, greatest(1, ceil(random() * 15)::int)), greatest(1, ceil(random() * 2)::int)),
            greatest(1, ceil(random() * 200)::int)::text,
            CASE WHEN random() > 0.35
                 THEN greatest(1, ceil(random() * 300)::int)::text
                 ELSE NULL
            END
        )
        RETURNING address_id INTO v_id;

        IF i <= value THEN
            v_rest_addr_ids := array_append(v_rest_addr_ids, v_id);
        ELSE
            v_client_addr_ids := array_append(v_client_addr_ids, v_id);
        END IF;
    END LOOP;

    -- 4. Рестораны (value * 1, work_end гарантированно <= 22:00:00 > work_start)
    FOR i IN 1..value LOOP
        v_work_start := ('08:00'::time + (floor(random() * 4)::int * interval '1 hour'))::time;
        v_work_end   := (v_work_start + ((8 + floor(random() * 4)::int) * interval '1 hour'))::time;

        INSERT INTO restaurant (
            restaurant_id, restaurant_name, address_id, description,
            work_start, work_end, inn, kpp, ogrn, bank_account, bik, rating, status
        )
        VALUES (
            exts.uuid_generate_v4(),
            repeat(substring(v_alphabet, 1, greatest(1, ceil(random() * 15)::int)), greatest(1, ceil(random() * 2)::int)),
            v_rest_addr_ids[i],
            repeat(substring(v_alphabet, 1, greatest(1, ceil(random() * 30)::int)), greatest(1, ceil(random() * 3)::int)),
            v_work_start,
            v_work_end,
            lpad(floor(random() * 10000000000)::bigint::text, 10, '0'),
            CASE WHEN random() > 0.2 THEN lpad(floor(random() * 1000000000)::bigint::text, 9, '0') ELSE NULL END,
            lpad(floor(random() * 10000000000000)::bigint::text, 13, '0'),
            lpad(floor(random() * 10000000000)::bigint::text, 10, '0') || lpad(floor(random() * 10000000000)::bigint::text, 10, '0'),
            lpad(floor(random() * 1000000000)::bigint::text, 9, '0'),
            NULL,
            CASE WHEN i = 1 THEN 'активен'::restaurant_status
                 ELSE v_rest_statuses[greatest(1, ceil(random() * cardinality(v_rest_statuses))::int)]
            END
        )
        RETURNING restaurant_id INTO v_id;

        v_rest_ids := array_append(v_rest_ids, v_id);
    END LOOP;

    -- 5. Клиенты (value * 1)
    FOR i IN 1..value LOOP
        INSERT INTO client (client_id, login, password, phone_number)
        VALUES (
            exts.uuid_generate_v4(),
            substring(md5(random()::text || clock_timestamp()::text), 1, 12) || '_' || i,
            md5(random()::text),
            '7' || substr(replace(exts.uuid_generate_v4()::text, '-', ''), 1, 10)
        )
        RETURNING client_id INTO v_id;

        v_client_ids := array_append(v_client_ids, v_id);
    END LOOP;

    -- 6. Связь client_address (используем все value * 4 клиентских адресов без дублей)
    FOR i IN 1..array_length(v_client_addr_ids, 1) LOOP
        v_client_id := v_client_ids[((i - 1) % value) + 1];
        INSERT INTO client_address (client_id, address_id)
        VALUES (v_client_id, v_client_addr_ids[i])
        ON CONFLICT DO NOTHING;
    END LOOP;

    FOR i IN 1..value LOOP
        v_client_id := v_client_ids[i];
        FOR j IN 1..floor(random() * 2)::int LOOP
            v_addr_id := v_client_addr_ids[greatest(1, ceil(random() * array_length(v_client_addr_ids, 1))::int)];
            INSERT INTO client_address (client_id, address_id)
            VALUES (v_client_id, v_addr_id)
            ON CONFLICT DO NOTHING;
        END LOOP;
    END LOOP;

    -- 7. Блюда (value * 5: цена 200..1000 ₽ исключает переполнение numeric(5,3) в количестве)
    FOR i IN 1..(value * 5) LOOP
        IF i <= value THEN
            v_rest_id := v_rest_ids[i];
        ELSE
            v_rest_id := v_rest_ids[greatest(1, ceil(random() * value)::int)];
        END IF;

        v_idx := greatest(1, ceil(random() * value)::int);
        v_price := round((200 + random() * 800)::numeric, 2);

        INSERT INTO product (
            product_id, product_name, product_category_id, price,
            restaurant_id, photo_url, rating, status, description
        )
        VALUES (
            exts.uuid_generate_v4(),
            repeat(substring(v_alphabet, 1, greatest(1, ceil(random() * 15)::int)), greatest(1, ceil(random() * 2)::int)),
            v_cat_ids[v_idx],
            v_price,
            v_rest_id,
            CASE WHEN random() > 0.3
                 THEN 'https://cdn.foodexpress.ru/img/' || md5(random()::text) || '.jpg'
                 ELSE NULL
            END,
            NULL,
            v_prod_statuses[greatest(1, ceil(random() * cardinality(v_prod_statuses))::int)],
            repeat(substring(v_alphabet, 1, greatest(1, ceil(random() * 25)::int)), greatest(1, ceil(random() * 3)::int))
        )
        RETURNING product_id INTO v_id;

        v_prod_ids := array_append(v_prod_ids, v_id);
        v_prod_rest_ids := array_append(v_prod_rest_ids, v_rest_id);
        v_prod_prices := array_append(v_prod_prices, v_price);
    END LOOP;

    -- 8. Заказы (value * 5), состав заказа (order_structure) и оплаты (payment: value * 5)
    FOR i IN 1..(value * 5) LOOP
        v_client_id := v_client_ids[greatest(1, ceil(random() * value)::int)];

        SELECT address_id INTO v_addr_id
        FROM client_address
        WHERE client_id = v_client_id
        LIMIT 1;

        v_rest_id := v_rest_ids[greatest(1, ceil(random() * value)::int)];
        v_cour_id := v_cour_ids[greatest(1, ceil(random() * value)::int)];

        v_rest_prods := '{}';
        v_rest_prices := '{}';
        FOR j IN 1..array_length(v_prod_ids, 1) LOOP
            IF v_prod_rest_ids[j] = v_rest_id THEN
                v_rest_prods := array_append(v_rest_prods, v_prod_ids[j]);
                v_rest_prices := array_append(v_rest_prices, v_prod_prices[j]);
            END IF;
        END LOOP;

        v_items_cnt := least(array_length(v_rest_prods, 1), greatest(1, ceil(random() * 5)::int));
        v_chosen_prods := '{}';
        v_chosen_qtys := '{}';
        v_order_amount := 0;

        WHILE array_length(v_chosen_prods, 1) IS NULL OR array_length(v_chosen_prods, 1) < v_items_cnt LOOP
            v_prod_idx := greatest(1, ceil(random() * array_length(v_rest_prods, 1))::int);
            IF NOT (v_rest_prods[v_prod_idx] = ANY(v_chosen_prods)) THEN
                v_qty := round((0.5 + random() * 2.5)::numeric, 2);
                v_chosen_prods := array_append(v_chosen_prods, v_rest_prods[v_prod_idx]);
                v_chosen_qtys := array_append(v_chosen_qtys, v_qty);
                v_order_amount := v_order_amount + round(v_rest_prices[v_prod_idx] * v_qty, 2);
            END IF;
        END LOOP;

        -- Гарантируем минимальную сумму заказа >= 1000 ₽ (BR-1.8 / BR-7.11)
        IF v_order_amount < 910 THEN
            v_idx := 1;
            v_qty := ceil((910.0 - v_order_amount) / v_rest_prices[v_idx]);
            IF v_rest_prods[v_idx] = ANY(v_chosen_prods) THEN
                FOR j IN 1..array_length(v_chosen_prods, 1) LOOP
                    IF v_chosen_prods[j] = v_rest_prods[v_idx] THEN
                        v_chosen_qtys[j] := v_chosen_qtys[j] + v_qty;
                    END IF;
                END LOOP;
            ELSE
                v_chosen_prods := array_append(v_chosen_prods, v_rest_prods[v_idx]);
                v_chosen_qtys := array_append(v_chosen_qtys, v_qty);
            END IF;
            v_order_amount := v_order_amount + round(v_rest_prices[v_idx] * v_qty, 2);
        END IF;

        v_commission := round(v_order_amount * 0.10, 2);
        v_total_amount := round(v_order_amount + v_commission, 2);

        v_order_ts := localtimestamp - (random() * 179)::int * interval '1 day' - (random() * 12)::int * interval '1 hour';
        v_order_status := v_order_statuses[greatest(1, ceil(random() * cardinality(v_order_statuses))::int)];
        IF i <= (value * 2) THEN
            v_order_status := 'доставлен'::order_status;
        END IF;

        IF v_order_status = 'доставлен'::order_status THEN
            v_deliv_ts := v_order_ts + (greatest(15, ceil(random() * 90)::int) * interval '1 minute');
            v_pay_status := 'оплачен'::order_pay_status;
        ELSE
            v_deliv_ts := NULL;
            v_pay_status := v_pay_statuses[greatest(1, ceil(random() * cardinality(v_pay_statuses))::int)];
        END IF;

        v_order_id := exts.uuid_generate_v4();

        INSERT INTO "order" (
            order_id, courier_id, client_id, address_id, restaurant_id,
            order_timestamp, delivery_timestamp,
            order_amount, commission, total_amount,
            status, pay_status, description
        )
        VALUES (
            v_order_id, v_cour_id, v_client_id, v_addr_id, v_rest_id,
            v_order_ts, v_deliv_ts,
            v_order_amount, v_commission, v_total_amount,
            v_order_status, v_pay_status,
            CASE WHEN random() > 0.5
                 THEN repeat(substring(v_alphabet, 1, greatest(1, ceil(random() * 20)::int)), 1)
                 ELSE NULL
            END
        );

        FOR j IN 1..array_length(v_chosen_prods, 1) LOOP
            INSERT INTO order_structure (order_id, product_id, quantity)
            VALUES (v_order_id, v_chosen_prods[j], v_chosen_qtys[j]);
        END LOOP;

        v_pay_type := v_pay_types[greatest(1, ceil(random() * cardinality(v_pay_types))::int)];
        v_p_status := CASE v_pay_status
            WHEN 'оплачен'::order_pay_status THEN 'успех'::payment_status
            WHEN 'ошибка'::order_pay_status THEN 'ошибка'::payment_status
            ELSE 'в_обработке'::payment_status
        END;

        INSERT INTO payment (
            payment_id, order_id, payment_type, amount,
            transaction_id, transaction_time, status
        )
        VALUES (
            exts.uuid_generate_v4(),
            v_order_id,
            v_pay_type,
            v_total_amount,
            'txn_' || md5(random()::text || clock_timestamp()::text || i::text),
            v_order_ts + interval '2 minutes',
            v_p_status
        );

        IF v_order_status = 'доставлен'::order_status THEN
            v_deliv_orders := array_append(v_deliv_orders, v_order_id);
            v_deliv_clients := array_append(v_deliv_clients, v_client_id);
            v_deliv_rests := array_append(v_deliv_rests, v_rest_id);
        END IF;
    END LOOP;

    -- 9. Отзывы (value * 5: 'блюдо', 'ресторан' и 'заказ' без дублей по BR-9.5)
    WHILE v_rev_created < (value * 5) AND v_attempts < (value * 200) AND array_length(v_deliv_orders, 1) IS NOT NULL LOOP
        v_attempts := v_attempts + 1;
        v_idx := greatest(1, ceil(random() * array_length(v_deliv_orders, 1))::int);
        v_order_id := v_deliv_orders[v_idx];
        v_client_id := v_deliv_clients[v_idx];
        v_rest_id := v_deliv_rests[v_idx];

        v_rev_type := v_review_types[greatest(1, ceil(random() * cardinality(v_review_types))::int)];

        IF v_rev_type = 'заказ'::review_entity_type THEN
            v_rev_entity_id := v_order_id;
        ELSIF v_rev_type = 'ресторан'::review_entity_type THEN
            v_rev_entity_id := v_rest_id;
        ELSE
            SELECT product_id INTO v_rev_entity_id
            FROM order_structure
            WHERE order_id = v_order_id
            ORDER BY random()
            LIMIT 1;
        END IF;

        v_rev_key := v_order_id::text || ':' || v_rev_type::text || ':' || v_rev_entity_id::text;

        IF NOT (v_rev_key = ANY(v_rev_keys)) THEN
            v_rev_keys := array_append(v_rev_keys, v_rev_key);
            v_rev_created := v_rev_created + 1;

            INSERT INTO review (
                review_id, client_id, review_timestamp,
                entity_id, entity_type, order_id,
                description, photo_url, rating
            )
            VALUES (
                exts.uuid_generate_v4(),
                v_client_id,
                localtimestamp - (random() * 150)::int * interval '1 day',
                v_rev_entity_id,
                v_rev_type,
                v_order_id,
                repeat(substring(v_alphabet, 1, greatest(1, ceil(random() * 25)::int)), greatest(1, ceil(random() * 2)::int)),
                CASE WHEN random() > 0.5
                     THEN 'https://cdn.foodexpress.ru/img/' || md5(random()::text) || '.jpg'
                     ELSE NULL
                END,
                greatest(1, ceil(random() * 5)::int)::numeric(2,1)
            );
        END IF;
    END LOOP;

    -- 10. Зарплата курьеров за последние 6 месяцев согласованно с BR-10.2 и FOOD-102
    FOR i IN 1..array_length(v_cour_ids, 1) LOOP
        v_cour_id := v_cour_ids[i];
        v_coeff := 0.1;

        FOR v_month_rec IN
            SELECT
                extract(year  FROM m)::int AS y,
                extract(month FROM m)::int AS m
            FROM generate_series(
                date_trunc('month', current_date - interval '5 months'),
                date_trunc('month', current_date),
                interval '1 month'
            ) AS m
            ORDER BY m
        LOOP
            SELECT
                count(*),
                COALESCE(sum(commission), 0)
            INTO v_deliv_cnt, v_comm_sum
            FROM "order"
            WHERE courier_id = v_cour_id
              AND status = 'доставлен'
              AND extract(year FROM order_timestamp) = v_month_rec.y
              AND extract(month FROM order_timestamp) = v_month_rec.m;

            INSERT INTO courier_pay (year, month, courier_id, amount, coefficient_used)
            VALUES (
                v_month_rec.y,
                v_month_rec.m,
                v_cour_id,
                round(v_comm_sum * v_coeff, 2),
                v_coeff
            )
            ON CONFLICT (year, month, courier_id)
            DO UPDATE SET
                amount = EXCLUDED.amount,
                coefficient_used = EXCLUDED.coefficient_used;

            v_coeff := CASE
                WHEN v_deliv_cnt <= 150 THEN 0.1
                WHEN v_deliv_cnt <= 250 THEN 0.2
                WHEN v_deliv_cnt <= 500 THEN 0.3
                ELSE 0.5
            END;
        END LOOP;

        UPDATE courier
        SET coefficient = v_coeff
        WHERE courier_id = v_cour_id
          AND status <> 'уволен'::courier_status;
    END LOOP;
END;
$$;
