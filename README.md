# Инструкция по использованию

1. Скопируйте папку `db` в свой репозиторий `Andrienko_Yuliya_total_designing_db_2026`.
2. В PostgreSQL выполните по порядку:
   - db/schema/01_types.sql
   - db/schema/02_tables.sql
   - db/schema/03_functions.sql
   - db/schema/04_triggers.sql
   - db/schema/05_views.sql
   - db/schema/grants.sql
3. Проверьте:
   ```sql
   SET search_path TO andrienko_food, exts;
   CALL insert_test_data(10);
   SELECT count(*) FROM client;
   SELECT * FROM get_statistic() LIMIT 5;
   ```
4. Сделайте backup:
   ```bash
   pg_dump -Fc -n andrienko_food -f db/foodexpress_andrienko.backup имя_базы
   ```
5. Закоммитьте и запушьте в свой форк.
