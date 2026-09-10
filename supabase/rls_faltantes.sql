-- =====================================================================
-- Políticas RLS faltantes — tablas sin política devuelven [] vía PostgREST
-- =====================================================================
-- RLS está habilitado en todas las tablas, pero solo 7 tenían política.
-- Sin política, el rol anon no ve NADA: colores, inventario y apliques
-- devolvían vacío en la app.
--
-- Mismo criterio que el resto del esquema (app sin login, un solo dueño):
-- política abierta FOR ALL. El cierre fino queda documentado en el vault
-- (notas/pendientes/rls-abierta-a-anon.md).
--
-- Aplicar: Supabase Studio -> SQL Editor -> pegar este archivo -> Run
-- =====================================================================

BEGIN;

CREATE POLICY "acceso_total_categorias" ON public.categorias
  FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "acceso_total_colores" ON public.colores
  FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "acceso_total_tela_colores" ON public.tela_colores
  FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "acceso_total_tela_fotos" ON public.tela_fotos
  FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "acceso_total_apliques" ON public.apliques
  FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "acceso_total_inventario" ON public.inventario
  FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "acceso_total_detalle_ventas_apliques" ON public.detalle_ventas_apliques
  FOR ALL USING (true) WITH CHECK (true);

COMMIT;
