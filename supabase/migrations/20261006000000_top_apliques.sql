-- =====================================================================
-- RPC top_apliques: ranking de apliques vendidos en un rango de fechas,
-- para la pestaña Apliques del dashboard de la app Flutter.
--
-- Misma firma y mismas columnas que top_productos (telas), así el cliente
-- reutiliza el mapeo. Agrupa por idapliques y toma el nombre actual de la
-- tabla apliques: detalle_ventas_apliques.nombre trae valores sueltos
-- ("A") y renombrar un aplique no debe partir su historial. Suma todos los
-- colores de cada aplique.
--
-- Aditiva: ninguna app existente cambia.
-- =====================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.top_apliques(desde text, hasta text)
RETURNS TABLE(nombre text, total_vendido numeric, total_cantidad numeric)
LANGUAGE sql STABLE
SET search_path = public
AS $$
  SELECT COALESCE(a.nombre, max(d.nombre)) AS nombre,
         SUM(d.total)    AS total_vendido,
         SUM(d.cantidad) AS total_cantidad
  FROM detalle_ventas_apliques d
  JOIN ventas_apliques v ON d.idventa = v.id
  LEFT JOIN apliques a ON a.id = d.idapliques
  WHERE v.fecha >= desde AND v.fecha <= hasta
  GROUP BY d.idapliques, a.nombre
  ORDER BY total_vendido DESC;
$$;

-- Solo usuarios logueados (Postgres da EXECUTE a PUBLIC por defecto)
REVOKE ALL ON FUNCTION public.top_apliques(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_apliques(text, text) TO authenticated, service_role;

COMMIT;
