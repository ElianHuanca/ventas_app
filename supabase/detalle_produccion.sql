-- =====================================================================
-- detalle_produccion — separar cabecera y detalle de fabricación
-- =====================================================================
-- Mismo criterio que ventas/detalle_ventas (y ventas_apliques/
-- detalle_ventas_apliques): una tabla plana con aplique+color+cantidad
-- por fila obligaba a decidir "¿es la misma producción del día o una
-- nueva?" con un UPDATE-o-INSERT ad-hoc sobre esa fila. Se separa:
--   producciones        -> cabecera: SOLO fecha + sucursal (una por
--                           sucursal+día, igual que getVentaByFecha)
--   detalle_produccion  -> líneas: aplique + color + cantidad, con
--                           upsert por (idproduccion, idaplique, idcolor)
--                           igual que detalle_ventas
--
-- Aplicar: Supabase Studio -> SQL Editor -> pegar este archivo -> Run
-- =====================================================================

BEGIN;

-- 1) Detalle: qué aplique+color+cantidad corresponde a cada producción
CREATE TABLE IF NOT EXISTS public.detalle_produccion (
  id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  idproduccion bigint NOT NULL REFERENCES public.producciones(id) ON DELETE CASCADE,
  idaplique    bigint NOT NULL REFERENCES public.apliques(id),
  idcolor      bigint NOT NULL REFERENCES public.colores(id),
  cantidad     numeric NOT NULL CHECK (cantidad > 0)
);

-- 2) Backfill defensivo: si ya hay filas en producciones (esquema viejo,
--    una fila = una línea), se preservan como detalle antes de achicar la
--    cabecera.
INSERT INTO public.detalle_produccion (idproduccion, idaplique, idcolor, cantidad)
SELECT id, aplique_id, color_id, cantidad FROM public.producciones;

-- 3) producciones queda como cabecera (fecha + sucursal), igual que ventas
ALTER TABLE public.producciones
  DROP COLUMN aplique_id,
  DROP COLUMN color_id,
  DROP COLUMN cantidad;

-- 4) Mismo esquema de permisos que el resto (app sin login)
ALTER TABLE public.detalle_produccion ENABLE ROW LEVEL SECURITY;
CREATE POLICY "acceso_total_detalle_produccion" ON public.detalle_produccion
  FOR ALL USING (true) WITH CHECK (true);

COMMIT;
