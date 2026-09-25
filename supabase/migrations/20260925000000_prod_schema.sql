


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE OR REPLACE FUNCTION "public"."resumen_ventas"("desde" "text", "hasta" "text") RETURNS TABLE("total" numeric, "ganancias" numeric, "descuento" numeric)
    LANGUAGE "sql" STABLE
    AS $$
  SELECT COALESCE(SUM(total), 0), COALESCE(SUM(ganancias), 0), COALESCE(SUM(descuento), 0)
  FROM public.ventas
  WHERE fecha >= desde AND fecha <= hasta;
$$;


ALTER FUNCTION "public"."resumen_ventas"("desde" "text", "hasta" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."resumen_ventas_apliques"("desde" "text", "hasta" "text") RETURNS TABLE("total" numeric, "ganancias" numeric, "descuento" numeric)
    LANGUAGE "sql" STABLE
    AS $$
  SELECT COALESCE(SUM(total), 0), COALESCE(SUM(ganancias), 0), COALESCE(SUM(descuento), 0)
  FROM public.ventas_apliques
  WHERE fecha >= desde AND fecha <= hasta;
$$;


ALTER FUNCTION "public"."resumen_ventas_apliques"("desde" "text", "hasta" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rls_auto_enable"() RETURNS "event_trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog'
    AS $$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$$;


ALTER FUNCTION "public"."rls_auto_enable"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."top_productos"("desde" "text", "hasta" "text") RETURNS TABLE("nombre" "text", "total_vendido" numeric, "total_cantidad" numeric)
    LANGUAGE "sql" STABLE
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


ALTER FUNCTION "public"."top_productos"("desde" "text", "hasta" "text") OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."aplique_colores" (
    "idaplique" bigint NOT NULL,
    "idcolor" bigint NOT NULL,
    "activo" boolean DEFAULT true NOT NULL
);


ALTER TABLE "public"."aplique_colores" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."apliques" (
    "id" bigint NOT NULL,
    "nombre" "text" NOT NULL,
    "costo_fabricacion" numeric DEFAULT 0 NOT NULL,
    "categoria_id" bigint,
    "activo" boolean DEFAULT true NOT NULL,
    "tamanio" "text",
    "ancho_cm" numeric(5,2),
    "alto_cm" numeric(5,2)
);


ALTER TABLE "public"."apliques" OWNER TO "postgres";


ALTER TABLE "public"."apliques" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."apliques_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."categorias" (
    "id" bigint NOT NULL,
    "nombre" "text" NOT NULL,
    "slug" "text" NOT NULL,
    "activo" boolean DEFAULT true NOT NULL
);


ALTER TABLE "public"."categorias" OWNER TO "postgres";


ALTER TABLE "public"."categorias" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."categorias_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."colores" (
    "id" bigint NOT NULL,
    "nombre" "text" NOT NULL,
    "hex" "text",
    "activo" boolean DEFAULT true NOT NULL
);


ALTER TABLE "public"."colores" OWNER TO "postgres";


ALTER TABLE "public"."colores" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."colores_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."detalle_produccion" (
    "id" bigint NOT NULL,
    "idproduccion" bigint NOT NULL,
    "idaplique" bigint NOT NULL,
    "idcolor" bigint NOT NULL,
    "cantidad" numeric NOT NULL,
    CONSTRAINT "detalle_produccion_cantidad_check" CHECK (("cantidad" > (0)::numeric))
);


ALTER TABLE "public"."detalle_produccion" OWNER TO "postgres";


ALTER TABLE "public"."detalle_produccion" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."detalle_produccion_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."detalle_ventas" (
    "id" bigint NOT NULL,
    "nombre" "text",
    "precio" numeric(12,2) NOT NULL,
    "cantidad" numeric(12,2) NOT NULL,
    "total" numeric(14,2),
    "ganancias" numeric(14,2),
    "idtelas" bigint NOT NULL,
    "idventa" bigint NOT NULL
);


ALTER TABLE "public"."detalle_ventas" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."detalle_ventas_apliques" (
    "id" bigint NOT NULL,
    "idventa" bigint NOT NULL,
    "idapliques" bigint NOT NULL,
    "idcolor" bigint NOT NULL,
    "nombre" "text",
    "precio" numeric DEFAULT 0 NOT NULL,
    "cantidad" numeric DEFAULT 0 NOT NULL,
    "total" numeric DEFAULT 0 NOT NULL,
    "ganancias" numeric DEFAULT 0 NOT NULL
);


ALTER TABLE "public"."detalle_ventas_apliques" OWNER TO "postgres";


ALTER TABLE "public"."detalle_ventas_apliques" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."detalle_ventas_apliques_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



ALTER TABLE "public"."detalle_ventas" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."detalle_ventas_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."inventario" (
    "sucursal_id" bigint NOT NULL,
    "aplique_id" bigint NOT NULL,
    "color_id" bigint NOT NULL,
    "stock" numeric DEFAULT 0 NOT NULL,
    "activo" boolean DEFAULT true NOT NULL
);


ALTER TABLE "public"."inventario" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."producciones" (
    "id" bigint NOT NULL,
    "fecha" "date" DEFAULT CURRENT_DATE NOT NULL,
    "sucursal_id" bigint NOT NULL
);


ALTER TABLE "public"."producciones" OWNER TO "postgres";


ALTER TABLE "public"."producciones" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."producciones_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."sucursales" (
    "id" bigint NOT NULL,
    "nombre" "text" NOT NULL,
    "slug" "text",
    "latitud" "text",
    "longitud" "text",
    "direccion" "text",
    "activo" boolean DEFAULT true NOT NULL
);


ALTER TABLE "public"."sucursales" OWNER TO "postgres";


ALTER TABLE "public"."sucursales" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."sucursales_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE OR REPLACE VIEW "public"."sucursales_web" AS
 SELECT "id",
    "nombre",
    "slug",
    "direccion",
    "latitud",
    "longitud"
   FROM "public"."sucursales"
  WHERE "activo"
  ORDER BY "id";


ALTER VIEW "public"."sucursales_web" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."tela_colores" (
    "idtela" bigint NOT NULL,
    "idcolor" bigint NOT NULL,
    "activo" boolean DEFAULT true NOT NULL
);


ALTER TABLE "public"."tela_colores" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."tela_fotos" (
    "id" bigint NOT NULL,
    "idtela" bigint NOT NULL,
    "url" "text" NOT NULL,
    "activo" boolean DEFAULT true NOT NULL
);


ALTER TABLE "public"."tela_fotos" OWNER TO "postgres";


ALTER TABLE "public"."tela_fotos" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."tela_fotos_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."tela_sucursales" (
    "idtela" bigint NOT NULL,
    "idsucursal" bigint NOT NULL,
    "activo" boolean DEFAULT true NOT NULL
);


ALTER TABLE "public"."tela_sucursales" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."telas" (
    "id" bigint NOT NULL,
    "nombre" "text" NOT NULL,
    "precxmen" numeric(12,2) DEFAULT 0 NOT NULL,
    "precxmay" numeric(12,2) DEFAULT 0 NOT NULL,
    "precxrollo" numeric(12,2) DEFAULT 0 NOT NULL,
    "precxcompra" numeric(12,2) DEFAULT 0 NOT NULL,
    "categoria_id" bigint,
    "slug" "text",
    "descripcion" "text",
    "ancho" numeric(4,2),
    "activo" boolean DEFAULT true NOT NULL
);


ALTER TABLE "public"."telas" OWNER TO "postgres";


ALTER TABLE "public"."telas" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."telas_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE OR REPLACE VIEW "public"."top_telas_web" AS
 WITH "ranking" AS (
         SELECT "dv"."idtelas" AS "id",
            "sum"("dv"."total") AS "monto"
           FROM "public"."detalle_ventas" "dv"
          GROUP BY "dv"."idtelas"
        )
 SELECT "row_number"() OVER (ORDER BY "r"."monto" DESC NULLS LAST) AS "posicion",
    "t"."id",
    "t"."nombre",
    "t"."slug",
    "t"."descripcion",
    "t"."ancho",
    NULLIF("t"."precxmen", (0)::numeric) AS "precio_metro",
    NULLIF("t"."precxmay", (0)::numeric) AS "precio_mayor",
    NULLIF("t"."precxrollo", (0)::numeric) AS "precio_rollo",
    "foto"."url" AS "foto"
   FROM (("ranking" "r"
     JOIN "public"."telas" "t" ON ((("t"."id" = "r"."id") AND "t"."activo")))
     LEFT JOIN LATERAL ( SELECT "f"."url"
           FROM "public"."tela_fotos" "f"
          WHERE (("f"."idtela" = "t"."id") AND "f"."activo")
          ORDER BY "f"."id"
         LIMIT 1) "foto" ON (true))
  WHERE (("t"."precxmen" > (0)::numeric) OR ("t"."precxmay" > (0)::numeric) OR ("t"."precxrollo" > (0)::numeric))
  ORDER BY "r"."monto" DESC NULLS LAST
 LIMIT 6;


ALTER VIEW "public"."top_telas_web" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."ventas" (
    "id" bigint NOT NULL,
    "fecha" "text" NOT NULL,
    "total" numeric(14,2) DEFAULT 0 NOT NULL,
    "ganancias" numeric(14,2) DEFAULT 0 NOT NULL,
    "descuento" numeric(14,2) DEFAULT 0 NOT NULL,
    "idsucursales" bigint NOT NULL
);


ALTER TABLE "public"."ventas" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."ventas_apliques" (
    "id" bigint NOT NULL,
    "fecha" "text" NOT NULL,
    "total" numeric(14,2) DEFAULT 0 NOT NULL,
    "ganancias" numeric(14,2) DEFAULT 0 NOT NULL,
    "descuento" numeric(14,2) DEFAULT 0 NOT NULL,
    "idsucursales" bigint NOT NULL
);


ALTER TABLE "public"."ventas_apliques" OWNER TO "postgres";


ALTER TABLE "public"."ventas_apliques" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."ventas_apliques_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



ALTER TABLE "public"."ventas" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."ventas_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



ALTER TABLE ONLY "public"."aplique_colores"
    ADD CONSTRAINT "aplique_colores_pkey" PRIMARY KEY ("idaplique", "idcolor");



ALTER TABLE ONLY "public"."apliques"
    ADD CONSTRAINT "apliques_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."categorias"
    ADD CONSTRAINT "categorias_nombre_key" UNIQUE ("nombre");



ALTER TABLE ONLY "public"."categorias"
    ADD CONSTRAINT "categorias_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."categorias"
    ADD CONSTRAINT "categorias_slug_key" UNIQUE ("slug");



ALTER TABLE ONLY "public"."colores"
    ADD CONSTRAINT "colores_nombre_key" UNIQUE ("nombre");



ALTER TABLE ONLY "public"."colores"
    ADD CONSTRAINT "colores_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."detalle_produccion"
    ADD CONSTRAINT "detalle_produccion_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."detalle_ventas_apliques"
    ADD CONSTRAINT "detalle_ventas_apliques_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."detalle_ventas"
    ADD CONSTRAINT "detalle_ventas_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."inventario"
    ADD CONSTRAINT "inventario_pkey" PRIMARY KEY ("sucursal_id", "aplique_id", "color_id");



ALTER TABLE ONLY "public"."producciones"
    ADD CONSTRAINT "producciones_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."sucursales"
    ADD CONSTRAINT "sucursales_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."sucursales"
    ADD CONSTRAINT "sucursales_slug_key" UNIQUE ("slug");



ALTER TABLE ONLY "public"."tela_colores"
    ADD CONSTRAINT "tela_colores_pkey" PRIMARY KEY ("idtela", "idcolor");



ALTER TABLE ONLY "public"."tela_fotos"
    ADD CONSTRAINT "tela_fotos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."tela_sucursales"
    ADD CONSTRAINT "tela_sucursales_pkey" PRIMARY KEY ("idtela", "idsucursal");



ALTER TABLE ONLY "public"."telas"
    ADD CONSTRAINT "telas_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."telas"
    ADD CONSTRAINT "telas_slug_key" UNIQUE ("slug");



ALTER TABLE ONLY "public"."ventas_apliques"
    ADD CONSTRAINT "ventas_apliques_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."ventas"
    ADD CONSTRAINT "ventas_pkey" PRIMARY KEY ("id");



CREATE INDEX "idx_detalle_ventas_idtelas" ON "public"."detalle_ventas" USING "btree" ("idtelas");



CREATE INDEX "idx_detalle_ventas_idventa" ON "public"."detalle_ventas" USING "btree" ("idventa");



CREATE INDEX "idx_producciones_fecha" ON "public"."producciones" USING "btree" ("fecha");



CREATE INDEX "idx_ventas_fecha" ON "public"."ventas" USING "btree" ("fecha");



CREATE INDEX "idx_ventas_idsucursales" ON "public"."ventas" USING "btree" ("idsucursales");



ALTER TABLE ONLY "public"."aplique_colores"
    ADD CONSTRAINT "aplique_colores_idaplique_fkey" FOREIGN KEY ("idaplique") REFERENCES "public"."apliques"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."aplique_colores"
    ADD CONSTRAINT "aplique_colores_idcolor_fkey" FOREIGN KEY ("idcolor") REFERENCES "public"."colores"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."apliques"
    ADD CONSTRAINT "apliques_categoria_id_fkey" FOREIGN KEY ("categoria_id") REFERENCES "public"."categorias"("id");



ALTER TABLE ONLY "public"."detalle_produccion"
    ADD CONSTRAINT "detalle_produccion_idaplique_fkey" FOREIGN KEY ("idaplique") REFERENCES "public"."apliques"("id");



ALTER TABLE ONLY "public"."detalle_produccion"
    ADD CONSTRAINT "detalle_produccion_idcolor_fkey" FOREIGN KEY ("idcolor") REFERENCES "public"."colores"("id");



ALTER TABLE ONLY "public"."detalle_produccion"
    ADD CONSTRAINT "detalle_produccion_idproduccion_fkey" FOREIGN KEY ("idproduccion") REFERENCES "public"."producciones"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."detalle_ventas_apliques"
    ADD CONSTRAINT "detalle_ventas_apliques_idapliques_fkey" FOREIGN KEY ("idapliques") REFERENCES "public"."apliques"("id");



ALTER TABLE ONLY "public"."detalle_ventas_apliques"
    ADD CONSTRAINT "detalle_ventas_apliques_idcolor_fkey" FOREIGN KEY ("idcolor") REFERENCES "public"."colores"("id");



ALTER TABLE ONLY "public"."detalle_ventas_apliques"
    ADD CONSTRAINT "detalle_ventas_apliques_idventa_fkey" FOREIGN KEY ("idventa") REFERENCES "public"."ventas_apliques"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."detalle_ventas"
    ADD CONSTRAINT "detalle_ventas_idtelas_fkey" FOREIGN KEY ("idtelas") REFERENCES "public"."telas"("id");



ALTER TABLE ONLY "public"."detalle_ventas"
    ADD CONSTRAINT "detalle_ventas_idventa_fkey" FOREIGN KEY ("idventa") REFERENCES "public"."ventas"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."inventario"
    ADD CONSTRAINT "inventario_aplique_id_fkey" FOREIGN KEY ("aplique_id") REFERENCES "public"."apliques"("id");



ALTER TABLE ONLY "public"."inventario"
    ADD CONSTRAINT "inventario_color_id_fkey" FOREIGN KEY ("color_id") REFERENCES "public"."colores"("id");



ALTER TABLE ONLY "public"."inventario"
    ADD CONSTRAINT "inventario_sucursal_id_fkey" FOREIGN KEY ("sucursal_id") REFERENCES "public"."sucursales"("id");



ALTER TABLE ONLY "public"."producciones"
    ADD CONSTRAINT "producciones_sucursal_id_fkey" FOREIGN KEY ("sucursal_id") REFERENCES "public"."sucursales"("id");



ALTER TABLE ONLY "public"."tela_colores"
    ADD CONSTRAINT "tela_colores_idcolor_fkey" FOREIGN KEY ("idcolor") REFERENCES "public"."colores"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tela_colores"
    ADD CONSTRAINT "tela_colores_idtela_fkey" FOREIGN KEY ("idtela") REFERENCES "public"."telas"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tela_fotos"
    ADD CONSTRAINT "tela_fotos_idtela_fkey" FOREIGN KEY ("idtela") REFERENCES "public"."telas"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tela_sucursales"
    ADD CONSTRAINT "tela_sucursales_idsucursal_fkey" FOREIGN KEY ("idsucursal") REFERENCES "public"."sucursales"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tela_sucursales"
    ADD CONSTRAINT "tela_sucursales_idtela_fkey" FOREIGN KEY ("idtela") REFERENCES "public"."telas"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."telas"
    ADD CONSTRAINT "telas_categoria_id_fkey" FOREIGN KEY ("categoria_id") REFERENCES "public"."categorias"("id");



ALTER TABLE ONLY "public"."ventas_apliques"
    ADD CONSTRAINT "ventas_apliques_idsucursales_fkey" FOREIGN KEY ("idsucursales") REFERENCES "public"."sucursales"("id");



ALTER TABLE ONLY "public"."ventas"
    ADD CONSTRAINT "ventas_idsucursales_fkey" FOREIGN KEY ("idsucursales") REFERENCES "public"."sucursales"("id");



CREATE POLICY "acceso_total_aplique_colores" ON "public"."aplique_colores" USING (true) WITH CHECK (true);



CREATE POLICY "acceso_total_apliques" ON "public"."apliques" USING (true) WITH CHECK (true);



CREATE POLICY "acceso_total_categorias" ON "public"."categorias" USING (true) WITH CHECK (true);



CREATE POLICY "acceso_total_colores" ON "public"."colores" USING (true) WITH CHECK (true);



CREATE POLICY "acceso_total_detalle_produccion" ON "public"."detalle_produccion" USING (true) WITH CHECK (true);



CREATE POLICY "acceso_total_detalle_ventas" ON "public"."detalle_ventas" USING (true) WITH CHECK (true);



CREATE POLICY "acceso_total_detalle_ventas_apliques" ON "public"."detalle_ventas_apliques" USING (true) WITH CHECK (true);



CREATE POLICY "acceso_total_inventario" ON "public"."inventario" USING (true) WITH CHECK (true);



CREATE POLICY "acceso_total_producciones" ON "public"."producciones" USING (true) WITH CHECK (true);



CREATE POLICY "acceso_total_sucursales" ON "public"."sucursales" USING (true) WITH CHECK (true);



CREATE POLICY "acceso_total_tela_colores" ON "public"."tela_colores" USING (true) WITH CHECK (true);



CREATE POLICY "acceso_total_tela_fotos" ON "public"."tela_fotos" USING (true) WITH CHECK (true);



CREATE POLICY "acceso_total_tela_sucursales" ON "public"."tela_sucursales" USING (true) WITH CHECK (true);



CREATE POLICY "acceso_total_telas" ON "public"."telas" USING (true) WITH CHECK (true);



CREATE POLICY "acceso_total_ventas" ON "public"."ventas" USING (true) WITH CHECK (true);



CREATE POLICY "acceso_total_ventas_apliques" ON "public"."ventas_apliques" USING (true) WITH CHECK (true);



ALTER TABLE "public"."aplique_colores" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."apliques" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."categorias" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."colores" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."detalle_produccion" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."detalle_ventas" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."detalle_ventas_apliques" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."inventario" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."producciones" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sucursales" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."tela_colores" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."tela_fotos" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."tela_sucursales" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."telas" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."ventas" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."ventas_apliques" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";






















































































































































GRANT ALL ON FUNCTION "public"."resumen_ventas"("desde" "text", "hasta" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."resumen_ventas"("desde" "text", "hasta" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."resumen_ventas"("desde" "text", "hasta" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."resumen_ventas_apliques"("desde" "text", "hasta" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."resumen_ventas_apliques"("desde" "text", "hasta" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."resumen_ventas_apliques"("desde" "text", "hasta" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."rls_auto_enable"() TO "anon";
GRANT ALL ON FUNCTION "public"."rls_auto_enable"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."rls_auto_enable"() TO "service_role";



GRANT ALL ON FUNCTION "public"."top_productos"("desde" "text", "hasta" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."top_productos"("desde" "text", "hasta" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."top_productos"("desde" "text", "hasta" "text") TO "service_role";


















GRANT ALL ON TABLE "public"."aplique_colores" TO "anon";
GRANT ALL ON TABLE "public"."aplique_colores" TO "authenticated";
GRANT ALL ON TABLE "public"."aplique_colores" TO "service_role";



GRANT ALL ON TABLE "public"."apliques" TO "anon";
GRANT ALL ON TABLE "public"."apliques" TO "authenticated";
GRANT ALL ON TABLE "public"."apliques" TO "service_role";



GRANT ALL ON SEQUENCE "public"."apliques_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."apliques_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."apliques_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."categorias" TO "anon";
GRANT ALL ON TABLE "public"."categorias" TO "authenticated";
GRANT ALL ON TABLE "public"."categorias" TO "service_role";



GRANT ALL ON SEQUENCE "public"."categorias_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."categorias_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."categorias_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."colores" TO "anon";
GRANT ALL ON TABLE "public"."colores" TO "authenticated";
GRANT ALL ON TABLE "public"."colores" TO "service_role";



GRANT ALL ON SEQUENCE "public"."colores_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."colores_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."colores_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."detalle_produccion" TO "anon";
GRANT ALL ON TABLE "public"."detalle_produccion" TO "authenticated";
GRANT ALL ON TABLE "public"."detalle_produccion" TO "service_role";



GRANT ALL ON SEQUENCE "public"."detalle_produccion_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."detalle_produccion_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."detalle_produccion_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."detalle_ventas" TO "anon";
GRANT ALL ON TABLE "public"."detalle_ventas" TO "authenticated";
GRANT ALL ON TABLE "public"."detalle_ventas" TO "service_role";



GRANT ALL ON TABLE "public"."detalle_ventas_apliques" TO "anon";
GRANT ALL ON TABLE "public"."detalle_ventas_apliques" TO "authenticated";
GRANT ALL ON TABLE "public"."detalle_ventas_apliques" TO "service_role";



GRANT ALL ON SEQUENCE "public"."detalle_ventas_apliques_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."detalle_ventas_apliques_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."detalle_ventas_apliques_id_seq" TO "service_role";



GRANT ALL ON SEQUENCE "public"."detalle_ventas_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."detalle_ventas_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."detalle_ventas_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."inventario" TO "anon";
GRANT ALL ON TABLE "public"."inventario" TO "authenticated";
GRANT ALL ON TABLE "public"."inventario" TO "service_role";



GRANT ALL ON TABLE "public"."producciones" TO "anon";
GRANT ALL ON TABLE "public"."producciones" TO "authenticated";
GRANT ALL ON TABLE "public"."producciones" TO "service_role";



GRANT ALL ON SEQUENCE "public"."producciones_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."producciones_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."producciones_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."sucursales" TO "anon";
GRANT ALL ON TABLE "public"."sucursales" TO "authenticated";
GRANT ALL ON TABLE "public"."sucursales" TO "service_role";



GRANT ALL ON SEQUENCE "public"."sucursales_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."sucursales_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."sucursales_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."sucursales_web" TO "anon";
GRANT ALL ON TABLE "public"."sucursales_web" TO "authenticated";
GRANT ALL ON TABLE "public"."sucursales_web" TO "service_role";



GRANT ALL ON TABLE "public"."tela_colores" TO "anon";
GRANT ALL ON TABLE "public"."tela_colores" TO "authenticated";
GRANT ALL ON TABLE "public"."tela_colores" TO "service_role";



GRANT ALL ON TABLE "public"."tela_fotos" TO "anon";
GRANT ALL ON TABLE "public"."tela_fotos" TO "authenticated";
GRANT ALL ON TABLE "public"."tela_fotos" TO "service_role";



GRANT ALL ON SEQUENCE "public"."tela_fotos_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."tela_fotos_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."tela_fotos_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."tela_sucursales" TO "anon";
GRANT ALL ON TABLE "public"."tela_sucursales" TO "authenticated";
GRANT ALL ON TABLE "public"."tela_sucursales" TO "service_role";



GRANT ALL ON TABLE "public"."telas" TO "anon";
GRANT ALL ON TABLE "public"."telas" TO "authenticated";
GRANT ALL ON TABLE "public"."telas" TO "service_role";



GRANT ALL ON SEQUENCE "public"."telas_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."telas_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."telas_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."top_telas_web" TO "anon";
GRANT ALL ON TABLE "public"."top_telas_web" TO "authenticated";
GRANT ALL ON TABLE "public"."top_telas_web" TO "service_role";



GRANT ALL ON TABLE "public"."ventas" TO "anon";
GRANT ALL ON TABLE "public"."ventas" TO "authenticated";
GRANT ALL ON TABLE "public"."ventas" TO "service_role";



GRANT ALL ON TABLE "public"."ventas_apliques" TO "anon";
GRANT ALL ON TABLE "public"."ventas_apliques" TO "authenticated";
GRANT ALL ON TABLE "public"."ventas_apliques" TO "service_role";



GRANT ALL ON SEQUENCE "public"."ventas_apliques_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."ventas_apliques_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."ventas_apliques_id_seq" TO "service_role";



GRANT ALL ON SEQUENCE "public"."ventas_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."ventas_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."ventas_id_seq" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";



































