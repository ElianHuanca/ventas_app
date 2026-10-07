-- =====================================================================
-- La venta de apliques solo acepta colores vinculados al aplique
--
-- Deshabilitar un color en "Colores" del aplique (aplique_colores.activo =
-- false) ya lo saca de los selectores de Fabricación y de la venta en la
-- app Flutter. Esto lo exige también en la base: crear_venta_apliques
-- falla entera si una línea trae un color no vinculado, así una app vieja
-- o el port iOS tampoco pueden venderlo.
--
-- Misma firma y mismo cuerpo que 20261004000100_venta_apliques_por_dia.sql
-- más el chequeo; CREATE OR REPLACE conserva los permisos (solo
-- authenticated/service_role). Flutter e iOS no cambian.
-- =====================================================================

BEGIN;

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
    -- El color tiene que seguir habilitado para ese aplique
    IF NOT EXISTS (
      SELECT 1 FROM aplique_colores
       WHERE idaplique = (d->>'idapliques')::bigint
         AND idcolor   = (d->>'idcolor')::bigint
         AND activo
    ) THEN
      RAISE EXCEPTION 'Color no habilitado para el aplique: %', COALESCE(d->>'nombre', d->>'idapliques')
        USING ERRCODE = 'P0001', HINT = 'color_no_vinculado';
    END IF;

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
