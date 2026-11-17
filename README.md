# Proyecto III — Auditoría y rediseño de la base de datos de inventarios de Petit Monde

Curso de Bases de Datos · Proyecto grupal · Entrega: 22/11/2026, 23:59 (`.zip` con el PDF y el `.sql`)

## Integrantes

- Luis
- P1
- P2

## Tecnologías

- **Base de datos:** PostgreSQL (administrada con DBeaver)
- **Reportes y rutinas transaccionales:** funciones en PL/pgSQL

## Estructura del repositorio

```
Proyecto-3-Bases-de-Datos/
├── sql/        Scripts numerados en el orden de ejecución
├── docs/       Modelo lógico, DER, plan de trabajo y flujo de Git
├── capturas/   Evidencias de las pruebas por rol
├── entrega/    Script consolidado y PDF que van en el .zip
└── README.md
```

## Scripts

Siguen el orden del enunciado: esquema, datos de prueba, roles y RLS, procedimientos y pruebas.

| Archivo | Contenido | Responsable |
|---|---|---|
| `01_esquema.sql` | Esquema normalizado (3FNBC): tablas, PK, FK, CHECK, UNIQUE y NOT NULL | Luis |
| `02_datos_prueba.sql` | Datos de prueba | Luis |
| `03_roles_rbac.sql` | Roles, usuarios de prueba y permisos (GRANT/REVOKE) | P1 |
| `04_politicas_rls.sql` | Seguridad a nivel de fila por almacén | P1 |
| `05_reportes.sql` | `sp_reporte_valoracion_reabastecimiento` y `sp_reporte_rotacion_inventario` | P2 |
| `06_rutinas_transaccionales.sql` | Venta y despacho (checkout) y transferencia entre almacenes | P1 |
| `07_pruebas_db_admin.sql` | Pruebas 1 a 6 | Luis |
| `08_pruebas_inventory_manager.sql` | Pruebas 7 a 10 | P1 |
| `09_pruebas_auditor.sql` | Pruebas 11 a 15 | P2 |

## Cómo ejecutar

1. Crear en PostgreSQL una base de datos llamada `petit_monde`.
2. Ejecutar los scripts de `sql/` en orden numérico, o el script consolidado `entrega/proyecto3_petit_monde.sql`.

## Documentación del equipo

- [Plan de trabajo y cronograma](docs/plan_de_trabajo.md)
- [Flujo de trabajo con Git](docs/flujo_git.md)
