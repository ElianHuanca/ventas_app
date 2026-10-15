-- =====================================================================
-- RPC inventario_con_ventas: el inventario de apliques de una sucursal con
-- lo vendido de cada aplique+color en un rango, para la pantalla Inventario
-- de la app Flutter (la lista de faltantes que se le pasa al fabricante).
--
-- Devuelve las filas de inventario activas cuyo aplique, color y vínculo
-- aplique_colores siguen activos (lo mismo que ofrece la venta), con:
--   vendidas        unidades vendidas en ESA sucursal en el rango
--   vendidas_otras  promedio de las otras sucursales que vendieron apliques
--                   en el rango: estima la venta de una sucursal sin
--                   historial propio (una tienda que recién empieza)
-- La regla de reposición (mínimo, cuánto hacer) la aplica la app.
--
-- Aditiva: ninguna app existente cambia.
-- =====================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.inventario_con_ventas(
  p_sucursal_id bigint, desde text, hasta text)
RETURNS TABLE(aplique_id bigint, aplique text, color_id bigint, color text,
              hex text, stock numeric, vendidas numeric,
              vendidas_otras numeric)
LANGUAGE sql STABLE
SET search_path = public
AS $$
  WITH vendido AS (
    SELECT v.idsucursales AS sucursal_id, d.idapliques AS aplique_id,
           d.idcolor AS color_id, SUM(d.cantidad) AS unidades
    FROM detalle_ventas_apliques d
    JOIN ventas_apliques v ON v.id = d.idventa
    WHERE v.fecha >= desde AND v.fecha <= hasta
    GROUP BY 1, 2, 3
  ),
  otras AS (
    -- Solo cuentan las sucursales que vendieron algo: una sin ventas no
    -- baja el promedio
    SELECT x.aplique_id, x.color_id,
           SUM(x.unidades) / (SELECT COUNT(DISTINCT y.sucursal_id)
                              FROM vendido y
                              WHERE y.sucursal_id <> p_sucursal_id)
             AS unidades
    FROM vendido x
    WHERE x.sucursal_id <> p_sucursal_id
    GROUP BY x.aplique_id, x.color_id
  )
  SELECT i.aplique_id, a.nombre, i.color_id, c.nombre, COALESCE(c.hex, ''),
         i.stock,
         COALESCE(propia.unidades, 0),
         COALESCE(o.unidades, 0)
  FROM inventario i
  JOIN apliques a ON a.id = i.aplique_id AND a.activo
  JOIN colores c ON c.id = i.color_id AND c.activo
  JOIN aplique_colores ac
    ON ac.idaplique = i.aplique_id AND ac.idcolor = i.color_id AND ac.activo
  LEFT JOIN vendido propia
    ON propia.sucursal_id = i.sucursal_id
   AND propia.aplique_id = i.aplique_id
   AND propia.color_id = i.color_id
  LEFT JOIN otras o ON o.aplique_id = i.aplique_id AND o.color_id = i.color_id
  WHERE i.sucursal_id = p_sucursal_id AND i.activo
  ORDER BY a.nombre, c.nombre;
$$;

-- Solo usuarios logueados (Postgres da EXECUTE a PUBLIC por defecto)
REVOKE ALL ON FUNCTION public.inventario_con_ventas(bigint, text, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.inventario_con_ventas(bigint, text, text)
  TO authenticated, service_role;

COMMIT;
