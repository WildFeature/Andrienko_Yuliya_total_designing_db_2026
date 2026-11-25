# Протокол тестирования

Схема: `andrienko_food`  
Роль: `inspector`

## Подготовка и восстановление (FOOD-109, FOOD-110)

```bash
pg_restore -U postgres -d <database_name> db/foodexpress_andrienko.backup
psql -U postgres -d <database_name> -f db/schema/grants.sql
psql -U inspector -d <database_name>
```

```sql
SET search_path TO andrienko_food, exts;
```

## Проверка прав доступа (FOOD-109)

- `SELECT table_name FROM information_schema.tables WHERE table_schema = 'andrienko_food';` — **OK** (все 12 таблиц доступны)
- `SELECT tablename FROM pg_catalog.pg_tables WHERE schemaname = 'andrienko_food';` — **OK**
- `SELECT exts.uuid_generate_v4();` — **OK**

## Проверка процедур, функций, триггера и представления

1. **FOOD-103 (`erase_test_data`):**
   - `CALL erase_test_data();` — **OK**, повторный вызов `CALL erase_test_data();` — **OK** (все таблицы содержат 0 строк).
2. **FOOD-102 (`insert_test_data`):**
   - `CALL insert_test_data(10);` — **OK**.
   - Проверка количества строк (BR-11.7):
     - `client`, `courier`, `product_category`, `restaurant` — по **10** строк (`value * 1`).
     - `address` — **50** строк (`value * 5`: 10 у ресторанов, 40 у клиентов).
     - `product`, `"order"`, `payment`, `review` — по **50** строк (`value * 5`).
     - `courier_pay` — **60** строк (10 курьеров × 6 месяцев).
   - Повторный вызов `CALL insert_test_data(10);` без очистки — **OK** (конфликтов ключей и нарушений FK нет).
3. **FOOD-104 (`add_product`):**
   - Вызов с валидными `restaurant_id` и `product_category_id` — **OK** (запись добавлена).
   - Вызов с несуществующим `restaurant_id` — ошибка `violates foreign key constraint` (**OK**).
   - Вызов с отрицательной ценой (`-10`) — ошибка `violates check constraint` (**OK**).
4. **FOOD-105 (`trg_rating_change` / `rating_change`):**
   - Вставка 3 отзывов на блюдо с оценками `3`, `4`, `5` → `product.rating = 4.00` (**OK**).
   - Обновление отзыва (смена оценки / перенос на другое блюдо) → пересчёт `OLD` и `NEW` (**OK**).
   - Удаление одного отзыва → `product.rating = 4.50`; удаление всех → `product.rating IS NULL` (**OK**).
   - Вставка отзыва с `entity_type = 'заказ'` → агрегаты не затрагиваются (**OK**).
5. **FOOD-106 (`get_statistic`):**
   - `SELECT * FROM get_statistic();` — **OK** (возвращает 1 строку на ресторан, колонки `restaurant_name`, `best_product_name`, `total_amount`, `avg_amount`, `best_user`, `total_amount >= avg_amount`).
6. **FOOD-107 (`courier_salary`):**
   - `CALL courier_salary();` — **OK**, повторный вызов за тот же месяц обновляет существующие записи без дублей (**OK**).
7. **FOOD-108 (`how_much_money`):**
   - `SELECT * FROM how_much_money;` — **OK** (покрывает непрерывный ряд месяцев от первого до последнего доставленного заказа, для первого месяца `prev_commission IS NULL`).
