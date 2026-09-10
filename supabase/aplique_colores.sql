-- =====================================================================
-- aplique_colores + inventario.activo — colores por producto y baja lógica
-- =====================================================================
-- Regla del negocio: NADA se borra físicamente; toda baja es activo=false.
--
-- 1) aplique_colores: qué colores se fabrican de cada aplique
--    (contraparte de tela_colores). Los selectores de color de
--    fabricación y disponibilidad por sucursal se filtran por esta tabla.
--    Backfill desde inventario para no romper los apliques existentes.
-- 2) inventario.activo: la vinculación sucursal+aplique+color se da de
--    baja con activo=false en vez de DELETE.
--
-- Aplicar: Supabase Studio -> SQL Editor -> pegar este archivo -> Run
-- =====================================================================

BEGIN;

CREATE TABLE IF NOT EXISTS public.aplique_colores (
  idaplique BIGINT NOT NULL REFERENCES public.apliques(id) ON DELETE CASCADE,
  idcolor   BIGINT NOT NULL REFERENCES public.colores(id)  ON DELETE CASCADE,
  activo    BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (idaplique, idcolor)
);

-- Backfill: los colores que hoy tienen stock registrado quedan vinculados
INSERT INTO public.aplique_colores (idaplique, idcolor)
SELECT DISTINCT aplique_id, color_id FROM public.inventario
ON CONFLICT DO NOTHING;

ALTER TABLE public.aplique_colores ENABLE ROW LEVEL SECURITY;
CREATE POLICY "acceso_total_aplique_colores" ON public.aplique_colores
  FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE public.inventario
  ADD COLUMN IF NOT EXISTS activo BOOLEAN NOT NULL DEFAULT TRUE;

COMMIT;
