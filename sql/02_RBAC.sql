SET search_path TO inventario, public;

-- ---------------------------------------------------------------------
-- 1. ROLES DE GRUPO
-- ---------------------------------------------------------------------
DO $$
DECLARE
    r text;
BEGIN
    FOREACH r IN ARRAY ARRAY['db_admin', 'inventory_manager', 'auditor', 'operador']
    LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r) THEN
            EXECUTE format('CREATE ROLE %I NOLOGIN', r);
        END IF;
    END LOOP;
END $$;

-- Atributos (se reaplican en cada ejecución para que el script converja)
-- db_admin: administra roles y puede saltarse el RLS (bypass autorizado).
ALTER ROLE db_admin          NOLOGIN NOSUPERUSER NOCREATEDB CREATEROLE   BYPASSRLS;
ALTER ROLE inventory_manager NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS;
ALTER ROLE auditor           NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS;
ALTER ROLE operador          NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS;

COMMENT ON ROLE db_admin          IS 'Administrador: control total de estructura, usuarios y rutinas; bypass de RLS';
COMMENT ON ROLE inventory_manager IS 'Gestor de inventario: lectura/inserción/actualización de productos y stock de su almacén';
COMMENT ON ROLE auditor           IS 'Auditor: solo lectura de reportes y movimientos; puede ejecutar el reporte de rotación';
COMMENT ON ROLE operador          IS 'Operativo (cajero/ventas): solo registra ventas; sin acceso a costos ni reportería';

-- ---------------------------------------------------------------------
-- 2. USUARIOS DE PRUEBA (LOGIN) Y MEMBRESÍAS
--    Las contraseñas son solo para el entorno académico.
-- ---------------------------------------------------------------------
DO $$
DECLARE
    es_super boolean := (SELECT rolsuper FROM pg_roles WHERE rolname = current_user);
    u text;
BEGIN
    FOREACH u IN ARRAY ARRAY['usr_admin', 'usr_gestor_central', 'usr_gestor_norte',
                             'usr_auditor', 'usr_operador']
    LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = u) THEN
            EXECUTE format('CREATE ROLE %I LOGIN', u);
        END IF;
        IF es_super THEN
            EXECUTE format('ALTER ROLE %I LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS PASSWORD %L',
                           u, 'Petit_2026');
        ELSE
            EXECUTE format('ALTER ROLE %I LOGIN PASSWORD %L', u, 'Petit_2026');
        END IF;
        EXECUTE format('ALTER ROLE %I SET search_path = inventario, public', u);
    END LOOP;
END $$;

GRANT db_admin          TO usr_admin;
GRANT inventory_manager TO usr_gestor_central, usr_gestor_norte;
GRANT auditor           TO usr_auditor;
GRANT operador          TO usr_operador;

-- Sin superusuario: quien corre el script necesita poder hacer SET ROLE a cada
-- rol y usuario para ejecutar las pruebas (7 a 15). Un superusuario ya puede.
-- En PostgreSQL 16+ se concede solo SET (sin heredar privilegios).
DO $$
DECLARE
    x text;
BEGIN
    IF NOT (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN
        FOREACH x IN ARRAY ARRAY['inventory_manager', 'auditor', 'operador', 'usr_admin',
                                 'usr_gestor_central', 'usr_gestor_norte', 'usr_auditor', 'usr_operador']
        LOOP
            IF current_setting('server_version_num')::int >= 160000 THEN
                EXECUTE format('GRANT %I TO %I WITH INHERIT FALSE, SET TRUE', x, current_user);
            ELSE
                EXECUTE format('GRANT %I TO %I', x, current_user);
            END IF;
        END LOOP;
    END IF;
END $$;

-- ---------------------------------------------------------------------
-- 3. PROPIEDAD DE LOS OBJETOS: todo pasa a db_admin
--    (el dueño de una tabla se salta el RLS; los demás roles NO son dueños)
-- ---------------------------------------------------------------------
-- Sin superusuario, para cambiar el dueño hay que poder hacer SET ROLE db_admin
-- y db_admin debe tener CREATE en la base de datos.
DO $$
BEGIN
    IF NOT (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN
        EXECUTE format('GRANT db_admin TO %I', current_user);
        EXECUTE format('GRANT CREATE ON DATABASE %I TO db_admin', current_database());
    END IF;
END $$;

ALTER SCHEMA inventario OWNER TO db_admin;

DO $$
DECLARE
    o record;
BEGIN
    FOR o IN SELECT c.relname, c.relkind
             FROM pg_class c
             JOIN pg_namespace n ON n.oid = c.relnamespace
             WHERE n.nspname = 'inventario' AND c.relkind IN ('r', 'v', 'S')
             ORDER BY c.relkind DESC          -- tablas antes que secuencias propias
    LOOP
        IF o.relkind = 'r' THEN
            EXECUTE format('ALTER TABLE inventario.%I OWNER TO db_admin', o.relname);
        ELSIF o.relkind = 'v' THEN
            EXECUTE format('ALTER VIEW inventario.%I OWNER TO db_admin', o.relname);
        ELSE
            EXECUTE format('ALTER SEQUENCE inventario.%I OWNER TO db_admin', o.relname);
        END IF;
    END LOOP;
END $$;

-- ---------------------------------------------------------------------
-- 4. DENEGAR POR DEFECTO: quitar todo a PUBLIC
-- ---------------------------------------------------------------------
-- Base de datos: solo los roles del proyecto se conectan; TEMPORARY se
-- conserva porque los reportes usan tablas temporales con el rol que los ejecuta.
DO $$
BEGIN
    EXECUTE format('REVOKE ALL ON DATABASE %I FROM PUBLIC', current_database());
    EXECUTE format('GRANT CONNECT, TEMPORARY ON DATABASE %I TO db_admin, inventory_manager, auditor, operador',
                   current_database());
END $$;

REVOKE CREATE ON SCHEMA public     FROM PUBLIC;
REVOKE ALL    ON SCHEMA inventario FROM PUBLIC;
REVOKE ALL    ON ALL TABLES    IN SCHEMA inventario FROM PUBLIC;
REVOKE ALL    ON ALL SEQUENCES IN SCHEMA inventario FROM PUBLIC;
REVOKE ALL    ON ALL FUNCTIONS IN SCHEMA inventario FROM PUBLIC;

-- En PostgreSQL toda función nueva es ejecutable por PUBLIC. Este REVOKE evita
-- que las funciones creadas después (reportes y rutinas) queden abiertas.
ALTER DEFAULT PRIVILEGES FOR ROLE db_admin REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES                   REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;  -- rol que ejecuta los scripts

-- Limpieza para que el script converja si ya se había corrido antes
REVOKE ALL ON ALL TABLES    IN SCHEMA inventario FROM inventory_manager, auditor, operador;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA inventario FROM inventory_manager, auditor, operador;

-- ---------------------------------------------------------------------
-- 5. VISTAS DE CONSULTA
--    security_invoker = true: la vista se evalúa con los privilegios y el RLS
--    de quien la consulta (REQUIERE PostgreSQL 15 o superior). Sin esta opción la vista
--    correría como su dueño (db_admin, BYPASSRLS) y filtraría datos de otros almacenes.
--    No exponen datos de proveedores y NO se otorgan al rol operador (muestran costos).
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW inventario.v_stock_detallado
WITH (security_invoker = true) AS
SELECT a.almacen_id,
       a.nombre                      AS almacen,
       p.producto_id,
       p.sku,
       p.nombre                      AS producto,
       c.nombre                      AS categoria,
       e.pasillo,
       e.estante,
       e.cantidad,
       e.stock_minimo,
       e.stock_optimo,
       p.costo_unitario,
       p.precio_venta,
       e.cantidad * p.costo_unitario AS valor_total_stock
FROM inventario.existencia e
JOIN inventario.almacen   a ON a.almacen_id   = e.almacen_id
JOIN inventario.producto  p ON p.producto_id  = e.producto_id
JOIN inventario.categoria c ON c.categoria_id = p.categoria_id;

CREATE OR REPLACE VIEW inventario.v_movimientos_detallado
WITH (security_invoker = true) AS
SELECT m.movimiento_id,
       m.fecha,
       m.tipo,
       m.cantidad,
       a.almacen_id,
       a.nombre AS almacen,
       p.sku,
       p.nombre AS producto,
       m.usuario,
       m.venta_id,
       m.transferencia_id
FROM inventario.movimiento_inventario m
JOIN inventario.almacen  a ON a.almacen_id  = m.almacen_id
JOIN inventario.producto p ON p.producto_id = m.producto_id;

ALTER VIEW inventario.v_stock_detallado       OWNER TO db_admin;

ALTER VIEW inventario.v_movimientos_detallado OWNER TO db_admin;

REVOKE ALL ON inventario.v_stock_detallado, inventario.v_movimientos_detallado FROM PUBLIC;
-- ---------------------------------------------------------------------
-- 6. PRIVILEGIOS: esquema, tablas, vistas y secuencias
-- ---------------------------------------------------------------------

-- 6.1 Esquema
GRANT USAGE ON SCHEMA inventario TO inventory_manager, auditor, operador;
GRANT ALL   ON SCHEMA inventario TO db_admin;
GRANT USAGE ON SCHEMA public     TO db_admin, inventory_manager, auditor, operador;

-- 6.2 db_admin: dueño de todo (control total sobre estructura y datos)
GRANT ALL ON ALL TABLES    IN SCHEMA inventario TO db_admin;
GRANT ALL ON ALL SEQUENCES IN SCHEMA inventario TO db_admin;

-- 6.3 inventory_manager: lectura, inserción y actualización; nunca DELETE
GRANT SELECT, INSERT, UPDATE ON inventario.categoria, inventario.proveedor, inventario.producto,
                                inventario.existencia, inventario.orden_compra
      TO inventory_manager;
GRANT SELECT, INSERT         ON inventario.venta, inventario.detalle_venta,
                                inventario.transferencia, inventario.movimiento_inventario
      TO inventory_manager;
GRANT SELECT, INSERT         ON inventario.bitacora_reporte TO inventory_manager;
GRANT SELECT                 ON inventario.almacen, inventario.usuario_almacen
      TO inventory_manager;
GRANT USAGE, SELECT ON SEQUENCE
      inventario.categoria_categoria_id_seq,
      inventario.proveedor_proveedor_id_seq,
      inventario.producto_producto_id_seq,
      inventario.orden_compra_orden_compra_id_seq,
      inventario.venta_venta_id_seq,
      inventario.transferencia_transferencia_id_seq,
      inventario.movimiento_inventario_movimiento_id_seq,
      inventario.bitacora_reporte_bitacora_id_seq
      TO inventory_manager;

-- 6.4 auditor: solo lectura de todo el esquema.
--     Única escritura: añadir filas a su propia bitácora de reportes (INSERT,
--     sin UPDATE/DELETE), necesaria para que sp_reporte_rotacion_inventario
--     deje trazabilidad. No puede modificar ningún dato operativo.
GRANT SELECT ON ALL TABLES IN SCHEMA inventario TO auditor;
GRANT INSERT ON inventario.bitacora_reporte TO auditor;
GRANT USAGE, SELECT ON SEQUENCE inventario.bitacora_reporte_bitacora_id_seq TO auditor;

-- 6.5 operador: registra ventas y descuenta stock; sin costos, sin reportes.
GRANT SELECT ON inventario.categoria, inventario.almacen, inventario.existencia,
                inventario.usuario_almacen, inventario.venta, inventario.detalle_venta
      TO operador;
-- producto: sin costo_unitario ni proveedor_id (datos financieros/comerciales)
GRANT SELECT (producto_id, sku, nombre, categoria_id, precio_venta) ON inventario.producto TO operador;
-- existencia: solo puede cambiar la cantidad (no mínimos, óptimos ni ubicación)
GRANT UPDATE (cantidad) ON inventario.existencia TO operador;
GRANT INSERT ON inventario.venta, inventario.detalle_venta, inventario.movimiento_inventario TO operador;
GRANT USAGE, SELECT ON SEQUENCE
      inventario.venta_venta_id_seq,
      inventario.movimiento_inventario_movimiento_id_seq
      TO operador;

-- 6.6 Vistas (solo si se crearon en la sección 5)
DO $$
BEGIN
    IF to_regclass('inventario.v_stock_detallado') IS NOT NULL THEN
        GRANT ALL    ON inventario.v_stock_detallado, inventario.v_movimientos_detallado TO db_admin;
        GRANT SELECT ON inventario.v_stock_detallado, inventario.v_movimientos_detallado
              TO inventory_manager, auditor;
    END IF;
END $$;

-- ---------------------------------------------------------------------
-- 7. PERMISOS DE EJECUCIÓN DE FUNCIONES (reportes y rutinas)
--    Las funciones no existen aún cuando corre este script. Esta función aplica
--    el mapa de permisos a las que existan y se invoca de nuevo al final de los
--    scripts 05 y 06.
--
--    Mapa de EXECUTE (todas: REVOKE a PUBLIC y dueño db_admin):
--      sp_reporte_valoracion_reabastecimiento -> db_admin, inventory_manager
--      sp_reporte_rotacion_inventario         -> db_admin, inventory_manager, auditor
--      sp_procesar_venta  (Rutina 1)          -> db_admin, inventory_manager, operador
--      sp_transferir_inventario (Rutina 2)    -> db_admin, inventory_manager
--      fn_rls_*  (funciones de apoyo de RLS)  -> los cuatro roles
--      cualquier otra función                 -> solo db_admin
--    Todas deben ser SECURITY INVOKER (valor por defecto) para que el RLS
--    filtre con la identidad de quien las ejecuta.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION inventario.aplicar_permisos_rutinas()
RETURNS void
LANGUAGE plpgsql
AS $fn$
DECLARE
    f record;
    n integer := 0;
BEGIN
    FOR f IN
        SELECT p.oid::regprocedure::text AS firma, p.proname
        FROM pg_proc p
        JOIN pg_namespace ns ON ns.oid = p.pronamespace
        WHERE ns.nspname = 'inventario'
          AND p.prokind IN ('f', 'p')
          AND p.prorettype <> 'trigger'::regtype
    LOOP
        EXECUTE format('ALTER FUNCTION %s OWNER TO db_admin', f.firma);
        EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC', f.firma);
        EXECUTE format('REVOKE ALL ON FUNCTION %s FROM inventory_manager, auditor, operador', f.firma);
        EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO db_admin', f.firma);

        IF f.proname = 'sp_reporte_valoracion_reabastecimiento' THEN
            EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO inventory_manager', f.firma);
        ELSIF f.proname = 'sp_reporte_rotacion_inventario' THEN
            EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO inventory_manager, auditor', f.firma);
        ELSIF f.proname = 'sp_procesar_venta' THEN
            EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO inventory_manager, operador', f.firma);
        ELSIF f.proname = 'sp_transferir_inventario' THEN
            EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO inventory_manager', f.firma);
        ELSIF f.proname LIKE 'fn\_rls\_%' THEN
            EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO inventory_manager, auditor, operador', f.firma);
        END IF;
        n := n + 1;
    END LOOP;
    RAISE NOTICE 'aplicar_permisos_rutinas: % funcion(es) procesada(s)', n;
END
$fn$;

ALTER FUNCTION inventario.aplicar_permisos_rutinas() OWNER TO db_admin;
REVOKE ALL ON FUNCTION inventario.aplicar_permisos_rutinas() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION inventario.aplicar_permisos_rutinas() TO db_admin;

SELECT inventario.aplicar_permisos_rutinas();

-- ---------------------------------------------------------------------
-- 8. VERIFICACIÓN (genera la matriz RBAC real para el documento)
--    X = privilegio de tabla completo | cols = solo algunas columnas | - = ninguno
-- ---------------------------------------------------------------------
SELECT r.rol,
       t.objeto,
       CASE WHEN has_table_privilege(r.rol, t.oid, 'SELECT') THEN 'X'
            WHEN has_any_column_privilege(r.rol, t.oid, 'SELECT') THEN 'cols' ELSE '-' END AS "SELECT",
       CASE WHEN has_table_privilege(r.rol, t.oid, 'INSERT') THEN 'X'
            WHEN has_any_column_privilege(r.rol, t.oid, 'INSERT') THEN 'cols' ELSE '-' END AS "INSERT",
       CASE WHEN has_table_privilege(r.rol, t.oid, 'UPDATE') THEN 'X'
            WHEN has_any_column_privilege(r.rol, t.oid, 'UPDATE') THEN 'cols' ELSE '-' END AS "UPDATE",
       CASE WHEN has_table_privilege(r.rol, t.oid, 'DELETE') THEN 'X' ELSE '-' END         AS "DELETE"
FROM (VALUES ('db_admin'), ('inventory_manager'), ('auditor'), ('operador')) AS r(rol)
CROSS JOIN (SELECT c.oid, c.relname AS objeto
            FROM pg_class c
            JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname = 'inventario' AND c.relkind IN ('r', 'v')) AS t
ORDER BY t.objeto, r.rol;

SELECT r.rol,
       p.oid::regprocedure::text AS funcion,
       CASE WHEN has_function_privilege(r.rol, p.oid, 'EXECUTE') THEN 'EXECUTE' ELSE '-' END AS permiso
FROM (VALUES ('db_admin'), ('inventory_manager'), ('auditor'), ('operador')) AS r(rol)
CROSS JOIN pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'inventario' AND p.prokind IN ('f', 'p')
ORDER BY funcion, r.rol;

