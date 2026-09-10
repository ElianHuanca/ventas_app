-- =====================================================================
-- tela_sucursales — disponibilidad de telas por sucursal
-- =====================================================================
-- Las telas NO llevan control de stock; esta tabla solo registra QUÉ telas
-- se venden en QUÉ sucursal (ej: Razo Suizo en la feria, no en la ramada).
--
-- Es la contraparte de `inventario` para apliques: allí la vinculación
-- sucursal+aplique+color ya existe con stock; para telas es solo vínculo.
--
-- La venta de telas (Flutter) filtra su selector por esta tabla:
-- si una sucursal tiene vínculos activos, solo ofrece esas telas;
-- si no tiene NINGÚN vínculo configurado, muestra todo el catálogo
-- (regla de transición para no romper ventas mientras no se configure).
--
-- Aplicar: Supabase Studio -> SQL Editor -> pegar este archivo -> Run
-- =====================================================================

BEGIN;

CREATE TABLE IF NOT EXISTS public.tela_sucursales (
  idtela      BIGINT NOT NULL REFERENCES public.telas(id)      ON DELETE CASCADE,
  idsucursal  BIGINT NOT NULL REFERENCES public.sucursales(id) ON DELETE CASCADE,
  activo      BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (idtela, idsucursal)
);

-- Mismo esquema de permisos que el resto de las tablas (app sin login)
ALTER TABLE public.tela_sucursales ENABLE ROW LEVEL SECURITY;
CREATE POLICY "acceso_total_tela_sucursales" ON public.tela_sucursales
  FOR ALL USING (true) WITH CHECK (true);

COMMIT;
