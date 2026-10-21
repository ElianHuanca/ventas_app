-- =====================================================================
-- Idempotencia de las escrituras y venta de telas en una sola RPC
--
-- Bugs de red (suite red/ de la app Flutter, 2026-10-20):
--   * crear_venta_apliques y registrar_produccion no eran idempotentes: con
--     la respuesta perdida después del commit y un segundo toque en
--     Guardar, el stock, las líneas y los totales se aplicaban dos veces;
--   * la venta de telas eran tres llamadas (venta del día →
--     registrar_detalle_venta → incrementar_venta) y borrar una línea dos
--     (DELETE → incrementar_venta): una falla en el medio dejaba el total de
--     la venta distinto de la suma de sus líneas, y un reintento duplicaba;
--   * top_productos hacía SUM(dv.total) y detalle_ventas.total admite NULL:
--     total_vendido podía salir NULL y Android (TopProductoRow) no lo
--     decodifica (todo de 09_contrato.test.sql).
--
-- Arreglo:
--   1. operaciones_aplicadas: la clave (uuid v4 que genera la app por envío)
--      de cada escritura que ya se aplicó, guardada en la MISMA transacción.
--      Una RPC que recibe una clave ya aplicada devuelve el resultado de
--      entonces sin tocar nada. Si la escritura falla, se revierte también
--      la clave y el reintento se aplica.
--   2. crear_venta_apliques y registrar_produccion ganan p_id_operacion uuid
--      DEFAULT NULL al final (DROP de la firma vieja + CREATE). Sin clave
--      hacen exactamente lo de antes.
--   3. registrar_venta_telas: venta del día + líneas + totales en UNA
--      transacción, con clave.
--   4. borrar_detalle_venta: borra la línea y descuenta su total de la
--      venta en una transacción; si la línea ya no está, no hace nada.
--   5. top_productos: COALESCE en las sumas (misma firma).
--
-- ADITIVA y compatible: los celulares con el Flutter anterior, Android e
-- iOS siguen andando sin cambios. PostgREST llama por nombre y
-- p_id_operacion tiene default, así que una llamada sin esa clave resuelve
-- a la función nueva (queda una sola por nombre). registrar_detalle_venta e
-- incrementar_venta no se tocan: las usan Android e iOS.
--
-- El Flutter nuevo necesita esta migración aplicada ANTES de publicarse
-- (manda p_id_operacion y llama a las dos RPC nuevas).
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- 1. Claves de las escrituras ya aplicadas
-- ---------------------------------------------------------------------
CREATE TABLE public.operaciones_aplicadas (
  id        uuid        PRIMARY KEY,
  rpc       text        NOT NULL,
  resultado bigint,
  creada    timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.operaciones_aplicadas IS
  'Claves de idempotencia (p_id_operacion) de las RPC de escritura ya aplicadas: '
  'un reintento con la misma clave devuelve resultado sin volver a aplicar. '
  'Una fila por envío; nadie la borra.';
COMMENT ON COLUMN public.operaciones_aplicadas.rpc IS
  'RPC que aplicó la clave (una clave no se puede reusar en otra RPC)';
COMMENT ON COLUMN public.operaciones_aplicadas.resultado IS
  'Lo que devolvió la RPC: id de la venta o de la producción';

ALTER TABLE public.operaciones_aplicadas ENABLE ROW LEVEL SECURITY;
CREATE POLICY solo_logueados_operaciones_aplicadas ON public.operaciones_aplicadas
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Las RPC son SECURITY INVOKER: authenticated tiene que poder leer,
-- insertar y actualizar la tabla. Sin DELETE ni TRUNCATE (como las demás)
-- y nada para anon (el default de Supabase le daba todo a authenticated).
REVOKE ALL ON public.operaciones_aplicadas FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON public.operaciones_aplicadas TO authenticated;
GRANT ALL ON public.operaciones_aplicadas TO service_role;

-- ---------------------------------------------------------------------
-- 2. crear_venta_apliques: mismo cuerpo que
--    20261007000000_venta_apliques_colores_vinculados.sql + la clave
-- ---------------------------------------------------------------------
DROP FUNCTION public.crear_venta_apliques(bigint, text, numeric, numeric, numeric, jsonb);

CREATE FUNCTION public.crear_venta_apliques(
  p_idsucursales bigint,
  p_fecha        text,
  p_total        numeric,
  p_ganancias    numeric,
  p_descuento    numeric,
  p_detalles     jsonb,
  p_id_operacion uuid DEFAULT NULL
) RETURNS bigint
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_id    bigint;
  d       jsonb;
  v_filas int;
  v_rpc   text;
BEGIN
  IF jsonb_typeof(p_detalles) <> 'array' OR jsonb_array_length(p_detalles) = 0 THEN
    RAISE EXCEPTION 'La venta no tiene líneas';
  END IF;

  -- Envío ya aplicado (respuesta perdida + reintento): devuelve la venta de
  -- entonces sin tocar nada. El INSERT toma la clave: un reintento que
  -- llega mientras el primero sigue en curso espera a que termine.
  IF p_id_operacion IS NOT NULL THEN
    INSERT INTO operaciones_aplicadas (id, rpc)
    VALUES (p_id_operacion, 'crear_venta_apliques')
    ON CONFLICT (id) DO NOTHING;
    IF NOT FOUND THEN
      SELECT o.rpc, o.resultado INTO v_rpc, v_id
        FROM operaciones_aplicadas o WHERE o.id = p_id_operacion;
      IF v_rpc <> 'crear_venta_apliques' THEN
        RAISE EXCEPTION 'La clave de operación % ya se usó en %', p_id_operacion, v_rpc
          USING ERRCODE = 'P0001', HINT = 'operacion_de_otra_rpc';
      END IF;
      RETURN v_id;
    END IF;
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

  IF p_id_operacion IS NOT NULL THEN
    UPDATE operaciones_aplicadas SET resultado = v_id WHERE id = p_id_operacion;
  END IF;

  RETURN v_id;
END;
$$;

-- ---------------------------------------------------------------------
-- 3. registrar_produccion: mismo cuerpo que
--    20261003000100_integridad_stock_y_ventas.sql + la clave
-- ---------------------------------------------------------------------
DROP FUNCTION public.registrar_produccion(bigint, date, jsonb);

CREATE FUNCTION public.registrar_produccion(
  p_sucursal_id  bigint,
  p_fecha        date,
  p_lineas       jsonb,
  p_id_operacion uuid DEFAULT NULL
) RETURNS bigint
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_id  bigint;
  l     jsonb;
  v_rpc text;
BEGIN
  -- Envío ya aplicado: devuelve la producción de entonces sin tocar nada
  IF p_id_operacion IS NOT NULL THEN
    INSERT INTO operaciones_aplicadas (id, rpc)
    VALUES (p_id_operacion, 'registrar_produccion')
    ON CONFLICT (id) DO NOTHING;
    IF NOT FOUND THEN
      SELECT o.rpc, o.resultado INTO v_rpc, v_id
        FROM operaciones_aplicadas o WHERE o.id = p_id_operacion;
      IF v_rpc <> 'registrar_produccion' THEN
        RAISE EXCEPTION 'La clave de operación % ya se usó en %', p_id_operacion, v_rpc
          USING ERRCODE = 'P0001', HINT = 'operacion_de_otra_rpc';
      END IF;
      RETURN v_id;
    END IF;
  END IF;

  INSERT INTO producciones (sucursal_id, fecha)
  VALUES (p_sucursal_id, p_fecha)
  ON CONFLICT (sucursal_id, fecha) DO UPDATE SET fecha = EXCLUDED.fecha
  RETURNING id INTO v_id;

  FOR l IN SELECT * FROM jsonb_array_elements(p_lineas) LOOP
    INSERT INTO detalle_produccion (idproduccion, idaplique, idcolor, cantidad)
    VALUES (v_id, (l->>'idaplique')::bigint, (l->>'idcolor')::bigint, (l->>'cantidad')::numeric)
    ON CONFLICT (idproduccion, idaplique, idcolor)
      DO UPDATE SET cantidad = detalle_produccion.cantidad + EXCLUDED.cantidad;

    INSERT INTO inventario (sucursal_id, aplique_id, color_id, stock, activo)
    VALUES (p_sucursal_id, (l->>'idaplique')::bigint, (l->>'idcolor')::bigint,
            (l->>'cantidad')::numeric, true)
    ON CONFLICT (sucursal_id, aplique_id, color_id)
      DO UPDATE SET stock = inventario.stock + EXCLUDED.stock, activo = true;
  END LOOP;

  IF p_id_operacion IS NOT NULL THEN
    UPDATE operaciones_aplicadas SET resultado = v_id WHERE id = p_id_operacion;
  END IF;

  RETURN v_id;
END;
$$;

-- ---------------------------------------------------------------------
-- 4. Venta de telas en una sola transacción
--
-- Venta del día de la sucursal (la crea o reusa la que hay: UNIQUE por
-- sucursal+día) + líneas acumuladas por (idventa, idtelas, precio) + a la
-- venta se le suman el total y las ganancias de ESAS líneas (calculados
-- acá, no mandados aparte) y el descuento. Así el total de la venta es
-- siempre la suma de sus líneas, y lo que sumó otro dispositivo se
-- conserva (todo es UPDATE ... = actual + delta).
--
-- fecha: la de una venta que ya existe NO se toca (queda la del primer
-- registro del día, como en crear_venta_apliques). El flujo viejo
-- (incrementar_venta con p_fecha) la pisaba con la hora del último
-- registro: dos dispositivos se la pisaban entre sí y el día no podía
-- cambiar igual (UNIQUE por sucursal+día).
--
-- p_detalles: [{"idtelas","nombre","precio","cantidad","total","ganancias"}]
-- (lo mismo que registrar_detalle_venta). Devuelve el id de la venta.
-- ---------------------------------------------------------------------
CREATE FUNCTION public.registrar_venta_telas(
  p_idsucursales bigint,
  p_fecha        text,
  p_detalles     jsonb,
  p_descuento    numeric,
  p_id_operacion uuid DEFAULT NULL
) RETURNS bigint
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_id        bigint;
  d           jsonb;
  v_total     numeric := 0;
  v_ganancias numeric := 0;
  v_rpc       text;
BEGIN
  IF p_detalles IS NULL OR jsonb_typeof(p_detalles) <> 'array'
     OR jsonb_array_length(p_detalles) = 0 THEN
    RAISE EXCEPTION 'La venta no tiene líneas';
  END IF;
  IF p_descuento < 0 THEN
    RAISE EXCEPTION 'El descuento no puede ser negativo';
  END IF;

  FOR d IN SELECT * FROM jsonb_array_elements(p_detalles) LOOP
    IF d->>'total' IS NULL OR d->>'ganancias' IS NULL THEN
      RAISE EXCEPTION 'Línea sin total o ganancias: %', COALESCE(d->>'nombre', d->>'idtelas');
    END IF;
    -- Cada línea se guarda en numeric(14,2): se suma lo que va a quedar
    v_total     := v_total     + round((d->>'total')::numeric, 2);
    v_ganancias := v_ganancias + round((d->>'ganancias')::numeric, 2);
  END LOOP;

  -- Envío ya aplicado: devuelve la venta de entonces sin tocar nada
  IF p_id_operacion IS NOT NULL THEN
    INSERT INTO operaciones_aplicadas (id, rpc)
    VALUES (p_id_operacion, 'registrar_venta_telas')
    ON CONFLICT (id) DO NOTHING;
    IF NOT FOUND THEN
      SELECT o.rpc, o.resultado INTO v_rpc, v_id
        FROM operaciones_aplicadas o WHERE o.id = p_id_operacion;
      IF v_rpc <> 'registrar_venta_telas' THEN
        RAISE EXCEPTION 'La clave de operación % ya se usó en %', p_id_operacion, v_rpc
          USING ERRCODE = 'P0001', HINT = 'operacion_de_otra_rpc';
      END IF;
      RETURN v_id;
    END IF;
  END IF;

  -- El ON CONFLICT cubre a dos dispositivos creando la del día a la vez
  INSERT INTO ventas (fecha, total, ganancias, descuento, idsucursales)
  VALUES (p_fecha, v_total, v_ganancias, COALESCE(p_descuento, 0), p_idsucursales)
  ON CONFLICT (idsucursales, left(fecha, 10)) DO UPDATE SET
    total     = ventas.total     + EXCLUDED.total,
    ganancias = ventas.ganancias + EXCLUDED.ganancias,
    descuento = ventas.descuento + EXCLUDED.descuento
  RETURNING id INTO v_id;

  -- Misma línea (tela + precio) en la venta → se acumula (como
  -- registrar_detalle_venta; una línea vieja con total NULL suma desde 0)
  FOR d IN SELECT * FROM jsonb_array_elements(p_detalles) LOOP
    INSERT INTO detalle_ventas (nombre, precio, cantidad, total, ganancias, idtelas, idventa)
    VALUES (d->>'nombre', (d->>'precio')::numeric, (d->>'cantidad')::numeric,
            (d->>'total')::numeric, (d->>'ganancias')::numeric,
            (d->>'idtelas')::bigint, v_id)
    ON CONFLICT (idventa, idtelas, precio) DO UPDATE SET
      cantidad  = detalle_ventas.cantidad + EXCLUDED.cantidad,
      total     = COALESCE(detalle_ventas.total, 0) + EXCLUDED.total,
      ganancias = COALESCE(detalle_ventas.ganancias, 0) + EXCLUDED.ganancias;
  END LOOP;

  IF p_id_operacion IS NOT NULL THEN
    UPDATE operaciones_aplicadas SET resultado = v_id WHERE id = p_id_operacion;
  END IF;

  RETURN v_id;
END;
$$;

-- ---------------------------------------------------------------------
-- 5. Borrar una línea de la venta de telas en una sola transacción
--
-- Borra la línea y le resta su total y sus ganancias a la venta. Si la
-- línea ya no existe (la borró otro dispositivo, o es el reintento de un
-- borrado cuya respuesta se perdió) no hace nada: es idempotente sin clave.
-- Devuelve la venta con los totales ya descontados, o NULL si no borró.
-- ---------------------------------------------------------------------
CREATE FUNCTION public.borrar_detalle_venta(p_id bigint)
RETURNS public.ventas
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_linea detalle_ventas;
  v_venta ventas;
BEGIN
  -- El DELETE bloquea la fila: dos borrados a la vez restan una sola vez
  DELETE FROM detalle_ventas WHERE id = p_id RETURNING * INTO v_linea;
  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  UPDATE ventas
     SET total     = total     - COALESCE(v_linea.total, 0),
         ganancias = ganancias - COALESCE(v_linea.ganancias, 0)
   WHERE id = v_linea.idventa
  RETURNING * INTO v_venta;

  RETURN v_venta;
END;
$$;

-- Solo usuarios logueados (Postgres da EXECUTE a PUBLIC por defecto)
REVOKE ALL ON FUNCTION public.crear_venta_apliques(bigint, text, numeric, numeric, numeric, jsonb, uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.registrar_produccion(bigint, date, jsonb, uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.registrar_venta_telas(bigint, text, jsonb, numeric, uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.borrar_detalle_venta(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.crear_venta_apliques(bigint, text, numeric, numeric, numeric, jsonb, uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.registrar_produccion(bigint, date, jsonb, uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.registrar_venta_telas(bigint, text, jsonb, numeric, uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.borrar_detalle_venta(bigint) TO authenticated, service_role;

-- ---------------------------------------------------------------------
-- 6. top_productos: nunca NULL en las sumas (misma firma y columnas;
--    CREATE OR REPLACE conserva los permisos)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.top_productos(desde text, hasta text)
RETURNS TABLE(nombre text, total_vendido numeric, total_cantidad numeric)
LANGUAGE sql STABLE
SET search_path = public
AS $$
  SELECT COALESCE(t.nombre, max(dv.nombre)) AS nombre,
         COALESCE(SUM(dv.total), 0)    AS total_vendido,
         COALESCE(SUM(dv.cantidad), 0) AS total_cantidad
  FROM detalle_ventas dv
  JOIN ventas v ON dv.idventa = v.id
  LEFT JOIN telas t ON t.id = dv.idtelas
  WHERE v.fecha >= desde AND v.fecha <= hasta
  GROUP BY dv.idtelas, t.nombre
  ORDER BY total_vendido DESC;
$$;

-- PostgREST vuelve a leer las firmas (las RPC cambiaron de parámetros)
NOTIFY pgrst, 'reload schema';

COMMIT;
