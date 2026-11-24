# Plan de trabajo — Proyecto III (Petit Monde)

**Entrega:** domingo 29/11/2026, 23:59 — un `.zip` con el PDF del documento técnico y el script `.sql`.
**Meta interna:** todo listo el domingo 29/11 a las 18:00, para dejar margen.

## Decisiones del equipo

- Se trabaja en **PostgreSQL**. Los ejemplos del enunciado en otros motores son solo referencia.
- El **Reporte 1** se llama `sp_ReporteRotacionInventario` y devuelve lo que pide su descripción, no la salida del ejemplo.
- La **prueba 10** se corre con un **rol operativo** sin permisos de reportería, no con `inventory_manager` (que sí puede ejecutar el Reporte 1).

## Reparto

### Luis — Modelo y datos (integración)

- **Fase 1:** auditoría de anomalías (actualización, inserción y borrado) con ejemplos del Anexo 1.
- **Análisis de normalización:** dependencias funcionales y paso por 1FN, 2FN, 3FN y FNBC, con la justificación de cada descomposición.
- **Modelo lógico** en `docs/modelo_logico.md` y **DER** definitivo generado desde DBeaver.
- `sql/01_esquema.sql`: tablas con PK, FK, CHECK, UNIQUE, NOT NULL y tipos adecuados (NUMERIC para montos). Incluye las tablas de apoyo que necesitan Winston y Vinicio.
- `sql/02_datos_prueba.sql`.
- `sql/07_pruebas_db_admin.sql`: pruebas 1 a 6.
- **Integración:** correr todos los scripts en una base limpia, consolidarlos en `entrega/proyecto3_petit_monde.sql`, README final y armar el `.zip`.

### Winston — Seguridad y transacciones

- **Fase 2:** `sql/03_roles_rbac.sql` con los roles `db_admin`, `inventory_manager`, `auditor` y el rol operativo de la prueba 10, usuarios de prueba y GRANT/REVOKE sobre esquema, tablas, vistas y funciones (mínimo privilegio).
- **Fase 3:** `sql/04_politicas_rls.sql` con la asignación de cada usuario a su almacén y las políticas RLS en las tablas operativas.
- **Fase 5:** `sql/06_rutinas_transaccionales.sql` con la Rutina 1 (venta y despacho) y la Rutina 2 (transferencia entre almacenes).
- `sql/08_pruebas_inventory_manager.sql`: pruebas 7 a 10.
- **Documento:** matriz de permisos RBAC, arquitectura de las políticas RLS y su prueba de funcionamiento (cómo cada rol ve datos distintos).

### Vinicio — Reportería y respaldos (armado del documento)

- **Fase 4:** `sql/05_reportes.sql` con `sp_ReporteRotacionInventario` (Reporte 1) y `sp_reporte_rotacion_inventario` (Reporte 2).
- **Fase 6:** cuadro de respaldos y recuperación (Full, Incrementales, WAL, Ubicación y retención) con los cálculos de espacio que lo justifican.
- `sql/09_pruebas_auditor.sql`: pruebas 11 a 15.
- **Documento técnico:** plantilla, integración de las secciones de los tres, capturas y exportación a PDF.

## Cronograma

| Día | Luis | Winston | Vinicio |
|---|---|---|---|
| **Lun 23** (noche) | Dependencias funcionales del Anexo 1 y anomalías con ejemplos de las filas 1001–1006. *(1 h)* | Clonar el repo y crear la rama `winston`. Borrador de la matriz RBAC (roles × operaciones). Repasar `CREATE POLICY` y `current_setting` (Lab 8). *(1,5 h)* | Clonar el repo y crear la rama `vinicio`. Fase 6: cálculos de capacidad (full, incrementales, WAL, 4 GB/mes y pico de 250 %) frente al umbral de 1 TB. *(2 h)* |
| **Mar 24** | Descomposición hasta 3FNBC y lista de tablas con PK y FK en `docs/modelo_logico.md` (**a `main` antes de las 12:00**). Acordar con Winston y Vinicio las tablas de apoyo y las firmas de las 4 funciones. DDL completo en `01_esquema.sql`. **Integrar a `main` en la noche.** *(5 h)* | Ajustar la matriz al modelo lógico. `03_roles_rbac.sql`: roles (incluido el operativo de la prueba 10), usuarios de prueba, REVOKE a `PUBLIC` y GRANT por esquema y tabla. *(2,5 h)* | Completar el cuadro de Fase 6 con su justificación. Diseñar los dos reportes: pasos, tablas temporales, columnas de salida y fórmulas. *(3 h)* |
| **Mié 25** | `02_datos_prueba.sql`: 2 almacenes, categorías, proveedores, los 6 productos del Anexo más ELE-105, stock con mínimo y óptimo, y movimientos de enero a marzo de 2026. Correr 01 y 02 en una base limpia. **Integrar a `main` a mediodía.** *(3 h)* | `04_politicas_rls.sql`: asignación de usuarios a almacén y políticas en stock, movimientos y ventas. Probar que cada gestor ve solo su almacén. *(3 h)* | `05_reportes.sql`: Reporte 1 `sp_ReporteRotacionInventario` (valor del inventario por almacén, estado de criticidad, cantidad a pedir y presupuesto; tablas temporales, CASE, COALESCE, manejo de excepciones y GRANT EXECUTE). *(3,5 h)* |
| **Jue 26** | Documento: auditoría de anomalías y análisis de normalización. Imagen del DER. *(2,5 h)* | **Integrar RBAC y RLS a `main`.** `06_rutinas_transaccionales.sql`: Rutina 1 (venta de varios productos). *(3 h)* | Reporte 2 `sp_reporte_rotacion_inventario` (validación de fechas, agregaciones, días de inventario restante, clasificación ABC y bitácora). **Integrar reportes a `main`.** *(3,5 h)* |
| **Vie 27** | `07_pruebas_db_admin.sql` (pruebas 1–6) con capturas. Revisión cruzada: que los scripts de Winston y Vinicio usen los nombres del DDL. *(2 h)* | Rutina 2 (transferencia con doble movimiento). `08_pruebas_inventory_manager.sql` (pruebas 7–10) con capturas. **Integrar a `main`.** *(3,5 h)* | `09_pruebas_auditor.sql` (pruebas 11–15) con capturas. **Integrar a `main`.** Plantilla del documento técnico. *(2 h)* |
| **Sáb 28** | Correr los scripts 01 → 09 en una base limpia, corregir con cada dueño y consolidar en `entrega/proyecto3_petit_monde.sql`. *(2 h)* | Documento: matriz de permisos RBAC y arquitectura y prueba de RLS. *(2 h)* | Armar el documento con las secciones de los tres, el cuadro de Fase 6 y las capturas. *(2,5 h)* |
| **Dom 29** | README final. Armar el `.zip` (PDF + `.sql`) y entregar. **Meta interna: 18:00.** *(1 h)* | Revisión final: que cada prueba imprima su número antes de la llamada. *(1 h)* | Revisión final del documento y exportación a PDF. *(1 h)* |
| **Total** | **16,5 h** | **16,5 h** | **17,5 h** |

## Dependencias y puntos de integración

- **Martes 12:00 — modelo lógico en `main`.** Winston lo necesita para la matriz y los GRANT; Vinicio, para diseñar los reportes.
- **Martes — acuerdos con Luis** (van en el DDL):
  - Winston: tabla de asignación usuario–almacén para el RLS; tablas de ventas, detalle, transferencias y `movimientos_inventario` para las rutinas.
  - Vinicio: stock óptimo y unidades pendientes de compra (Reporte 1) y bitácora de reportes (Reporte 2).
  - Los tres: nombre, parámetros y columnas de salida de las 4 funciones, para poder escribir las pruebas antes de que estén terminadas.
- **Martes noche — DDL en `main`.** Winston lo necesita para el RBAC y el RLS del miércoles.
- **Miércoles mediodía — datos de prueba en `main`.** Winston los necesita para probar el RLS; Vinicio, para probar los reportes.
- **Jueves — RBAC y RLS en `main`.** El RLS tiene que filtrar dentro de los reportes y las rutinas.
- **Viernes — todo el código en `main`.** El sábado se corre todo desde cero.

## Notas técnicas

**Luis (modelo y datos)**
- Las pruebas usan IDs fijos: Almacén Central = 1, Bodega Norte = 2 y Electrónica = categoría 2. Los datos de prueba deben respetarlos para que las llamadas de ejemplo funcionen tal cual.
- El Reporte 1 necesita stock óptimo y unidades pendientes, que no están en el Anexo 1. La salida esperada del Reporte 2 incluye ELE-105, que tampoco está. Hay que agregarlos al modelo y a los datos.

**Winston (RBAC, RLS y rutinas)**
- En PostgreSQL toda función nueva la puede ejecutar `PUBLIC` por defecto. Hay que hacer `REVOKE EXECUTE ... FROM PUBLIC` en cada una; si no, las pruebas 10 y 15 no van a fallar como pide el enunciado.
- No revocar el privilegio `TEMPORARY` de la base: los reportes crean tablas temporales con el rol que los ejecuta.
- El dueño de una tabla se salta el RLS. Los usuarios de prueba no deben ser dueños de las tablas, y `db_admin` puede tener `BYPASSRLS` (las pruebas 1 y 3 hablan de un "bypass autorizado").
- Una función no puede hacer `COMMIT` ni `ROLLBACK` adentro. Las rutinas se llaman dentro de `BEGIN; ... COMMIT;`, como en la prueba 9, y la validación lanza `RAISE EXCEPTION`, lo que revierte todo el bloque (pruebas 3 y 6).
- Los roles son globales del servidor: `03_roles_rbac.sql` tiene que poder correrse varias veces sin error.

**Vinicio (reportes y respaldos)**
- Las pruebas llaman a los reportes con `SELECT * FROM ...`, así que van como `FUNCTION ... RETURNS TABLE`, no como `PROCEDURE`.
- Dejarlas como `SECURITY INVOKER` (el valor por defecto), para que el RLS filtre dentro del reporte como pide la Fase 4.
- El mensaje de error del Reporte 2 debe coincidir con el del enunciado (prueba 14).
- Un producto sin salidas no puede dar `NULL` ni división entre cero en los días de inventario restante (`COALESCE`, `NULLIF`).
- El auditor es de solo lectura. Si el Reporte 2 inserta en la bitácora (el enunciado lo deja opcional), hay que resolver ese permiso con Winston.
- R-04 menciona respaldo externo o en la nube, pero las restricciones prohíben contratar nube: la propuesta debe resolver el respaldo fuera de sitio sin ella.
