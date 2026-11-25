-- 04_triggers.sql
SET search_path TO andrienko_food, exts;

CREATE OR REPLACE FUNCTION rating_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path TO andrienko_food, exts
AS $$
DECLARE
    v_avg numeric;
BEGIN
    IF TG_OP IN ('UPDATE', 'DELETE') THEN
        IF OLD.entity_type = 'блюдо' THEN
            SELECT avg(rating) INTO v_avg
            FROM review
            WHERE entity_type = 'блюдо'
              AND entity_id = OLD.entity_id;

            UPDATE product
            SET rating = v_avg
            WHERE product_id = OLD.entity_id;
        ELSIF OLD.entity_type = 'ресторан' THEN
            SELECT avg(rating) INTO v_avg
            FROM review
            WHERE entity_type = 'ресторан'
              AND entity_id = OLD.entity_id;

            UPDATE restaurant
            SET rating = v_avg
            WHERE restaurant_id = OLD.entity_id;
        END IF;
    END IF;

    IF TG_OP IN ('INSERT', 'UPDATE') THEN
        IF NEW.entity_type = 'блюдо' THEN
            SELECT avg(rating) INTO v_avg
            FROM review
            WHERE entity_type = 'блюдо'
              AND entity_id = NEW.entity_id;

            UPDATE product
            SET rating = v_avg
            WHERE product_id = NEW.entity_id;
        ELSIF NEW.entity_type = 'ресторан' THEN
            SELECT avg(rating) INTO v_avg
            FROM review
            WHERE entity_type = 'ресторан'
              AND entity_id = NEW.entity_id;

            UPDATE restaurant
            SET rating = v_avg
            WHERE restaurant_id = NEW.entity_id;
        END IF;
    END IF;

    RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_rating_change ON review;
CREATE TRIGGER trg_rating_change
AFTER INSERT OR UPDATE OR DELETE ON review
FOR EACH ROW EXECUTE FUNCTION rating_change();