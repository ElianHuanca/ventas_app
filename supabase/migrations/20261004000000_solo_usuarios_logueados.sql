-- =====================================================================
-- Aplicada en producción el 2026-10-04, con todos los celulares ya en la
-- versión con login.
--
-- Cierra la base a quien no inició sesión (rol anon). Solo usuarios de
-- Supabase Auth (rol authenticated) leen y escriben tablas y RPC.
-- La web (sitio) NO se rompe: las vistas *_web siguen con SELECT para anon
-- (corren con permisos del owner, no dependen de las tablas base).
-- Desde acá, una app sin login no funciona contra esta base.
--
-- Modelo: "logueado = acceso total" (las cuentas las crea el dueño desde el
-- dashboard; el registro público está desactivado). Si más adelante hay
-- roles (p. ej. vendedores sin acceso a precxcompra), se reemplazan estas
-- políticas por otras que miren una tabla de perfiles.
-- =====================================================================

BEGIN;

DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'aplique_colores', 'apliques', 'categorias', 'colores',
    'detalle_produccion', 'detalle_ventas', 'detalle_ventas_apliques',
    'inventario', 'producciones', 'sucursales', 'tela_colores',
    'tela_fotos', 'tela_sucursales', 'telas', 'ventas', 'ventas_apliques'
  ] LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', 'acceso_total_' || t, t);
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', 'solo_logueados_' || t, t);
    EXECUTE format(
      'CREATE POLICY %I ON public.%I FOR ALL TO authenticated USING (true) WITH CHECK (true)',
      'solo_logueados_' || t, t);
  END LOOP;
END $$;

-- anon fuera de las tablas y de las funciones
REVOKE ALL ON ALL TABLES    IN SCHEMA public FROM anon;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon;
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM anon;

-- ...y de lo que se cree en el futuro (el dump daba ALL por defecto)
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON TABLES    FROM anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON SEQUENCES FROM anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON FUNCTIONS FROM anon;

-- La web: solo estas vistas, solo lectura
GRANT SELECT ON public.sucursales_web, public.top_telas_web,
                public.catalogo_telas_web, public.catalogo_apliques_web
TO anon;

COMMIT;
