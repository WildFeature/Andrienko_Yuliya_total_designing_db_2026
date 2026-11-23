<<<<<<< HEAD

=======
# FoodExpress DB

База данных сервиса доставки еды FoodExpress.

Схема: `andrienko_food`

## Структура

```
db/schema/
├── 01_types.sql       — типы и схема
├── 02_tables.sql      — таблицы
├── 03_functions.sql   — процедуры и функции
├── 04_triggers.sql    — триггеры
├── 05_views.sql       — представления
└── grants.sql         — права доступа
```

## Развёртывание

```bash
psql -d your_database -f db/schema/01_types.sql
psql -d your_database -f db/schema/02_tables.sql
psql -d your_database -f db/schema/03_functions.sql
psql -d your_database -f db/schema/04_triggers.sql
psql -d your_database -f db/schema/05_views.sql
psql -d your_database -f db/schema/grants.sql
```

## Проверка

```sql
SET search_path TO andrienko_food, exts;
CALL insert_test_data(10);
SELECT * FROM get_statistic() LIMIT 10;
SELECT * FROM how_much_money LIMIT 5;
CALL courier_salary();
```

## Основные объекты

- `insert_test_data(value)` — генерация тестовых данных
- `erase_test_data()` — очистка
- `add_product(...)` — добавление блюда
- `get_statistic()` — статистика по ресторанам
- `courier_salary()` — расчёт зарплаты курьеров
- `how_much_money` — отчёт по месяцам
- `rating_change` — триггер пересчёта рейтинга

Роль `inspector` создаётся в `grants.sql`.
>>>>>>> 808161a (Исправления по замечаниям преподавателя)
