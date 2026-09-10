-- =====================================================================
-- ventas_apliques — separar el libro de ventas de apliques del de telas
-- =====================================================================
-- Mismo criterio que la migración 05 con detalle_ventas: la tabla
-- compartida con discriminador `origen` se paga con filtros en cada query
-- y un dashboard que mezcla conceptos. Se separa:
--   ventas           -> SOLO telas (se elimina la columna origen)
--   ventas_apliques  -> SOLO apliques
--
-- `fecha` queda TEXT ISO8601 igual que `ventas` (la migración 03 que la
-- pasaba a date NUNCA se aplicó a producción; las RPC comparan texto
-- lexicográficamente y dependen de ese formato).
--
-- Los ids de las ventas de apliques se preservan (son > 1000) porque
-- detalle_ventas_apliques.idventa los referencia; la FK se repunta a la
-- tabla nueva.
--
-- ⚠️ La app PHP `textiles` (obsoleta) filtra ventas por origen: con esta
-- migración deja de funcionar. El Flutter ya no usa `origen`.
--
-- Aplicar: Supabase Studio -> SQL Editor -> pegar este archivo -> Run
-- =====================================================================

BEGIN;

-- 1) Tabla nueva
CREATE TABLE IF NOT EXISTS public.ventas_apliques (
  id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  fecha        text NOT NULL,
  total        numeric(14, 2) NOT NULL DEFAULT 0,
  ganancias    numeric(14, 2) NOT NULL DEFAULT 0,
  descuento    numeric(14, 2) NOT NULL DEFAULT 0,
  idsucursales bigint NOT NULL REFERENCES public.sucursales(id)
);

-- 2) Migrar las ventas de apliques preservando ids (FK del detalle)
INSERT INTO public.ventas_apliques (id, fecha, total, ganancias, descuento, idsucursales)
OVERRIDING SYSTEM VALUE
SELECT id, fecha, total, ganancias, descuento, idsucursales
FROM public.ventas WHERE origen = 'apliques';

-- 3) Repuntar la FK del detalle de apliques
ALTER TABLE public.detalle_ventas_apliques
  DROP CONSTRAINT detalle_ventas_apliques_idventa_fkey,
  ADD CONSTRAINT detalle_ventas_apliques_idventa_fkey
    FOREIGN KEY (idventa) REFERENCES public.ventas_apliques(id) ON DELETE CASCADE;

-- 4) ventas queda solo telas; origen ya no hace falta
DELETE FROM public.ventas WHERE origen = 'apliques';
ALTER TABLE public.ventas DROP COLUMN origen;

-- 5) RPCs del dashboard: resumen por tabla
DROP FUNCTION IF EXISTS public.resumen_ventas(text, text, text);

CREATE OR REPLACE FUNCTION public.resumen_ventas(desde TEXT, hasta TEXT)
RETURNS TABLE (total NUMERIC, ganancias NUMERIC, descuento NUMERIC)
LANGUAGE sql STABLE AS $$
  SELECT COALESCE(SUM(total), 0), COALESCE(SUM(ganancias), 0), COALESCE(SUM(descuento), 0)
  FROM public.ventas
  WHERE fecha >= desde AND fecha <= hasta;
$$;

CREATE OR REPLACE FUNCTION public.resumen_ventas_apliques(desde TEXT, hasta TEXT)
RETURNS TABLE (total NUMERIC, ganancias NUMERIC, descuento NUMERIC)
LANGUAGE sql STABLE AS $$
  SELECT COALESCE(SUM(total), 0), COALESCE(SUM(ganancias), 0), COALESCE(SUM(descuento), 0)
  FROM public.ventas_apliques
  WHERE fecha >= desde AND fecha <= hasta;
$$;

-- 6) Mismo esquema de permisos que el resto (app sin login)
ALTER TABLE public.ventas_apliques ENABLE ROW LEVEL SECURITY;
CREATE POLICY "acceso_total_ventas_apliques" ON public.ventas_apliques
  FOR ALL USING (true) WITH CHECK (true);

COMMIT;
