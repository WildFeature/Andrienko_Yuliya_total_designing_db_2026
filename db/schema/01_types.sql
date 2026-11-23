-- 01_types.sql
CREATE SCHEMA IF NOT EXISTS exts;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" SCHEMA exts;

CREATE SCHEMA IF NOT EXISTS andrienko_food;
SET search_path TO andrienko_food, exts;

CREATE TYPE restaurant_status AS ENUM ('активен', 'неактивен');
CREATE TYPE product_status AS ENUM ('доступно', 'нет_в_наличии', 'архив');
CREATE TYPE courier_status AS ENUM ('свободен', 'занят', 'на_доставке', 'уволен');
CREATE TYPE order_status AS ENUM ('создан', 'готовится', 'в_доставке', 'доставлен', 'отменён');
CREATE TYPE order_pay_status AS ENUM ('ожидает', 'оплачен', 'ошибка');
CREATE TYPE payment_status AS ENUM ('успех', 'ошибка', 'в_обработке');
CREATE TYPE payment_type AS ENUM ('карта', 'наличные', 'безнал');
CREATE TYPE review_entity_type AS ENUM ('блюдо', 'ресторан', 'заказ');
