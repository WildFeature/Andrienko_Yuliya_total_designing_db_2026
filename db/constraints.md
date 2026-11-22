# Обоснование ограничений

Схема: `andrienko_food`

## Enum-типы

| Тип | Значения | BR |
|-----|----------|----|
| restaurant_status | 'активен', 'неактивен' | BR-4.3 |
| product_status | 'доступно', 'нет_в_наличии', 'архив' | BR-5.5 |
| courier_status | 'свободен', 'занят', 'на_доставке', 'уволен' | BR-6.2 |
| order_status | 'создан', 'готовится', 'в_доставке', 'доставлен', 'отменён' | BR-7.7 |
| order_pay_status | 'ожидает', 'оплачен', 'ошибка' | BR-7.9 |
| payment_status | 'успех', 'ошибка', 'в_обработке' | BR-8.2 |
| payment_type | 'карта', 'наличные', 'безнал' | BR-8.2 |
| review_entity_type | 'блюдо', 'ресторан', 'заказ' | BR-9.1 |

## Ловушки

### Ловушка 1: payment
Добавлены все поля из BR-8.2. Тип оплаты хранится в payment (BR-8.6).

### Ловушка 2: order.address_id принадлежит клиенту (BR-7.4)
Контролируется в insert_test_data: адрес берётся только из client_address клиента.

### Ловушка 3: все блюда из одного ресторана (BR-7.3)
В insert_test_data продукты выбираются только из restaurant_id заказа.

### Ловушка 4: review полиморфизм
entity_id без FK. Валидность обеспечивается логикой генератора и триггером.

## CHECK-ограничения

| Таблица | Условие | BR |
|---------|---------|----|
| restaurant.rating | NULL или 0..5 | BR-4.2 |
| restaurant.work_end > work_start | | BR-4.4 |
| product.price >= 0 | | BR-5.3 |
| product.rating | NULL или 0..5 | BR-5.4 |
| courier.coefficient | 0.1..0.5 | BR-6.4 |
| courier dismissal | у уволенного есть дата | BR-6.3 |
| "order".total_amount >= 1000 | | BR-1.8 / BR-7.11 |
| "order" delivery_timestamp | >= order_timestamp или NULL | BR-7.13 |
| "order" commission = 10% | | BR-1.4 |
| "order" total = amount + commission | | BR-7.10 |
| order_structure.quantity > 0 | | BR-7.15 |
| review.rating 1..5 | | BR-9.4 |
| courier_pay.amount >= 0 | | BR-10.4 |

## UNIQUE

- client.login, client.phone_number — BR-2.2
- restaurant.address_id — BR-3.3
- payment.transaction_id — BR-8.3
- client_address (client_id, address_id) — BR-2.5
- order_structure (order_id, product_id) — BR-7.16
- courier_pay (year, month, courier_id) — BR-10.3

## NULL разрешены

- address.apartment_office — BR-3.2
- product.photo_url — BR-5.6
- product/restaurant.rating — BR-9.7
- courier.dismissal_date — BR-6.3
- "order".delivery_timestamp — BR-7.12
- review.photo_url — BR-9.3

## 3НФ

Все таблицы в 3НФ. Рейтинги — осознанная денормализация, поддерживаемая триггером.
