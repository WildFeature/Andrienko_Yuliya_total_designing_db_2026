# Обоснование ограничений

Схема: `andrienko_food` (FOOD-101)

## Enum-типы (BR-11.5)

| Тип | Значения | BR |
|-----|----------|----|
| `restaurant_status` | `'активен'`, `'неактивен'` | BR-4.3 |
| `product_status` | `'доступно'`, `'нет_в_наличии'`, `'архив'` | BR-5.5 |
| `courier_status` | `'свободен'`, `'занят'`, `'на_доставке'`, `'уволен'` | BR-6.2 |
| `order_status` | `'создан'`, `'готовится'`, `'в_доставке'`, `'доставлен'`, `'отменён'` | BR-7.7 |
| `order_pay_status` | `'ожидает'`, `'оплачен'`, `'ошибка'` | BR-7.9 |
| `payment_status` | `'успех'`, `'ошибка'`, `'в_обработке'` | BR-8.2 |
| `payment_type` | `'карта'`, `'наличные'`, `'безнал'` | BR-8.2 |
| `review_entity_type` | `'блюдо'`, `'ресторан'`, `'заказ'` | BR-9.1 |

## Первичные и внешние ключи (PK / FK)

- **Все таблицы:** первичные ключи `*_id` имеют тип `uuid` и генерируются по умолчанию через `exts.uuid_generate_v4()` (BR-11.1, BR-13.3).
- `client_address(client_id, address_id)` → `client(client_id)`, `address(address_id)` — связь M:N между клиентами и адресами доставки (BR-2.4, BR-3.4).
- `restaurant(address_id)` → `address(address_id)` с `UNIQUE` — у ресторана ровно один уникальный физический адрес (BR-3.3).
- `product(product_category_id)` → `product_category(product_category_id)` и `product(restaurant_id)` → `restaurant(restaurant_id)` — блюдо принадлежит одной категории и одному ресторану (BR-5.1).
- `"order"(courier_id, client_id, address_id, restaurant_id)` → соответствующие справочники — привязка заказа к клиенту, ресторану, курьеру и адресу доставки (BR-7.2, BR-7.4, BR-7.5). Таблица взята в кавычки `"order"`, так как `order` является зарезервированным словом SQL (BR-13.1).
- `order_structure(order_id, product_id)` → `"order"(order_id)`, `product(product_id)` — позиции заказа (BR-7.14).
- `payment(order_id)` → `"order"(order_id)` — попытки оплаты по заказу (BR-8.1, BR-8.6).
- `review(client_id)` → `client(client_id)` и `review(order_id)` → `"order"(order_id)` — отзыв привязан к клиенту и конкретному заказу (BR-9.2).

## Ловушки и правила данных

- **Ловушка 1 (`payment`):** Хранит отдельные попытки оплаты с типом (`payment_type`), суммой, внешним `transaction_id` и статусом (BR-8.2, BR-8.6).
- **Ловушка 2 (`order.address_id` принадлежит клиенту, BR-7.4):** В `insert_test_data` адрес заказа выбирается исключительно из `client_address` данного клиента.
- **Ловушка 3 (все блюда из одного ресторана, BR-7.3):** В `insert_test_data` позиции `order_structure` выбираются строго из блюд `restaurant_id` заказа.
- **Ловушка 4 (полиморфизм `review`):** `entity_id` ссылается на блюдо, ресторан или заказ в зависимости от `entity_type`. Валидность и отсутствие дублей `(order_id, entity_type, entity_id)` (BR-9.5) контролируются генератором и триггером `rating_change()` (FOOD-105).

## CHECK-ограничения

| Таблица | Условие | BR |
|---------|---------|----|
| `restaurant.rating` | `rating IS NULL OR rating BETWEEN 0 AND 5` | BR-4.2 |
| `restaurant.work_end` | `work_end > work_start` | BR-4.4 |
| `product.price` | `price >= 0` | BR-5.3 |
| `product.rating` | `rating IS NULL OR rating BETWEEN 0 AND 5` | BR-5.4 |
| `courier.coefficient` | `coefficient BETWEEN 0.1 AND 0.5` | BR-6.4 |
| `courier.dismissal_date` | `(status = 'уволен' AND dismissal_date IS NOT NULL) OR (status <> 'уволен')` | BR-6.3 |
| `"order".order_amount` | `order_amount >= 0` | BR-7.10 |
| `"order".commission` | `commission >= 0 AND round(order_amount * 0.10, 2) = commission` | BR-1.4 |
| `"order".total_amount` | `total_amount >= 1000 AND round(order_amount + commission, 2) = total_amount` | BR-1.8, BR-7.10, BR-7.11 |
| `"order".delivery_timestamp` | `delivery_timestamp IS NULL OR delivery_timestamp >= order_timestamp` | BR-7.13 |
| `order_structure.quantity` | `quantity > 0` | BR-7.15 |
| `review.rating` | `rating BETWEEN 1 AND 5` | BR-9.4 |
| `courier_pay.amount` | `amount >= 0` | BR-10.4 |
| `courier_pay.month` | `month BETWEEN 1 AND 12` | BR-10.2 |

## UNIQUE-ограничения

- `client.login`, `client.phone_number` — уникальность логина и телефона клиента (BR-2.2).
- `courier.phone_number` — уникальность номера телефона курьера (BR-6.1).
- `product_category.product_category_name` — уникальность названия категории (BR-5.7).
- `restaurant.address_id` — один адрес только у одного ресторана (BR-3.3).
- `payment.transaction_id` — уникальность внешнего идентификатора транзакции (BR-8.3).
- `client_address(client_id, address_id)` — запрет повторной привязки того же адреса клиенту (BR-2.5).
- `order_structure(order_id, product_id)` — одно блюдо в заказе встречается один раз (BR-7.16).
- `courier_pay(year, month, courier_id)` — одна запись начисления за месяц на курьера (BR-10.3).

## NULL разрешены (BR-11.3)

- `address.apartment_office` — может отсутствовать у частных домов (BR-3.2).
- `product.photo_url` — фотография блюда необязательна (BR-5.6).
- `product.rating`, `restaurant.rating` — `NULL` при отсутствии отзывов (BR-9.7).
- `courier.middle_name` — отчество может отсутствовать (BR-6.1).
- `courier.dismissal_date` — отсутствует у работающих курьеров (BR-6.3).
- `"order".delivery_timestamp` — заполняется только после доставки (BR-7.12).
- `"order".description` — комментарий к заказу необязателен.
- `review.description`, `review.photo_url` — текст и фото отзыва необязательны (BR-9.3).

## Нормализация (3НФ)

Все таблицы приведены к 3НФ: отсутствуют повторяющиеся группы (1НФ), все неключевые атрибуты полностью зависят от всего первичного ключа (2НФ), транзитивные зависимости устранены (3НФ). Поля `product.rating` и `restaurant.rating` являются осознанной денормализацией по требованию BR-9.6 и автоматически поддерживаются триггером `trg_rating_change` (FOOD-105).
