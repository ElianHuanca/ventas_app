-- =====================================================================
-- apliques: dimensiones en cm (reemplaza al campo tamanio en la UI)
-- =====================================================================
-- `tamanio` ('Grande', 'Chico', ...) era redundante: ya va en el nombre
-- del aplique. Se agregan las dimensiones reales del producto.
-- La columna `tamanio` se conserva (dato histórico parseado en la
-- migración 06) pero la app ya no la edita.
--
-- Aplicar: Supabase Studio -> SQL Editor -> pegar este archivo -> Run
-- =====================================================================

BEGIN;

ALTER TABLE public.apliques
  ADD COLUMN IF NOT EXISTS ancho_cm numeric(5, 2),
  ADD COLUMN IF NOT EXISTS alto_cm  numeric(5, 2);

COMMIT;
