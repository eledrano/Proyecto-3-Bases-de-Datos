--- Esquema normalizado

DROP SCHEMA IF EXISTS inventario CASCADE;
CREATE SCHEMA inventario;
SET search_path TO inventario;

--- Tablas normalizadas del anexo 1
CREATE TABLE categoria (
    categoria_id        SERIAL       PRIMARY KEY,
    nombre              VARCHAR(60)  NOT NULL,
    categoria_padre_id  INT          REFERENCES categoria (categoria_id),
	--- Relación unaria de categorías y subcategorías
    CONSTRAINT ck_categoria_padre CHECK (categoria_padre_id <> categoria_id),
    CONSTRAINT uq_subcategoria UNIQUE (categoria_padre_id, nombre)
);

CREATE UNIQUE INDEX uq_categoria_principal
    ON categoria (nombre)
    WHERE categoria_padre_id IS NULL;

CREATE TABLE proveedor (
    proveedor_id  SERIAL        PRIMARY KEY,
    nombre        VARCHAR(100)  NOT NULL UNIQUE,
    contacto      VARCHAR(100)  NOT NULL,
    telefono      VARCHAR(20)   NOT NULL,
    pais          VARCHAR(60)   NOT NULL
);

CREATE TABLE producto (
    producto_id     SERIAL         PRIMARY KEY,
    sku             VARCHAR(20)    NOT NULL UNIQUE,
    nombre          VARCHAR(100)   NOT NULL,
    categoria_id    INT            NOT NULL REFERENCES categoria (categoria_id),
    proveedor_id    INT            NOT NULL REFERENCES proveedor (proveedor_id),
    costo_unitario  NUMERIC(12,2)  NOT NULL,
    precio_venta    NUMERIC(12,2)  NOT NULL,
    -- Formato del SKU
    CONSTRAINT ck_producto_sku    CHECK (sku ~ '^[A-Z]{3}-[0-9]{3}$'),
    CONSTRAINT ck_producto_costo  CHECK (costo_unitario >= 0),
    CONSTRAINT ck_producto_precio CHECK (precio_venta >= 0)
);

--- Almacen con dividisón de ciudad y país
CREATE TABLE almacen (
    almacen_id  SERIAL        PRIMARY KEY,
    nombre      VARCHAR(100)  NOT NULL UNIQUE,
    ciudad      VARCHAR(60)   NOT NULL,
    pais        VARCHAR(60)   NOT NULL
);

--- Existencia de stock: valor total y estado se calcularan en los reportes
CREATE TABLE existencia (
    almacen_id    INT          NOT NULL REFERENCES almacen (almacen_id),
    producto_id   INT          NOT NULL REFERENCES producto (producto_id),
    pasillo       VARCHAR(5)   NOT NULL,
    estante       VARCHAR(5)   NOT NULL,
    cantidad      INT          NOT NULL DEFAULT 0,
    stock_minimo  INT          NOT NULL,
    stock_optimo  INT          NOT NULL,
    CONSTRAINT pk_existencia PRIMARY KEY (almacen_id, producto_id),
    CONSTRAINT ck_existencia_cantidad CHECK (cantidad >= 0),
    CONSTRAINT ck_existencia_minimo   CHECK (stock_minimo >= 0),
    CONSTRAINT ck_existencia_optimo   CHECK (stock_optimo >= stock_minimo)
);

--- Tablas de apoyo
CREATE TABLE venta (
    venta_id    SERIAL       PRIMARY KEY,
    almacen_id  INT          NOT NULL REFERENCES almacen (almacen_id),
    fecha       TIMESTAMP    NOT NULL DEFAULT now(),
    usuario     VARCHAR(63)  NOT NULL DEFAULT current_user
);

CREATE TABLE detalle_venta (
    venta_id         INT            NOT NULL REFERENCES venta (venta_id),
    producto_id      INT            NOT NULL REFERENCES producto (producto_id),
    cantidad         INT            NOT NULL,
    precio_unitario  NUMERIC(12,2)  NOT NULL,

    CONSTRAINT pk_detalle_venta PRIMARY KEY (venta_id, producto_id),
    CONSTRAINT ck_detalle_cantidad CHECK (cantidad > 0),
    CONSTRAINT ck_detalle_precio   CHECK (precio_unitario >= 0)
);

CREATE TABLE transferencia (
    transferencia_id    SERIAL       PRIMARY KEY,
    almacen_origen_id   INT          NOT NULL REFERENCES almacen (almacen_id),
    almacen_destino_id  INT          NOT NULL REFERENCES almacen (almacen_id),
    producto_id         INT          NOT NULL REFERENCES producto (producto_id),
    cantidad            INT          NOT NULL,
    fecha               TIMESTAMP    NOT NULL DEFAULT now(),
    usuario             VARCHAR(63)  NOT NULL DEFAULT current_user,

    CONSTRAINT ck_transferencia_cantidad CHECK (cantidad > 0),
    CONSTRAINT ck_transferencia_almacenes CHECK (almacen_origen_id <> almacen_destino_id)
);

--- Movimiento Inventario para llevar el control de entradas y salidas de productos
CREATE TABLE movimiento_inventario (
    movimiento_id     SERIAL       PRIMARY KEY,
    almacen_id        INT          NOT NULL,
    producto_id       INT          NOT NULL,
    tipo              VARCHAR(10)  NOT NULL,
    cantidad          INT          NOT NULL,
    fecha             TIMESTAMP    NOT NULL DEFAULT now(),
    usuario           VARCHAR(63)  NOT NULL DEFAULT current_user,
    venta_id          INT          REFERENCES venta (venta_id),
    transferencia_id  INT          REFERENCES transferencia (transferencia_id),
    CONSTRAINT fk_movimiento_existencia FOREIGN KEY (almacen_id, producto_id) REFERENCES existencia (almacen_id, producto_id),
    CONSTRAINT ck_movimiento_tipo     CHECK (tipo IN ('ENTRADA', 'SALIDA')),
    CONSTRAINT ck_movimiento_cantidad CHECK (cantidad > 0),
    CONSTRAINT ck_movimiento_origen   CHECK (venta_id IS NULL OR transferencia_id IS NULL)
);

CREATE TABLE orden_compra (
    orden_compra_id  SERIAL       PRIMARY KEY,
    almacen_id       INT          NOT NULL REFERENCES almacen (almacen_id),
    producto_id      INT          NOT NULL REFERENCES producto (producto_id),
    cantidad         INT          NOT NULL,
    fecha_orden      DATE         NOT NULL DEFAULT CURRENT_DATE,
    estado           VARCHAR(10)  NOT NULL DEFAULT 'PENDIENTE',

    CONSTRAINT ck_orden_cantidad CHECK (cantidad > 0),
    CONSTRAINT ck_orden_estado   CHECK (estado IN ('PENDIENTE', 'RECIBIDA'))
);

CREATE TABLE bitacora_reporte (
    bitacora_id  SERIAL       PRIMARY KEY,
    reporte      VARCHAR(60)  NOT NULL,
    parametros   TEXT,
    usuario      VARCHAR(63)  NOT NULL DEFAULT current_user,
    fecha        TIMESTAMP    NOT NULL DEFAULT now()
);

--- Usuario almacen: asignación de almacen para cada usuario
CREATE TABLE usuario_almacen (
    usuario     VARCHAR(63)  NOT NULL,
    almacen_id  INT          NOT NULL REFERENCES almacen (almacen_id),

    CONSTRAINT pk_usuario_almacen PRIMARY KEY (usuario, almacen_id)
);
