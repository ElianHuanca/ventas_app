-- =====================================================================
-- Landing page — vistas públicas
--
-- Aplicar DESPUÉS de schema.sql:
--   Supabase Studio -> SQL Editor -> pegar este archivo -> Run
--
-- Estas vistas son lo ÚNICO que la web lee. Nunca exponen precxcompra
-- (margen) ni los montos vendidos (facturación).
-- =====================================================================

-- ---------------------------------------------------------------------
-- Top 6 telas por monto vendido histórico (sin filtro de fecha)
--
-- El ranking se calcula con SUM(dv.total), pero el monto NO se expone:
-- solo sale `posicion`. Así la web puede ordenarlas sin publicar cuánto
-- factura el negocio.
--
-- Se agrupa por dv.idtelas (no por dv.nombre) para que renombrar una tela
-- no parta su historial en dos.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW top_telas_web AS
WITH ranking AS (
  SELECT dv.idtelas AS id,
         SUM(dv.total) AS monto
  FROM detalle_ventas dv
  GROUP BY dv.idtelas
)
SELECT
  ROW_NUMBER() OVER (ORDER BY r.monto DESC NULLS LAST) AS posicion,
  t.id,
  t.nombre,
  t.slug,
  t.descripcion,
  t.ancho,
  -- convención acordada: precio 0 = no se vende en esa modalidad -> NULL
  NULLIF(t.precxmen,   0) AS precio_metro,
  NULLIF(t.precxmay,   0) AS precio_mayor,
  NULLIF(t.precxrollo, 0) AS precio_rollo,
  foto.url AS foto
FROM ranking r
JOIN telas t ON t.id = r.id AND t.activo
LEFT JOIN LATERAL (
  SELECT f.url
  FROM tela_fotos f
  WHERE f.idtela = t.id AND f.activo
  ORDER BY f.id
  LIMIT 1
) foto ON TRUE
-- una tela sin ningún precio cargado no se publica
WHERE t.precxmen > 0 OR t.precxmay > 0 OR t.precxrollo > 0
ORDER BY r.monto DESC NULLS LAST
LIMIT 6;

-- ---------------------------------------------------------------------
-- Sucursales activas. El celular NO está acá: se configura a mano en
-- sitio/lib/config.ts
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW sucursales_web AS
SELECT id, nombre, slug, direccion, latitud, longitud
FROM sucursales
WHERE activo
ORDER BY id;

-- ---------------------------------------------------------------------
-- Permisos: la web (rol anon) solo puede leer estas dos vistas.
-- Las vistas corren con permisos del owner (security_invoker = off, el
-- default), así que funcionan aunque más adelante le cerremos a `anon`
-- el acceso a las tablas base.
-- ---------------------------------------------------------------------
GRANT SELECT ON top_telas_web  TO anon;
GRANT SELECT ON sucursales_web TO anon;
