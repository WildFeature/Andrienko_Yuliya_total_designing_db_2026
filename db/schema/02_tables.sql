-- 02_tables.sql
SET search_path TO andrienko_food, exts;

CREATE TABLE client (
    client_id    uuid PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    login        varchar(50) NOT NULL UNIQUE,
    password     char(32)    NOT NULL,
    phone_number char(11)    NOT NULL UNIQUE
);

CREATE TABLE address (
    address_id       uuid PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    street           varchar(100) NOT NULL,
    house_number     varchar(20)  NOT NULL,
    apartment_office varchar(20)
);

CREATE TABLE client_address (
    client_id  uuid NOT NULL REFERENCES client(client_id),
    address_id uuid NOT NULL REFERENCES address(address_id),
    PRIMARY KEY (client_id, address_id)
);

CREATE TABLE restaurant (
    restaurant_id   uuid PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    restaurant_name varchar(100) NOT NULL,
    address_id      uuid NOT NULL UNIQUE REFERENCES address(address_id),
    description     text,
    work_start      time NOT NULL,
    work_end        time NOT NULL,
    company_details text,
    rating          numeric(3,2),
    status          restaurant_status NOT NULL,
    CONSTRAINT chk_rating_restaurant CHECK (rating IS NULL OR rating BETWEEN 0 AND 5),
    CONSTRAINT chk_work_time CHECK (work_end > work_start)
);

CREATE TABLE product_category (
    product_category_id   uuid PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    product_category_name varchar(50) NOT NULL UNIQUE
);

CREATE TABLE product (
    product_id          uuid PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    product_name        varchar(100) NOT NULL,
    product_category_id uuid NOT NULL REFERENCES product_category(product_category_id),
    price               numeric(10,2) NOT NULL CHECK (price >= 0),
    restaurant_id       uuid NOT NULL REFERENCES restaurant(restaurant_id),
    photo_url           text,
    rating              numeric(3,2),
    status              product_status NOT NULL,
    description         text,
    CONSTRAINT chk_rating_product CHECK (rating IS NULL OR rating BETWEEN 0 AND 5)
);

CREATE TABLE courier (
    courier_id     uuid PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    fio            varchar(100) NOT NULL,
    phone_number   char(11) NOT NULL UNIQUE,
    status         courier_status NOT NULL,
    hire_date      date NOT NULL,
    dismissal_date date,
    coefficient    numeric(3,2) NOT NULL DEFAULT 0.1
                   CHECK (coefficient BETWEEN 0.1 AND 0.5),
    CONSTRAINT chk_dismissal CHECK (
        (status = 'уволен' AND dismissal_date IS NOT NULL) OR
        (status <> 'уволен')
    )
);

CREATE TABLE courier_pay (
    year             int NOT NULL,
    month            int NOT NULL CHECK (month BETWEEN 1 AND 12),
    courier_id       uuid NOT NULL REFERENCES courier(courier_id),
    amount           numeric(12,2) NOT NULL CHECK (amount >= 0),
    coefficient_used numeric(3,2) NOT NULL,
    PRIMARY KEY (year, month, courier_id)
);

CREATE TABLE "order" (
    order_id           uuid PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    courier_id         uuid NOT NULL REFERENCES courier(courier_id),
    client_id          uuid NOT NULL REFERENCES client(client_id),
    address_id         uuid NOT NULL REFERENCES address(address_id),
    restaurant_id      uuid NOT NULL REFERENCES restaurant(restaurant_id),
    order_timestamp    timestamp NOT NULL DEFAULT now(),
    delivery_timestamp timestamp,
    order_amount       numeric(12,2) NOT NULL CHECK (order_amount >= 0),
    commission         numeric(12,2) NOT NULL CHECK (commission >= 0),
    total_amount       numeric(12,2) NOT NULL CHECK (total_amount >= 1000),
    status             order_status NOT NULL,
    pay_status         order_pay_status NOT NULL,
    description        text,
    CONSTRAINT chk_delivery_time CHECK (
        delivery_timestamp IS NULL OR delivery_timestamp >= order_timestamp
    ),
    CONSTRAINT chk_commission CHECK (round(order_amount * 0.10, 2) = commission),
    CONSTRAINT chk_total CHECK (round(order_amount + commission, 2) = total_amount)
);

CREATE TABLE order_structure (
    order_id   uuid NOT NULL REFERENCES "order"(order_id),
    product_id uuid NOT NULL REFERENCES product(product_id),
    quantity   numeric(8,3) NOT NULL CHECK (quantity > 0),
    PRIMARY KEY (order_id, product_id)
);

CREATE TABLE payment (
    payment_id       uuid PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    order_id         uuid NOT NULL REFERENCES "order"(order_id),
    payment_type     payment_type NOT NULL,
    amount           numeric(12,2) NOT NULL,
    transaction_id   varchar(100) NOT NULL UNIQUE,
    transaction_time timestamp NOT NULL,
    status           payment_status NOT NULL
);

CREATE TABLE review (
    review_id        uuid PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    client_id        uuid NOT NULL REFERENCES client(client_id),
    review_timestamp timestamp NOT NULL DEFAULT now(),
    entity_id        uuid NOT NULL,
    entity_type      review_entity_type NOT NULL,
    order_id         uuid NOT NULL REFERENCES "order"(order_id),
    description      text,
    photo_url        text,
    rating           numeric(2,1) NOT NULL CHECK (rating BETWEEN 1 AND 5)
);
