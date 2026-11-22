-- 04_triggers.sql
SET search_path TO andrienko_food, exts;

CREATE OR REPLACE FUNCTION rating_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_entity_id uuid;
    v_type review_entity_type;
    v_avg numeric;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_entity_id := OLD.entity_id;
        v_type := OLD.entity_type;
    ELSE
        v_entity_id := NEW.entity_id;
        v_type := NEW.entity_type;
    END IF;

    IF v_type = 'блюдо' THEN
        SELECT avg(rating) INTO v_avg FROM review WHERE entity_type = 'блюдо' AND entity_id = v_entity_id;
        UPDATE product SET rating = v_avg WHERE product_id = v_entity_id;
    ELSIF v_type = 'ресторан' THEN
        SELECT avg(rating) INTO v_avg FROM review WHERE entity_type = 'ресторан' AND entity_id = v_entity_id;
        UPDATE restaurant SET rating = v_avg WHERE restaurant_id = v_entity_id;
    END IF;

    -- При UPDATE могли измениться entity_id / entity_type — пересчитываем старые
    IF TG_OP = 'UPDATE' AND (OLD.entity_id IS DISTINCT FROM NEW.entity_id OR OLD.entity_type IS DISTINCT FROM NEW.entity_type) THEN
        IF OLD.entity_type = 'блюдо' THEN
            SELECT avg(rating) INTO v_avg FROM review WHERE entity_type = 'блюдо' AND entity_id = OLD.entity_id;
            UPDATE product SET rating = v_avg WHERE product_id = OLD.entity_id;
        ELSIF OLD.entity_type = 'ресторан' THEN
            SELECT avg(rating) INTO v_avg FROM review WHERE entity_type = 'ресторан' AND entity_id = OLD.entity_id;
            UPDATE restaurant SET rating = v_avg WHERE restaurant_id = OLD.entity_id;
        END IF;
    END IF;

    RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_rating_change ON review;
CREATE TRIGGER trg_rating_change
AFTER INSERT OR UPDATE OR DELETE ON review
FOR EACH ROW EXECUTE FUNCTION rating_change();
