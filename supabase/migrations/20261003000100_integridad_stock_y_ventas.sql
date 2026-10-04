-- =====================================================================
-- Integridad de stock y ventas
--
-- Todo es ADITIVO: las versiones viejas de las apps (Flutter, Android,
-- iOS) siguen funcionando. Lo que cambia para ellas:
--   * una escritura que deje stock/cantidad/precio negativo ahora falla
--     (antes quedaba guardada en silencio);
--   * dos cabeceras del mismo día/sucursal ya no se pueden crear; la
--     segunda falla en vez de dejar la sucursal trabada con duplicados.
--
-- Las funciones nuevas hacen en UNA transacción lo que hoy el cliente
-- hace en varias llamadas HTTP (leer → sumar → escribir), que pierde
-- unidades cuando dos dispositivos escriben a la vez.
--
-- Pre-chequeo en la copia local de producción (2026-09-25): 0 negativos,
-- 0 duplicados. Si producción tuviera alguno, VALIDATE / ADD UNIQUE fallan
-- y la transacción entera se revierte sin dejar nada a medias.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. CHECKs: nada negativo
-- ---------------------------------------------------------------------
ALTER TABLE public.inventario
  ADD CONSTRAINT inventario_stock_no_negativo CHECK (stock >= 0) NOT VALID;
ALTER TABLE public.detalle_ventas_apliques
  ADD CONSTRAINT detalle_ventas_apliques_montos_check
  CHECK (cantidad > 0 AND precio >= 0 AND total >= 0) NOT VALID;
ALTER TABLE public.detalle_ventas
  ADD CONSTRAINT detalle_ventas_montos_check
  CHECK (cantidad > 0 AND precio >= 0) NOT VALID;
ALTER TABLE public.telas
  ADD CONSTRAINT telas_precios_no_negativos
  CHECK (precxmen >= 0 AND precxmay >= 0 AND precxrollo >= 0 AND precxcompra >= 0) NOT VALID;
ALTER TABLE public.apliques
  ADD CONSTRAINT apliques_costo_no_negativo CHECK (costo_fabricacion >= 0) NOT VALID;
ALTER TABLE public.ventas
  ADD CONSTRAINT ventas_descuento_no_negativo CHECK (descuento >= 0) NOT VALID;
ALTER TABLE public.ventas_apliques
  ADD CONSTRAINT ventas_apliques_montos_check CHECK (total >= 0 AND descuento >= 0) NOT VALID;

ALTER TABLE public.inventario              VALIDATE CONSTRAINT inventario_stock_no_negativo;
ALTER TABLE public.detalle_ventas_apliques VALIDATE CONSTRAINT detalle_ventas_apliques_montos_check;
ALTER TABLE public.detalle_ventas          VALIDATE CONSTRAINT detalle_ventas_montos_check;
ALTER TABLE public.telas                   VALIDATE CONSTRAINT telas_precios_no_negativos;
ALTER TABLE public.apliques                VALIDATE CONSTRAINT apliques_costo_no_negativo;
ALTER TABLE public.ventas                  VALIDATE CONSTRAINT ventas_descuento_no_negativo;
ALTER TABLE public.ventas_apliques         VALIDATE CONSTRAINT ventas_apliques_montos_check;

-- ---------------------------------------------------------------------
-- 2. UNIQUE que el código ya daba por supuestos (maybeSingle)
--    ventas_apliques NO lleva: cada venta de apliques es una fila nueva.
-- ---------------------------------------------------------------------
ALTER TABLE public.producciones
  ADD CONSTRAINT producciones_sucursal_fecha_key UNIQUE (sucursal_id, fecha);
ALTER TABLE public.detalle_produccion
  ADD CONSTRAINT detalle_produccion_linea_key UNIQUE (idproduccion, idaplique, idcolor);
ALTER TABLE public.detalle_ventas
  ADD CONSTRAINT detalle_ventas_linea_key UNIQUE (idventa, idtelas, precio);
-- fecha es texto ISO8601: los 10 primeros caracteres son el día
CREATE UNIQUE INDEX ventas_sucursal_dia_key ON public.ventas (idsucursales, left(fecha, 10));

-- ---------------------------------------------------------------------
-- 3. Índices en FKs y columnas que filtran las apps
--    (los UNIQUE de arriba ya cubren producciones.sucursal_id y
--    detalle_produccion.idproduccion)
-- ---------------------------------------------------------------------
CREATE INDEX idx_ventas_apliques_sucursal_fecha ON public.ventas_apliques (idsucursales, fecha DESC);
CREATE INDEX idx_ventas_apliques_fecha          ON public.ventas_apliques (fecha);
CREATE INDEX idx_detalle_ventas_apliques_idventa   ON public.detalle_ventas_apliques (idventa);
CREATE INDEX idx_detalle_ventas_apliques_idaplique ON public.detalle_ventas_apliques (idapliques);
CREATE INDEX idx_detalle_ventas_apliques_idcolor   ON public.detalle_ventas_apliques (idcolor);
CREATE INDEX idx_detalle_produccion_idaplique ON public.detalle_produccion (idaplique);
CREATE INDEX idx_detalle_produccion_idcolor   ON public.detalle_produccion (idcolor);
CREATE INDEX idx_inventario_aplique ON public.inventario (aplique_id);
CREATE INDEX idx_inventario_color   ON public.inventario (color_id);
CREATE INDEX idx_tela_sucursales_sucursal ON public.tela_sucursales (idsucursal);
CREATE INDEX idx_tela_colores_color       ON public.tela_colores (idcolor);
CREATE INDEX idx_aplique_colores_color    ON public.aplique_colores (idcolor);
CREATE INDEX idx_tela_fotos_tela          ON public.tela_fotos (idtela);
CREATE INDEX idx_apliques_categoria       ON public.apliques (categoria_id);
CREATE INDEX idx_telas_categoria          ON public.telas (categoria_id);

-- ---------------------------------------------------------------------
-- 4. Funciones transaccionales (SECURITY INVOKER: corren con los
--    permisos de quien llama, no saltan RLS)
-- ---------------------------------------------------------------------

-- Venta de apliques completa: cabecera + líneas + descuento de stock.
-- Falla entera (sin dejar nada guardado) si alguna línea no tiene stock
-- suficiente o no está en el inventario activo de la sucursal.
-- p_detalles: [{"idapliques","idcolor","nombre","precio","cantidad","total","ganancias"}]
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

  INSERT INTO ventas_apliques (fecha, total, ganancias, descuento, idsucursales)
  VALUES (p_fecha, p_total, p_ganancias, p_descuento, p_idsucursales)
  RETURNING id INTO v_id;

  FOR d IN SELECT * FROM jsonb_array_elements(p_detalles) LOOP
    INSERT INTO detalle_ventas_apliques
      (idventa, idapliques, idcolor, nombre, precio, cantidad, total, ganancias)
    VALUES
      (v_id, (d->>'idapliques')::bigint, (d->>'idcolor')::bigint, d->>'nombre',
       (d->>'precio')::numeric, (d->>'cantidad')::numeric,
       (d->>'total')::numeric, (d->>'ganancias')::numeric);

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

-- Fabricación: cabecera del día (una por sucursal+fecha) + líneas
-- acumuladas por aplique+color + suma al stock (crea/reactiva la fila).
-- p_lineas: [{"idaplique","idcolor","cantidad"}]. Devuelve el id de la producción.
CREATE OR REPLACE FUNCTION public.registrar_produccion(
  p_sucursal_id bigint,
  p_fecha       date,
  p_lineas      jsonb
) RETURNS bigint
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_id bigint;
  l    jsonb;
BEGIN
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

  RETURN v_id;
END;
$$;

-- Líneas de venta de telas con upsert atómico por (idventa, idtelas, precio):
-- si la línea ya existe suma cantidad/total/ganancias. Devuelve las filas.
-- p_detalles: [{"idtelas","nombre","precio","cantidad","total","ganancias"}]
CREATE OR REPLACE FUNCTION public.registrar_detalle_venta(
  p_idventa  bigint,
  p_detalles jsonb
) RETURNS SETOF public.detalle_ventas
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  d jsonb;
BEGIN
  FOR d IN SELECT * FROM jsonb_array_elements(p_detalles) LOOP
    RETURN QUERY
    INSERT INTO detalle_ventas (nombre, precio, cantidad, total, ganancias, idtelas, idventa)
    VALUES (d->>'nombre', (d->>'precio')::numeric, (d->>'cantidad')::numeric,
            (d->>'total')::numeric, (d->>'ganancias')::numeric,
            (d->>'idtelas')::bigint, p_idventa)
    ON CONFLICT (idventa, idtelas, precio) DO UPDATE SET
      cantidad  = detalle_ventas.cantidad + EXCLUDED.cantidad,
      total     = COALESCE(detalle_ventas.total, 0) + EXCLUDED.total,
      ganancias = COALESCE(detalle_ventas.ganancias, 0) + EXCLUDED.ganancias
    RETURNING *;
  END LOOP;
END;
$$;

-- Suma deltas a los totales de una venta en un solo UPDATE (atómico).
-- p_fecha NULL = no tocar la fecha.
CREATE OR REPLACE FUNCTION public.incrementar_venta(
  p_id        bigint,
  p_total     numeric DEFAULT 0,
  p_ganancias numeric DEFAULT 0,
  p_descuento numeric DEFAULT 0,
  p_fecha     text    DEFAULT NULL
) RETURNS public.ventas
LANGUAGE sql
SET search_path = public
AS $$
  UPDATE ventas
     SET total     = total     + COALESCE(p_total, 0),
         ganancias = ganancias + COALESCE(p_ganancias, 0),
         descuento = descuento + COALESCE(p_descuento, 0),
         fecha     = COALESCE(p_fecha, fecha)
   WHERE id = p_id
  RETURNING *;
$$;

REVOKE ALL ON FUNCTION public.crear_venta_apliques(bigint, text, numeric, numeric, numeric, jsonb) FROM public;
REVOKE ALL ON FUNCTION public.registrar_produccion(bigint, date, jsonb) FROM public;
REVOKE ALL ON FUNCTION public.registrar_detalle_venta(bigint, jsonb) FROM public;
REVOKE ALL ON FUNCTION public.incrementar_venta(bigint, numeric, numeric, numeric, text) FROM public;
GRANT EXECUTE ON FUNCTION public.crear_venta_apliques(bigint, text, numeric, numeric, numeric, jsonb) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.registrar_produccion(bigint, date, jsonb) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.registrar_detalle_venta(bigint, jsonb) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.incrementar_venta(bigint, numeric, numeric, numeric, text) TO anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- 5. Funciones existentes: search_path fijo; top_productos agrupa por
--    idtelas (renombrar una tela ya no parte su historial). Misma firma y
--    mismas columnas: Flutter, Android e iOS no cambian.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.top_productos(desde text, hasta text)
RETURNS TABLE(nombre text, total_vendido numeric, total_cantidad numeric)
LANGUAGE sql STABLE
SET search_path = public
AS $$
  SELECT COALESCE(t.nombre, max(dv.nombre)) AS nombre,
         SUM(dv.total)    AS total_vendido,
         SUM(dv.cantidad) AS total_cantidad
  FROM detalle_ventas dv
  JOIN ventas v ON dv.idventa = v.id
  LEFT JOIN telas t ON t.id = dv.idtelas
  WHERE v.fecha >= desde AND v.fecha <= hasta
  GROUP BY dv.idtelas, t.nombre
  ORDER BY total_vendido DESC;
$$;

ALTER FUNCTION public.resumen_ventas(text, text)          SET search_path = public;
ALTER FUNCTION public.resumen_ventas_apliques(text, text) SET search_path = public;

-- Función de event trigger: nadie de la API debe poder ejecutarla
REVOKE ALL ON FUNCTION public.rls_auto_enable() FROM anon, authenticated, public;

-- ---------------------------------------------------------------------
-- 6. Permisos de anon/authenticated
--    Ninguna app hace DELETE físico salvo en ventas y detalle_ventas
--    (Flutter, Android, iOS: "eliminar venta/línea"); el resto es baja
--    lógica (activo = false). TRUNCATE no lo usa nadie.
-- ---------------------------------------------------------------------
REVOKE TRUNCATE ON ALL TABLES IN SCHEMA public FROM anon, authenticated;
REVOKE DELETE ON
  public.ventas_apliques, public.detalle_ventas_apliques,
  public.producciones, public.detalle_produccion, public.inventario,
  public.apliques, public.aplique_colores, public.telas, public.tela_colores,
  public.tela_fotos, public.tela_sucursales, public.sucursales,
  public.colores, public.categorias
FROM anon, authenticated;

-- Vistas web: solo lectura. Corren con permisos del owner (saltan RLS),
-- así que con GRANT ALL eran una puerta de escritura a sucursales.
REVOKE ALL ON public.sucursales_web, public.top_telas_web,
              public.catalogo_telas_web, public.catalogo_apliques_web
FROM anon, authenticated;
GRANT SELECT ON public.sucursales_web, public.top_telas_web,
                public.catalogo_telas_web, public.catalogo_apliques_web
TO anon, authenticated;
