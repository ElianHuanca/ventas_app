-- =====================================================================
-- Textiles App — Esquema PostgreSQL para Supabase
-- Equivalente al esquema SQLite de lib/features/database/database_helper.dart (v3)
--
-- Cómo aplicarlo:
--   Opción A) Supabase Studio -> SQL Editor -> pegar este archivo -> Run
--   Opción B) psql "postgresql://postgres:<password>@db.<ref>.supabase.co:5432/postgres" -f supabase/schema.sql
--   Opción C) supabase db push  (si lo agregas como migración en supabase/migrations/)
-- =====================================================================

-- ---------------------------------------------------------------------
-- Limpieza (opcional, descomenta si quieres recrear desde cero)
-- ---------------------------------------------------------------------
-- DROP TABLE IF EXISTS detalle_ventas CASCADE;
-- DROP TABLE IF EXISTS ventas CASCADE;
-- DROP TABLE IF EXISTS telas CASCADE;
-- DROP TABLE IF EXISTS sucursales CASCADE;

-- ---------------------------------------------------------------------
-- sucursales
-- ---------------------------------------------------------------------
CREATE TABLE categorias (
  id     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nombre TEXT NOT NULL UNIQUE,     -- 'Telas', 'Apliques'
  slug   TEXT NOT NULL UNIQUE,     -- 'telas', 'apliques'
  activo  BOOLEAN NOT NULL DEFAULT TRUE
);
INSERT INTO categorias (nombre, slug)
VALUES ('Telas','telas'), ('Apliques','apliques');

CREATE TABLE IF NOT EXISTS sucursales (
  id     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nombre TEXT NOT NULL
);

ALTER TABLE sucursales
  ADD COLUMN slug        TEXT UNIQUE,          
  ADD COLUMN latitud   TEXT,
  ADD COLUMN longitud   TEXT,
  ADD COLUMN direccion  TEXT,
  ADD COLUMN activo   BOOLEAN NOT NULL DEFAULT TRUE;
-- ---------------------------------------------------------------------
-- telas (productos)
-- En SQLite REAL -> en Postgres usamos NUMERIC para precios (evita errores
-- de coma flotante en dinero).
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS telas (
  id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nombre      TEXT NOT NULL,
  precxmen    NUMERIC(12, 2) NOT NULL DEFAULT 0,
  precxmay    NUMERIC(12, 2) NOT NULL DEFAULT 0,
  precxrollo  NUMERIC(12, 2) NOT NULL DEFAULT 0,
  precxcompra NUMERIC(12, 2) NOT NULL DEFAULT 0
);

ALTER TABLE telas
  ADD COLUMN categoria_id     BIGINT REFERENCES categorias(id),
  ADD COLUMN slug             TEXT UNIQUE,          -- URL bonita + SEO
  ADD COLUMN descripcion      TEXT,
  ADD COLUMN ancho              NUMERIC(4, 2),      -- ancho en mts (hasta 99.99)
  ADD COLUMN activo       BOOLEAN NOT NULL DEFAULT TRUE;

CREATE TABLE colores (
  id     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nombre TEXT NOT NULL UNIQUE,   -- 'Rojo', 'Negro', 'Palo de rosa'
  hex    TEXT ,          -- '#C0392B' -> el swatch en la web
  activo  BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE tela_colores (
  idtela  BIGINT NOT NULL REFERENCES telas(id)   ON DELETE CASCADE,
  idcolor BIGINT NOT NULL REFERENCES colores(id) ON DELETE CASCADE,
  activo BOOLEAN NOT NULL DEFAULT true,
  PRIMARY KEY (idtela, idcolor)
);

CREATE TABLE tela_fotos (
  id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  idtela     BIGINT NOT NULL REFERENCES telas(id)   ON DELETE CASCADE,
  url        TEXT NOT NULL,
  activo BOOLEAN NOT NULL DEFAULT true
);
-- ---------------------------------------------------------------------
-- ventas
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ventas (
  id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  fecha        TEXT NOT NULL,                       -- se mantiene TEXT como en SQLite
  total        NUMERIC(14, 2) NOT NULL DEFAULT 0,
  ganancias    NUMERIC(14, 2) NOT NULL DEFAULT 0,
  descuento    NUMERIC(14, 2) NOT NULL DEFAULT 0,
  idsucursales BIGINT NOT NULL REFERENCES sucursales(id)
);

-- ---------------------------------------------------------------------
-- detalle_ventas
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS detalle_ventas (
  id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nombre    TEXT,
  precio    NUMERIC(12, 2) NOT NULL,
  cantidad  NUMERIC(12, 2) NOT NULL,
  total     NUMERIC(14, 2),
  ganancias NUMERIC(14, 2),
  idtelas   BIGINT NOT NULL REFERENCES telas(id),
  idventa   BIGINT NOT NULL REFERENCES ventas(id) ON DELETE CASCADE
);

-- Índices útiles para las consultas de la app (dashboard, listados por sucursal)
CREATE INDEX IF NOT EXISTS idx_ventas_idsucursales        ON ventas (idsucursales);
CREATE INDEX IF NOT EXISTS idx_ventas_fecha               ON ventas (fecha);
CREATE INDEX IF NOT EXISTS idx_detalle_ventas_idventa     ON detalle_ventas (idventa);
CREATE INDEX IF NOT EXISTS idx_detalle_ventas_idtelas     ON detalle_ventas (idtelas);

-- ---------------------------------------------------------------------
-- Seed de telas iniciales (solo si la tabla está vacía)
-- Mismos datos que _seedTelasIfEmpty() en database_helper.dart
-- ---------------------------------------------------------------------
INSERT INTO telas (nombre, precxmen, precxmay, precxrollo, precxcompra)
SELECT * FROM (VALUES
  ('Razo Suizo Licra',    30.0,  25.0,  23.0,  20.0),
  ('Razo Suizo Rigido',   25.0,  20.0,  18.0,  15.0),
  ('Lipiur 3D',          160.0, 130.0, 110.0, 100.0),
  ('Mostazilla',         180.0, 150.0, 140.0, 110.0),
  ('Lipiur',             130.0, 100.0,  85.0,  70.0),
  ('Razo Doble Ancho',    20.0,  15.0,  14.0,  11.0),
  ('Razo',                10.0,   8.0,   6.0,   5.5),
  ('Tull Ramas',          65.0,  55.0,  50.0,  40.0),
  ('Blonda 15',           15.0,  12.0,  10.0,   8.0),
  ('Blonda 20',           20.0,  15.0,  12.0,  10.0),
  ('Blonda 50',           50.0,  45.0,  43.0,  35.0),
  ('Tull Ilusion',        10.0,   8.0,   6.0,   5.5),
  ('Tull Licra',          20.0,  16.0,  15.0,   8.0),
  ('Tull Frances',        25.0,  20.0,  18.0,  16.0),
  ('Can Can',             20.0,  17.0,  14.0,  12.0),
  ('Tull Maripozas LPZ',  65.0,  50.0,  45.0,  40.0),
  ('Tull Americano',      20.0,  17.0,  15.0,  11.5),
  ('lipiur AG',          130.0, 100.0,  85.0,  62.0),
  ('Tull Perlado',       100.0,  80.0,  70.0,  46.0),
  ('Bonye',               10.0,   8.0,   6.0,   5.5),
  ('Tull Brilloso',       23.0,  18.0,  15.0,  12.0),
  ('Lipiur IH',          130.0, 100.0,  85.0,  57.0),
  ('Lipiur Blonda',       60.0,  50.0,  45.0,  40.0),
  ('gasa',                15.0,  12.0,  10.0,   9.0),
  ('Tull Ramas Ramada',   65.0,  55.0,  50.0,  40.0)
) AS v(nombre, precxmen, precxmay, precxrollo, precxcompra)
WHERE NOT EXISTS (SELECT 1 FROM telas);

-- ---------------------------------------------------------------------
-- Row Level Security (RLS)
-- Supabase activa RLS por defecto en tablas expuestas vía la API.
-- Para una app sin login (solo dueño), la opción más simple es permitir
-- todo al rol anónimo. Si luego agregas Supabase Auth, restringe estas
-- políticas por usuario.
-- ---------------------------------------------------------------------
ALTER TABLE sucursales     ENABLE ROW LEVEL SECURITY;
ALTER TABLE telas          ENABLE ROW LEVEL SECURITY;
ALTER TABLE ventas         ENABLE ROW LEVEL SECURITY;
ALTER TABLE detalle_ventas ENABLE ROW LEVEL SECURITY;

CREATE POLICY "acceso_total_sucursales"     ON sucursales     FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "acceso_total_telas"          ON telas          FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "acceso_total_ventas"         ON ventas         FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "acceso_total_detalle_ventas" ON detalle_ventas FOR ALL USING (true) WITH CHECK (true);

-- ---------------------------------------------------------------------
-- Funciones RPC para el Dashboard
-- La librería de Supabase no permite GROUP BY/SUM directo desde el cliente,
-- así que estas agregaciones se exponen como funciones RPC.
-- `fecha` es TEXT en ISO8601, por eso la comparación lexicográfica funciona.
-- ---------------------------------------------------------------------

-- Top de productos por total vendido en un rango de fechas
CREATE OR REPLACE FUNCTION top_productos(desde TEXT, hasta TEXT)
RETURNS TABLE (
  nombre         TEXT,
  total_vendido  NUMERIC,
  total_cantidad NUMERIC
)
LANGUAGE sql
STABLE
AS $$
  SELECT dv.nombre,
         SUM(dv.total)    AS total_vendido,
         SUM(dv.cantidad) AS total_cantidad
  FROM detalle_ventas dv
  JOIN ventas v ON dv.idventa = v.id
  WHERE v.fecha >= desde AND v.fecha <= hasta
  GROUP BY dv.nombre
  ORDER BY total_vendido DESC;
$$;

-- Resumen de ventas (totales) en un rango de fechas
CREATE OR REPLACE FUNCTION resumen_ventas(desde TEXT, hasta TEXT)
RETURNS TABLE (
  total     NUMERIC,
  ganancias NUMERIC,
  descuento NUMERIC
)
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE(SUM(total), 0)     AS total,
         COALESCE(SUM(ganancias), 0) AS ganancias,
         COALESCE(SUM(descuento), 0) AS descuento
  FROM ventas
  WHERE fecha >= desde AND fecha <= hasta;
$$;
