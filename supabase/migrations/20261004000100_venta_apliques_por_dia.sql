-- =====================================================================
-- Venta de apliques: UNA por sucursal y día (como era en el PHP textiles)
--
-- textiles (ventaControlador::crearVenta) buscaba la venta de apliques de
-- hoy de la sucursal: si existía le sumaba total/descuento/ganancias y las
-- líneas iguales (aplique + color + precio) acumulaban cantidad; si no, la
-- creaba. Al pasar apliques a la app Flutter cada registro empezó a crear
-- una venta nueva (2026-10-02 quedó con 3 ventas en la sucursal 2).
-- Esto vuelve a la regla vieja, igual que las ventas de telas.
--
-- La firma de crear_venta_apliques NO cambia: Flutter e iOS siguen
-- llamándola igual y heredan el comportamiento.
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- 1. Unir las ventas repetidas del mismo día+sucursal en la más antigua
--    (autorizado por el dueño: 2026-10-02, sucursal 2, ventas 2/3/4 → 2)
-- ---------------------------------------------------------------------
CREATE TEMP TABLE _union ON COMMIT DROP AS
SELECT v.id AS id_viejo, k.id_queda
FROM ventas_apliques v
JOIN (
  SELECT idsucursales, left(fecha, 10) AS dia, min(id) AS id_queda
  FROM ventas_apliques
  GROUP BY 1, 2
  HAVING count(*) > 1
) k ON k.idsucursales = v.idsucursales AND k.dia = left(v.fecha, 10)
WHERE v.id <> k.id_queda;

-- Totales de las que se van, sumados a la que queda
UPDATE ventas_apliques q
   SET total     = q.total     + s.total,
       ganancias = q.ganancias + s.ganancias,
       descuento = q.descuento + s.descuento
  FROM (
    SELECT u.id_queda, sum(v.total) total, sum(v.ganancias) ganancias, sum(v.descuento) descuento
    FROM _union u JOIN ventas_apliques v ON v.id = u.id_viejo
    GROUP BY u.id_queda
  ) s
 WHERE q.id = s.id_queda;

-- Líneas de las que se van, agrupadas por aplique+color+precio
CREATE TEMP TABLE _lineas ON COMMIT DROP AS
SELECT u.id_queda, d.idapliques, d.idcolor, d.precio, min(d.nombre) AS nombre,
       sum(d.cantidad) cantidad, sum(d.total) total, sum(d.ganancias) ganancias
FROM _union u JOIN detalle_ventas_apliques d ON d.idventa = u.id_viejo
GROUP BY 1, 2, 3, 4;

-- Si la que queda ya tiene esa línea, se suma ahí...
UPDATE detalle_ventas_apliques q
   SET cantidad  = q.cantidad  + l.cantidad,
       total     = q.total     + l.total,
       ganancias = q.ganancias + l.ganancias
  FROM _lineas l
 WHERE q.idventa = l.id_queda AND q.idapliques = l.idapliques
   AND q.idcolor = l.idcolor  AND q.precio = l.precio;

-- ...si no, se agrega como línea nueva
INSERT INTO detalle_ventas_apliques
  (idventa, idapliques, idcolor, nombre, precio, cantidad, total, ganancias)
SELECT l.id_queda, l.idapliques, l.idcolor, l.nombre, l.precio, l.cantidad, l.total, l.ganancias
FROM _lineas l
WHERE NOT EXISTS (SELECT 1 FROM detalle_ventas_apliques q
                   WHERE q.idventa = l.id_queda AND q.idapliques = l.idapliques
                     AND q.idcolor = l.idcolor  AND q.precio = l.precio);

DELETE FROM detalle_ventas_apliques d USING _union u WHERE d.idventa = u.id_viejo;
DELETE FROM ventas_apliques v USING _union u WHERE v.id = u.id_viejo;

-- ---------------------------------------------------------------------
-- 2. Las reglas, en la DB
-- ---------------------------------------------------------------------
CREATE UNIQUE INDEX ventas_apliques_sucursal_dia_key
  ON public.ventas_apliques (idsucursales, left(fecha, 10));
ALTER TABLE public.detalle_ventas_apliques
  ADD CONSTRAINT detalle_ventas_apliques_linea_key UNIQUE (idventa, idapliques, idcolor, precio);

-- ---------------------------------------------------------------------
-- 3. crear_venta_apliques: venta del día + líneas acumuladas + stock
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.crear_venta_apliques(
  p_idsucursales bigint,
  p_fecha        text,
  p_total        numeric,
  p_ganancias    numeric,
  p_descuento    numeric,
  p_detalles     jsonb
) RETURNS bigint
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_id    bigint;
  d       jsonb;
  v_filas int;
BEGIN
  IF jsonb_typeof(p_detalles) <> 'array' OR jsonb_array_length(p_detalles) = 0 THEN
    RAISE EXCEPTION 'La venta no tiene líneas';
  END IF;

  -- Venta del día de esa sucursal: se le suma; si no hay, se crea (fecha =
  -- la del primer registro del día, igual que ventas de telas). El
  -- ON CONFLICT cubre a dos dispositivos creando la del día a la vez.
  INSERT INTO ventas_apliques (fecha, total, ganancias, descuento, idsucursales)
  VALUES (p_fecha, p_total, p_ganancias, p_descuento, p_idsucursales)
  ON CONFLICT (idsucursales, left(fecha, 10)) DO UPDATE SET
    total     = ventas_apliques.total     + EXCLUDED.total,
    ganancias = ventas_apliques.ganancias + EXCLUDED.ganancias,
    descuento = ventas_apliques.descuento + EXCLUDED.descuento
  RETURNING id INTO v_id;

  FOR d IN SELECT * FROM jsonb_array_elements(p_detalles) LOOP
    -- Misma línea (aplique + color + precio) en el día → se acumula
    INSERT INTO detalle_ventas_apliques
      (idventa, idapliques, idcolor, nombre, precio, cantidad, total, ganancias)
    VALUES
      (v_id, (d->>'idapliques')::bigint, (d->>'idcolor')::bigint, d->>'nombre',
       (d->>'precio')::numeric, (d->>'cantidad')::numeric,
       (d->>'total')::numeric, (d->>'ganancias')::numeric)
    ON CONFLICT (idventa, idapliques, idcolor, precio) DO UPDATE SET
      cantidad  = detalle_ventas_apliques.cantidad  + EXCLUDED.cantidad,
      total     = detalle_ventas_apliques.total     + EXCLUDED.total,
      ganancias = detalle_ventas_apliques.ganancias + EXCLUDED.ganancias;

    -- El UPDATE bloquea la fila: dos ventas simultáneas se serializan acá
    UPDATE inventario
       SET stock = stock - (d->>'cantidad')::numeric
     WHERE sucursal_id = p_idsucursales
       AND aplique_id  = (d->>'idapliques')::bigint
       AND color_id    = (d->>'idcolor')::bigint
       AND activo
       AND stock >= (d->>'cantidad')::numeric;
    GET DIAGNOSTICS v_filas = ROW_COUNT;
    IF v_filas = 0 THEN
      RAISE EXCEPTION 'Stock insuficiente: %', COALESCE(d->>'nombre', d->>'idapliques')
        USING ERRCODE = 'P0001', HINT = 'stock_insuficiente';
    END IF;
  END LOOP;

  RETURN v_id;
END;
$$;

COMMIT;
