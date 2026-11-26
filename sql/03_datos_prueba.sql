-- Inserción de Datos de Prueba
SET search_path TO inventario;

TRUNCATE categoria, proveedor, producto, almacen, existencia, venta, detalle_venta,
         transferencia, movimiento_inventario, orden_compra, bitacora_reporte,
         usuario_almacen
RESTART IDENTITY CASCADE;

---rear categorías y subcategorías
INSERT INTO categoria (nombre, categoria_padre_id) VALUES
    ('Muebles',      NULL),
    ('Electrónica',  NULL),
    ('Accesorios',   NULL),
    ('Monitores',    2),
    ('Periféricos',  2),
    ('Oficina',      1),
    ('Periféricos',  3),
    ('Cables',       3);

INSERT INTO proveedor (nombre, contacto, telefono, pais) VALUES
    ('Tech Supplies Co.',  'Carlos Ruiz', '+506 8888-1111', 'Costa Rica'),
    ('Muebles & Confort',  'Ana Gómez',   '+506 8888-2222', 'Costa Rica'),
    ('Importadora Global', 'Luis Mora',   '+506 8888-3333', 'Costa Rica');

INSERT INTO almacen (nombre, ciudad, pais) VALUES
    ('Almacén Central', 'Cartago',  'Costa Rica'),   -- 1
    ('Bodega Norte',    'San José', 'Costa Rica');   -- 2

INSERT INTO producto (sku, nombre, categoria_id, proveedor_id, costo_unitario, precio_venta) VALUES
    ('ELE-101', 'Monitor Gamer 27" 144Hz',     4, 1, 180.00, 280.00),
    ('ELE-102', 'Teclado Mecánico RGB',        5, 1,  35.00,  65.00),
    ('OFF-201', 'Silla Ergonómica Ejecutiva',  6, 2, 110.00, 195.00),
    ('OFF-202', 'Escritorio Ajustable de Pie', 6, 2, 210.00, 350.00),
    ('ACC-301', 'Mousepad XL Antideslizante',  7, 3,   6.50,  15.00),
    ('ACC-302', 'Cable HDMI 2.1 2m',           8, 3,   3.00,   8.00),
    ('ELE-105', 'Cable DisplayPort 1.4',       5, 1,  15.00,  25.00);

--- Stock óptimo = stock mínimo x 3
INSERT INTO existencia (almacen_id, producto_id, pasillo, estante, cantidad, stock_minimo, stock_optimo) VALUES
    (1, 1, 'A', '01', 15,  5, 15),
    (1, 2, 'A', '02',  4, 10, 30),
    (1, 3, 'B', '05',  8,  3,  9),
    (1, 4, 'B', '06',  0,  2,  6),
    (2, 5, 'C', '01', 45, 15, 45),
    (2, 6, 'C', '03',  8, 12, 36),
    (1, 7, 'A', '03',  7,  5, 15);

INSERT INTO venta (almacen_id, fecha, usuario) VALUES
    (1, '2026-01-20 10:00', 'usr_gestor_central'),
    (1, '2026-02-14 10:00', 'usr_gestor_central'),
    (1, '2026-03-18 10:00', 'usr_gestor_central'),
    (1, '2026-04-10 10:00', 'usr_gestor_central'),
    (2, '2026-04-22 10:00', 'usr_gestor_norte'),
    (1, '2026-05-15 10:00', 'usr_gestor_central'),
    (2, '2026-06-08 10:00', 'usr_gestor_norte'),
    (1, '2026-09-12 10:00', 'usr_gestor_central'),
    (1, '2026-10-05 10:00', 'usr_gestor_central'),
    (2, '2026-10-12 10:00', 'usr_gestor_norte'),
    (1, '2026-10-22 10:00', 'usr_gestor_central'),
    (2, '2026-10-25 10:00', 'usr_gestor_norte');

INSERT INTO detalle_venta (venta_id, producto_id, cantidad, precio_unitario) VALUES
    (1, 1, 20, 280.00),
    (1, 2, 18, 65.00),
    (2, 1, 15, 280.00),
    (2, 7, 3, 25.00),
    (3, 1, 10, 280.00),
    (3, 2, 10, 65.00),
    (4, 3, 3, 195.00),
    (5, 6, 18, 8.00),
    (6, 4, 3, 350.00),
    (7, 5, 20, 15.00),
    (8, 4, 3, 350.00),
    (9, 2, 12, 65.00),
    (10, 6, 24, 8.00),
    (11, 2, 8, 65.00),
    (12, 5, 10, 15.00);

INSERT INTO movimiento_inventario (almacen_id, producto_id, tipo, cantidad, fecha, usuario, venta_id) VALUES
    (1, 1, 'ENTRADA', 50, '2026-01-05 10:00', 'usr_gestor_central', NULL),
    (1, 2, 'ENTRADA', 32, '2026-01-05 10:00', 'usr_gestor_central', NULL),
    (1, 3, 'ENTRADA', 6, '2026-01-05 10:00', 'usr_gestor_central', NULL),
    (1, 4, 'ENTRADA', 4, '2026-01-05 10:00', 'usr_gestor_central', NULL),
    (2, 5, 'ENTRADA', 25, '2026-01-05 10:00', 'usr_gestor_norte', NULL),
    (2, 6, 'ENTRADA', 20, '2026-01-05 10:00', 'usr_gestor_norte', NULL),
    (1, 7, 'ENTRADA', 10, '2026-01-05 10:00', 'usr_gestor_central', NULL),
    (1, 1, 'SALIDA', 20, '2026-01-20 10:00', 'usr_gestor_central', 1),
    (1, 2, 'SALIDA', 18, '2026-01-20 10:00', 'usr_gestor_central', 1),
    (1, 1, 'SALIDA', 15, '2026-02-14 10:00', 'usr_gestor_central', 2),
    (1, 7, 'SALIDA', 3, '2026-02-14 10:00', 'usr_gestor_central', 2),
    (1, 1, 'SALIDA', 10, '2026-03-18 10:00', 'usr_gestor_central', 3),
    (1, 2, 'SALIDA', 10, '2026-03-18 10:00', 'usr_gestor_central', 3),
    (1, 3, 'SALIDA', 3, '2026-04-10 10:00', 'usr_gestor_central', 4),
    (2, 6, 'SALIDA', 18, '2026-04-22 10:00', 'usr_gestor_norte', 5),
    (1, 4, 'SALIDA', 3, '2026-05-15 10:00', 'usr_gestor_central', 6),
    (2, 5, 'SALIDA', 20, '2026-06-08 10:00', 'usr_gestor_norte', 7),
    (1, 4, 'ENTRADA', 2, '2026-08-10 10:00', 'usr_gestor_central', NULL),
    (2, 6, 'ENTRADA', 30, '2026-09-05 10:00', 'usr_gestor_norte', NULL),
    (1, 4, 'SALIDA', 3, '2026-09-12 10:00', 'usr_gestor_central', 8),
    (1, 2, 'ENTRADA', 20, '2026-09-20 10:00', 'usr_gestor_central', NULL),
    (1, 3, 'ENTRADA', 5, '2026-10-01 10:00', 'usr_gestor_central', NULL),
    (1, 2, 'SALIDA', 12, '2026-10-05 10:00', 'usr_gestor_central', 9),
    (2, 6, 'SALIDA', 24, '2026-10-12 10:00', 'usr_gestor_norte', 10),
    (1, 1, 'ENTRADA', 10, '2026-10-15 10:00', 'usr_gestor_central', NULL),
    (2, 5, 'ENTRADA', 50, '2026-10-18 10:00', 'usr_gestor_norte', NULL),
    (1, 2, 'SALIDA', 8, '2026-10-22 10:00', 'usr_gestor_central', 11),
    (2, 5, 'SALIDA', 10, '2026-10-25 10:00', 'usr_gestor_norte', 12);

INSERT INTO orden_compra (almacen_id, producto_id, cantidad, fecha_orden, estado) VALUES
    (2, 5, 50, '2026-10-10', 'RECIBIDA'),
    (1, 2, 26, '2026-11-20', 'PENDIENTE'),
    (1, 4,  6, '2026-11-20', 'PENDIENTE');

INSERT INTO usuario_almacen (usuario, almacen_id) VALUES
    ('usr_gestor_central', 1),
    ('usr_gestor_norte',   2),
    ('usr_operador',       1);
