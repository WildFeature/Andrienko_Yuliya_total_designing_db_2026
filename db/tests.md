# Протокол тестирования

Схема: andrienko_food  
Роль: inspector

## Подготовка

1. Восстановить backup
2. Выполнить grants.sql
3. SET ROLE inspector;
4. SET search_path TO andrienko_food, exts;

## Основные проверки

- CALL erase_test_data(); — OK
- CALL insert_test_data(10); — OK
- Повторный вызов insert_test_data(10) — OK
- CALL add_product(...) — OK
- CALL courier_salary(); — OK
- SELECT * FROM get_statistic(); — OK
- SELECT * FROM how_much_money; — OK
- Триггер рейтинга проверен вручную — OK

Все ограничения и FK соблюдены.
