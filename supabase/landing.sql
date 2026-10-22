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

-- ---------------------------------------------------------------------
-- Catálogo completo de telas (todas las activas, no solo el top 6)
--
-- A diferencia de top_telas_web, una tela SIN precio cargado también se
-- publica: es escaparate, y la card muestra "Precio a consultar". Los
-- precios en 0 siguen saliendo como NULL por modalidad.
-- Nunca expone precxcompra (margen) ni montos vendidos.
--
-- `colores` sale como jsonb: [{"nombre": "...", "hex": "..."}, ...],
-- solo vínculos y colores activos, ordenado alfabético sin mayúsculas.
-- `fotos` sale como jsonb: ["url", ...], las fotos activas (tela_fotos)
-- por id; `foto` es la primera (NULL si no tiene).
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW catalogo_telas_web AS
SELECT
  t.id,
  t.nombre,
  t.slug,
  t.descripcion,
  t.ancho,
  NULLIF(t.precxmen,   0) AS precio_metro,
  NULLIF(t.precxmay,   0) AS precio_mayor,
  NULLIF(t.precxrollo, 0) AS precio_rollo,
  fotos.lista->>0 AS foto,
  COALESCE(cols.colores, '[]'::jsonb) AS colores,
  COALESCE(fotos.lista, '[]'::jsonb) AS fotos
FROM telas t
LEFT JOIN LATERAL (
  SELECT jsonb_agg(f.url ORDER BY f.id) AS lista
  FROM tela_fotos f
  WHERE f.idtela = t.id AND f.activo
) fotos ON TRUE
LEFT JOIN LATERAL (
  SELECT jsonb_agg(jsonb_build_object('nombre', c.nombre, 'hex', c.hex)
                   ORDER BY lower(c.nombre)) AS colores
  FROM tela_colores tc
  JOIN colores c ON c.id = tc.idcolor AND c.activo
  WHERE tc.idtela = t.id AND tc.activo
) cols ON TRUE
WHERE t.activo
ORDER BY lower(t.nombre);

-- ---------------------------------------------------------------------
-- Catálogo de apliques (todos los activos). No tienen precio de lista
-- (el precio se define en cada venta), así que la web ofrece consultar
-- por WhatsApp. Nunca expone costo_fabricacion (margen).
-- `foto` / `fotos` como en telas, desde aplique_fotos.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW catalogo_apliques_web AS
SELECT
  a.id,
  a.nombre,
  a.tamanio,
  a.ancho_cm,
  a.alto_cm,
  COALESCE(cols.colores, '[]'::jsonb) AS colores,
  fotos.lista->>0 AS foto,
  COALESCE(fotos.lista, '[]'::jsonb) AS fotos
FROM apliques a
LEFT JOIN LATERAL (
  SELECT jsonb_agg(jsonb_build_object('nombre', c.nombre, 'hex', c.hex)
                   ORDER BY lower(c.nombre)) AS colores
  FROM aplique_colores ac
  JOIN colores c ON c.id = ac.idcolor AND c.activo
  WHERE ac.idaplique = a.id AND ac.activo
) cols ON TRUE
LEFT JOIN LATERAL (
  SELECT jsonb_agg(f.url ORDER BY f.id) AS lista
  FROM aplique_fotos f
  WHERE f.idaplique = a.id AND f.activo
) fotos ON TRUE
WHERE a.activo
ORDER BY lower(a.nombre);

GRANT SELECT ON catalogo_telas_web    TO anon;
GRANT SELECT ON catalogo_apliques_web TO anon;
