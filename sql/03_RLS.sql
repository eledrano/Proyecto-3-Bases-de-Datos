-- =====================================================================
-- 04_politicas_rls.sql  |  Proyecto III - Petit Monde  |  FASE 3: RLS
-- =====================================================================
SET search_path TO inventario, public;

-- ---------------------------------------------------------------------
-- 1. FUNCIÓN DE CONTEXTO DE SESIÓN
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION inventario.fn_rls_almacenes()
RETURNS integer[]
LANGUAGE sql
STABLE
PARALLEL SAFE
SET search_path = inventario, pg_temp
AS 'SELECT COALESCE(array_agg(almacen_id), ARRAY[]::integer[]) FROM inventario.usuario_almacen WHERE usuario = current_user';

COMMENT ON FUNCTION inventario.fn_rls_almacenes() IS 'RLS: almacenes asignados al usuario de la sesión (current_user)';

-- ---------------------------------------------------------------------
-- 2. ASIGNACIÓN DE USUARIOS A ALMACENES (datos de prueba)
-- ---------------------------------------------------------------------
INSERT INTO inventario.usuario_almacen (usuario, almacen_id)
SELECT v.usuario, v.almacen_id
FROM (VALUES ('usr_gestor_central', 1),
             ('usr_gestor_norte',   2),
             ('usr_operador',       1)) AS v(usuario, almacen_id)
JOIN inventario.almacen a ON a.almacen_id = v.almacen_id
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------
-- 3. HABILITAR RLS EN LAS TABLAS OPERATIVAS
-- ---------------------------------------------------------------------
ALTER TABLE inventario.existencia             ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventario.movimiento_inventario  ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventario.venta                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventario.detalle_venta          ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventario.transferencia          ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventario.orden_compra           ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventario.bitacora_reporte       ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventario.usuario_almacen        ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------
-- 4. POLÍTICAS
-- ---------------------------------------------------------------------

-- 4.1 existencia (stock por almacén)
DROP POLICY IF EXISTS rls_existencia_select_operativo ON inventario.existencia;
CREATE POLICY rls_existencia_select_operativo ON inventario.existencia
    FOR SELECT TO inventory_manager, operador
    USING (almacen_id = ANY ((SELECT inventario.fn_rls_almacenes())::integer[]));

DROP POLICY IF EXISTS rls_existencia_select_auditor ON inventario.existencia;
CREATE POLICY rls_existencia_select_auditor ON inventario.existencia
    FOR SELECT TO auditor
    USING (true);

DROP POLICY IF EXISTS rls_existencia_insert_gestor ON inventario.existencia;
CREATE POLICY rls_existencia_insert_gestor ON inventario.existencia
    FOR INSERT TO inventory_manager
    WITH CHECK (almacen_id = ANY ((SELECT inventario.fn_rls_almacenes())::integer[]));

DROP POLICY IF EXISTS rls_existencia_update_operativo ON inventario.existencia;
CREATE POLICY rls_existencia_update_operativo ON inventario.existencia
    FOR UPDATE TO inventory_manager, operador
    USING      (almacen_id = ANY ((SELECT inventario.fn_rls_almacenes())::integer[]))
    WITH CHECK (almacen_id = ANY ((SELECT inventario.fn_rls_almacenes())::integer[]));

-- 4.2 movimiento_inventario (bitácora de entradas y salidas; solo se inserta)
DROP POLICY IF EXISTS rls_movimiento_select_operativo ON inventario.movimiento_inventario;
CREATE POLICY rls_movimiento_select_operativo ON inventario.movimiento_inventario
    FOR SELECT TO inventory_manager, operador
    USING (almacen_id = ANY ((SELECT inventario.fn_rls_almacenes())::integer[]));

DROP POLICY IF EXISTS rls_movimiento_select_auditor ON inventario.movimiento_inventario;
CREATE POLICY rls_movimiento_select_auditor ON inventario.movimiento_inventario
    FOR SELECT TO auditor
    USING (true);

DROP POLICY IF EXISTS rls_movimiento_insert_operativo ON inventario.movimiento_inventario;
CREATE POLICY rls_movimiento_insert_operativo ON inventario.movimiento_inventario
    FOR INSERT TO inventory_manager, operador
    WITH CHECK (almacen_id = ANY ((SELECT inventario.fn_rls_almacenes())::integer[])
            AND usuario = current_user);
-- 4.3 venta (cabecera del pedido)
DROP POLICY IF EXISTS rls_venta_select_operativo ON inventario.venta;
CREATE POLICY rls_venta_select_operativo ON inventario.venta
    FOR SELECT TO inventory_manager, operador
    USING (almacen_id = ANY ((SELECT inventario.fn_rls_almacenes())::integer[]));

DROP POLICY IF EXISTS rls_venta_select_auditor ON inventario.venta;
CREATE POLICY rls_venta_select_auditor ON inventario.venta
    FOR SELECT TO auditor
    USING (true);

DROP POLICY IF EXISTS rls_venta_insert_operativo ON inventario.venta;
CREATE POLICY rls_venta_insert_operativo ON inventario.venta
    FOR INSERT TO inventory_manager, operador
    WITH CHECK (almacen_id = ANY ((SELECT inventario.fn_rls_almacenes())::integer[])
            AND usuario = current_user);

-- 4.4 detalle_venta: no tiene almacen_id; hereda la visibilidad de su venta.
DROP POLICY IF EXISTS rls_detalle_venta_select_operativo ON inventario.detalle_venta;
CREATE POLICY rls_detalle_venta_select_operativo ON inventario.detalle_venta
    FOR SELECT TO inventory_manager, operador
    USING (EXISTS (SELECT 1 FROM inventario.venta v WHERE v.venta_id = detalle_venta.venta_id));

DROP POLICY IF EXISTS rls_detalle_venta_select_auditor ON inventario.detalle_venta;
CREATE POLICY rls_detalle_venta_select_auditor ON inventario.detalle_venta
    FOR SELECT TO auditor
    USING (true);

DROP POLICY IF EXISTS rls_detalle_venta_insert_operativo ON inventario.detalle_venta;
CREATE POLICY rls_detalle_venta_insert_operativo ON inventario.detalle_venta
    FOR INSERT TO inventory_manager, operador
    WITH CHECK (EXISTS (SELECT 1 FROM inventario.venta v WHERE v.venta_id = detalle_venta.venta_id));

-- 4.5 transferencia: involucra dos almacenes.
DROP POLICY IF EXISTS rls_transferencia_select_gestor ON inventario.transferencia;
CREATE POLICY rls_transferencia_select_gestor ON inventario.transferencia
    FOR SELECT TO inventory_manager
    USING (almacen_origen_id  = ANY ((SELECT inventario.fn_rls_almacenes())::integer[])
        OR almacen_destino_id = ANY ((SELECT inventario.fn_rls_almacenes())::integer[]));

DROP POLICY IF EXISTS rls_transferencia_select_auditor ON inventario.transferencia;
CREATE POLICY rls_transferencia_select_auditor ON inventario.transferencia
    FOR SELECT TO auditor
    USING (true);

DROP POLICY IF EXISTS rls_transferencia_insert_gestor ON inventario.transferencia;
CREATE POLICY rls_transferencia_insert_gestor ON inventario.transferencia
    FOR INSERT TO inventory_manager
    WITH CHECK (almacen_origen_id  = ANY ((SELECT inventario.fn_rls_almacenes())::integer[])
            AND almacen_destino_id = ANY ((SELECT inventario.fn_rls_almacenes())::integer[])
            AND usuario = current_user);

-- 4.6 orden_compra
DROP POLICY IF EXISTS rls_orden_compra_select_gestor ON inventario.orden_compra;
CREATE POLICY rls_orden_compra_select_gestor ON inventario.orden_compra
    FOR SELECT TO inventory_manager
    USING (almacen_id = ANY ((SELECT inventario.fn_rls_almacenes())::integer[]));

DROP POLICY IF EXISTS rls_orden_compra_select_auditor ON inventario.orden_compra;
CREATE POLICY rls_orden_compra_select_auditor ON inventario.orden_compra
    FOR SELECT TO auditor
    USING (true);

DROP POLICY IF EXISTS rls_orden_compra_insert_gestor ON inventario.orden_compra;
CREATE POLICY rls_orden_compra_insert_gestor ON inventario.orden_compra
    FOR INSERT TO inventory_manager
    WITH CHECK (almacen_id = ANY ((SELECT inventario.fn_rls_almacenes())::integer[]));

DROP POLICY IF EXISTS rls_orden_compra_update_gestor ON inventario.orden_compra;
CREATE POLICY rls_orden_compra_update_gestor ON inventario.orden_compra
    FOR UPDATE TO inventory_manager
    USING      (almacen_id = ANY ((SELECT inventario.fn_rls_almacenes())::integer[]))
    WITH CHECK (almacen_id = ANY ((SELECT inventario.fn_rls_almacenes())::integer[]));

-- 4.7 bitacora_reporte: el gestor ve solo sus ejecuciones; el auditor ve todas.
DROP POLICY IF EXISTS rls_bitacora_select_gestor ON inventario.bitacora_reporte;
CREATE POLICY rls_bitacora_select_gestor ON inventario.bitacora_reporte
    FOR SELECT TO inventory_manager
    USING (usuario = current_user);

DROP POLICY IF EXISTS rls_bitacora_select_auditor ON inventario.bitacora_reporte;
CREATE POLICY rls_bitacora_select_auditor ON inventario.bitacora_reporte
    FOR SELECT TO auditor
    USING (true);

DROP POLICY IF EXISTS rls_bitacora_insert_gestor_auditor ON inventario.bitacora_reporte;
CREATE POLICY rls_bitacora_insert_gestor_auditor ON inventario.bitacora_reporte
    FOR INSERT TO inventory_manager, auditor
    WITH CHECK (usuario = current_user);

-- 4.8 usuario_almacen: cada usuario ve solo sus propias asignaciones; el auditor ve todas.
DROP POLICY IF EXISTS rls_usuario_almacen_select_operativo ON inventario.usuario_almacen;
CREATE POLICY rls_usuario_almacen_select_operativo ON inventario.usuario_almacen
    FOR SELECT TO inventory_manager, operador
    USING (usuario = current_user);

DROP POLICY IF EXISTS rls_usuario_almacen_select_auditor ON inventario.usuario_almacen;
CREATE POLICY rls_usuario_almacen_select_auditor ON inventario.usuario_almacen
    FOR SELECT TO auditor
    USING (true);

-- ---------------------------------------------------------------------
-- 5. ÍNDICES DE SOPORTE
-- ---------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_movimiento_almacen_producto_fecha ON inventario.movimiento_inventario (almacen_id, producto_id, fecha);
CREATE INDEX IF NOT EXISTS idx_movimiento_fecha                  ON inventario.movimiento_inventario (fecha);
CREATE INDEX IF NOT EXISTS idx_venta_almacen_fecha               ON inventario.venta (almacen_id, fecha);
CREATE INDEX IF NOT EXISTS idx_transferencia_origen              ON inventario.transferencia (almacen_origen_id);
CREATE INDEX IF NOT EXISTS idx_transferencia_destino             ON inventario.transferencia (almacen_destino_id);
CREATE INDEX IF NOT EXISTS idx_orden_compra_almacen_estado       ON inventario.orden_compra (almacen_id, estado);

-- ---------------------------------------------------------------------
-- 6. PERMISOS DE EJECUCIÓN DE LA FUNCIÓN DE RLS
-- ---------------------------------------------------------------------
SELECT inventario.aplicar_permisos_rutinas();

-- ---------------------------------------------------------------------
-- 7. VERIFICACIÓN (evidencia para el documento)
-- ---------------------------------------------------------------------
SELECT c.relname AS tabla, c.relrowsecurity AS rls_activo, c.relforcerowsecurity AS rls_forzado
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'inventario' AND c.relkind = 'r'
ORDER BY c.relrowsecurity DESC, c.relname;

SELECT tablename AS tabla, policyname AS politica, cmd AS operacion, roles
FROM pg_policies
WHERE schemaname = 'inventario'
ORDER BY tablename, cmd, policyname;

SELECT usuario, almacen_id FROM inventario.usuario_almacen ORDER BY usuario, almacen_id;