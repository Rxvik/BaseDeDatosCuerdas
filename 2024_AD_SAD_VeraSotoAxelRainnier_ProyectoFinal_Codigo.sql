-- Crear la base de datos si no existe
CREATE DATABASE IF NOT EXISTS Cuerdas;
USE Cuerdas;

-- Tabla Productos: Almacena información básica sobre los productos disponibles
CREATE TABLE Productos (
    ID_Producto INT AUTO_INCREMENT PRIMARY KEY, -- Identificador único del producto
    Nombre_Producto VARCHAR(100) NOT NULL,      -- Nombre del producto
    Descripcion_Producto TEXT,                  -- Descripción detallada del producto
    Precio DECIMAL(10, 2) NOT NULL              -- Precio del producto
);

-- Tabla Clientes: Guarda los datos de los clientes
CREATE TABLE Clientes (
    ID_Cliente INT AUTO_INCREMENT PRIMARY KEY,  -- Identificador único del cliente
    Nombre_Cliente VARCHAR(100) NOT NULL,       -- Nombre completo del cliente
    Direccion_Cliente VARCHAR(100),             -- Dirección del cliente
    Telefono_Cliente VARCHAR(15),               -- Teléfono del cliente
    Correo_Cliente VARCHAR(50)                  -- Correo electrónico del cliente
);

-- Tabla Unidades: Representa cada unidad física de un producto
CREATE TABLE Unidades (
    ID_Unidad INT AUTO_INCREMENT PRIMARY KEY,   -- Identificador único de la unidad
    ID_Producto INT NOT NULL,                   -- Relación con la tabla Productos
    ID_Tienda INT NOT NULL,                     -- Relación con la tienda donde se encuentra la unidad
    Estado ENUM('Disponible', 'Vendido') DEFAULT 'Disponible', -- Estado de la unidad
    FOREIGN KEY (ID_Producto) REFERENCES Productos(ID_Producto), -- Clave foránea con Productos
    FOREIGN KEY (ID_Tienda) REFERENCES Tiendas(ID_Tienda)       -- Clave foránea con Tiendas
);

-- Tabla Pedidos: Contiene los pedidos realizados por los clientes
CREATE TABLE Pedidos (
    ID_Pedido INT AUTO_INCREMENT PRIMARY KEY,   -- Identificador único del pedido
    ID_Cliente INT NOT NULL,                    -- Relación con el cliente que realiza el pedido
    Fecha_Pedido DATE NOT NULL,                 -- Fecha en la que se realiza el pedido
    Total_Pedido DECIMAL(10, 2) NOT NULL,       -- Total del pedido
    ID_Tienda INT NOT NULL,                     -- Relación con la tienda donde se realiza el pedido
    FOREIGN KEY (ID_Cliente) REFERENCES Clientes(ID_Cliente), -- Clave foránea con Clientes
    FOREIGN KEY (ID_Tienda) REFERENCES Tiendas(ID_Tienda)     -- Clave foránea con Tiendas
);

-- Tabla Detalle_Pedidos: Relaciona los pedidos con las unidades vendidas
CREATE TABLE Detalle_Pedidos (
    ID_Detalle INT AUTO_INCREMENT PRIMARY KEY,  -- Identificador único del detalle
    ID_Pedido INT NOT NULL,                     -- Relación con la tabla Pedidos
    ID_Unidad INT NOT NULL,                     -- Relación con la tabla Unidades
    FOREIGN KEY (ID_Pedido) REFERENCES Pedidos(ID_Pedido), -- Clave foránea con Pedidos
    FOREIGN KEY (ID_Unidad) REFERENCES Unidades(ID_Unidad) -- Clave foránea con Unidades
);

-- Tabla Tiendas: Contiene información de las tiendas
CREATE TABLE Tiendas (
    ID_Tienda INT AUTO_INCREMENT PRIMARY KEY,   -- Identificador único de la tienda
    Nombre_Tienda VARCHAR(100) NOT NULL,        -- Nombre de la tienda
    Direccion_Tienda VARCHAR(100),              -- Dirección de la tienda
    Telefono_Tienda VARCHAR(15),                -- Teléfono de contacto de la tienda
    Correo_Tienda VARCHAR(50)                   -- Correo electrónico de la tienda
);

-- Tabla Distribuidores: Guarda la información de los distribuidores
CREATE TABLE Distribuidores (
    ID_Distribuidor INT AUTO_INCREMENT PRIMARY KEY, -- Identificador único del distribuidor
    Nombre_Distribuidor VARCHAR(100) NOT NULL,      -- Nombre del distribuidor
    Direccion_Distribuidor VARCHAR(100),            -- Dirección del distribuidor
    Telefono_Distribuidor VARCHAR(15),              -- Teléfono de contacto del distribuidor
    Correo_Distribuidor VARCHAR(50)                 -- Correo electrónico del distribuidor
);

-- Tabla Distribuidor_Tienda: Relaciona distribuidores con tiendas
CREATE TABLE Distribuidor_Tienda (
    ID_Relacion INT AUTO_INCREMENT PRIMARY KEY, -- Identificador único de la relación
    ID_Distribuidor INT NOT NULL,               -- Relación con Distribuidores
    ID_Tienda INT NOT NULL,                     -- Relación con Tiendas
    FOREIGN KEY (ID_Distribuidor) REFERENCES Distribuidores(ID_Distribuidor), -- Clave foránea con Distribuidores
    FOREIGN KEY (ID_Tienda) REFERENCES Tiendas(ID_Tienda)                     -- Clave foránea con Tiendas
);

-- Procedimiento almacenado para agregar unidades a una tienda
DELIMITER $$
CREATE PROCEDURE AgregarUnidades(
    IN ProductoID INT, -- ID del producto a agregar
    IN TiendaID INT,   -- ID de la tienda donde se agregarán las unidades
    IN Cantidad INT     -- Cantidad de unidades a agregar
)
BEGIN
    DECLARE i INT DEFAULT 0; -- Contador para iterar
    WHILE i < Cantidad DO
        INSERT INTO Unidades (ID_Producto, ID_Tienda) -- Agregar unidad con producto y tienda específicos
        VALUES (ProductoID, TiendaID);
        SET i = i + 1; -- Incrementar contador
    END WHILE;
END$$
DELIMITER ;

-- Trigger para actualizar el estado de las unidades y verificar disponibilidad
DELIMITER $$
CREATE TRIGGER ActualizarStockYEstado
AFTER INSERT ON Detalle_Pedidos
FOR EACH ROW
BEGIN
    DECLARE unidades_disponibles INT;

    -- Contar unidades disponibles del producto en la tienda
    SELECT COUNT(*) INTO unidades_disponibles
    FROM Unidades
    WHERE ID_Producto = (SELECT ID_Producto FROM Unidades WHERE ID_Unidad = NEW.ID_Unidad)
      AND ID_Tienda = (SELECT ID_Tienda FROM Unidades WHERE ID_Unidad = NEW.ID_Unidad)
      AND Estado = 'Disponible';

    -- Verificar si hay unidades disponibles
    IF unidades_disponibles > 0 THEN
        UPDATE Unidades
        SET Estado = 'Vendido' -- Marcar unidad como vendida
        WHERE ID_Unidad = NEW.ID_Unidad;
    ELSE
        SIGNAL SQLSTATE '45000' -- Generar error si no hay stock
        SET MESSAGE_TEXT = 'No hay unidades disponibles en la tienda para el producto especificado';
    END IF;
END$$
DELIMITER ;

-- Vista para relacionar distribuidores con tiendas
CREATE VIEW Vista_Distribuidor_Tienda AS
SELECT 
    dt.ID_Relacion AS ID_Relacion,
    d.Nombre_Distribuidor AS Nombre_Distribuidor,
    t.Nombre_Tienda AS Nombre_Tienda
FROM 
    Distribuidor_Tienda dt
JOIN 
    Distribuidores d ON dt.ID_Distribuidor = d.ID_Distribuidor
JOIN 
    Tiendas t ON dt.ID_Tienda = t.ID_Tienda;

-- Vista para mostrar pedidos con la cantidad de unidades compradas
CREATE OR REPLACE VIEW Vista_Pedidos AS
SELECT 
    p.ID_Pedido,
    p.ID_Cliente,
    p.Fecha_Pedido,
    p.Total_Pedido,
    p.ID_Tienda,
    COALESCE(COUNT(dp.ID_Unidad), 0) AS Cantidad_Unidades -- Maneja casos sin unidades asociadas
FROM 
    Pedidos p
LEFT JOIN 
    Detalle_Pedidos dp ON p.ID_Pedido = dp.ID_Pedido
GROUP BY 
    p.ID_Pedido;

-- Datos de Prueba y Demostracion de Funcionamiento
-- Usando el simbolo del rayo o bien usando la combinacion de teclas Ctrl + Enter, ejecutar las siguientes lineas
-- Si es la primera vez que se usa la base de datos, para usos posteriores solo ejecutar la linea USE Cuerdas; 
CREATE DATABASE IF NOT EXISTS Cuerdas;
USE Cuerdas;

-- Una vez ejecutadas las lineas anteriores, ejecutar cada linea anterior que comience con CREATE ya sea TABLE, PROCEDURE O VIEW

-- Ingresar el producto a vender
SELECT * FROM Productos; -- Con esta linea verificamos que no hay productos registrados en la tabla 
INSERT INTO Productos (ID_Producto, Nombre_Producto, Descripcion_Producto, Precio) -- Ingresar los datos del producto a vender
VALUES (1, 'Cuerdas de Guitarra con Tecnologia de Brillo', 'Cuerdas de Guitarra que generan luz propia', 400.00);
SELECT * FROM Productos; -- Verificar que el producto ingresado se agrego correctamente a la tabla

-- Ingresar una lista de clientes
SELECT * FROM Clientes; -- Con esta linea verificamos que no hay clientes registrados en la tabla
INSERT INTO Clientes (Nombre_Cliente, Direccion_Cliente, Telefono_Cliente, Correo_Cliente) -- Ingresar los datos de clientes de prueba
VALUES ('Cliente1', 'Calle Ficticia 123', '4645874545', 'cliente1@outlook.com'),
	   ('Cliente2', 'Calle Ficticia 456', '4646257893', 'cliente2@outlook.com'),
       ('Cliente3', 'Calle Ficticia 789', '4646548585', 'cliente3@outlook.com'),
       ('Cliente4', 'Calle Ficticia 682', '4641234567', 'cliente4@outlook.com'),
	   ('Cliente5', 'Calle Ficticia 321', '4648972523', 'cliente5@outlook.com');
SELECT * FROM Clientes; -- Verificar que los clientes ingresados se agregaron correctamente a la tabla

-- Ingresar las tiendas donde se venderan los productos
SELECT * FROM Tiendas; -- Con esta linea verificamos que no hay tiendas registradas en la tabla 
INSERT INTO Tiendas (Nombre_Tienda, Direccion_Tienda, Telefono_Tienda, Correo_Tienda) -- Ingresar los datos de las tiendas donde se vendera el producto
VALUES ('Ruvik Tienda Norte', 'Zona Norte 982', '4646548585', 'ruviktiendanorte@email.com'),
	   ('Ruvik Tienda Sur', 'Zona Sur 515', '4643218967', 'ruviktiendasur@email.com'),
       ('Ruvik Tienda Centro', 'Zona Centro 478', '4643216864', 'ruviktiendacentro@email.com'),
       ('Ruvik Tienda Este', 'Zona Este 148', '4642517498', 'ruviktiendaeste@email.com'),
       ('Ruvik Tienda Oeste', 'Zona Oeste 367', '4640336568', 'ruviktiendaoeste@email.com');
SELECT * FROM Tiendas; -- Verificar que las tiendas ingresadas se agregaron correctamente a la tabla

-- Ingresar los distintos distribuidores que repartiran el producto a las tiendas
SELECT * FROM Distribuidores; -- Con esta linea verificamos que no hay distribuidores registrados en la tabla 
INSERT INTO Distribuidores (Nombre_Distribuidor, Direccion_Distribuidor, Telefono_Distribuidor, Correo_Distribuidor) -- Ingresar la informacion de los diferentes distribuidores
VALUES ('Distribuidor1', 'Calle Irreal 891', '4643218585', 'distribuidor1@email.com'),
       ('Distribuidor2', 'Calle No existente 123', '4641257845', 'distribuidor2@email.com'),
       ('Distribuidor3', 'Calle Surreal 844', '4642356969', 'distribuidor3@email.com'),
       ('Distribuidor4', 'Calle Ficticia 237', '4641028747', 'distribuidor4@email.com'),
       ('Distribuidor5', 'Calle Semireal 832', '4643268585', 'distribuidor5@email.com');
SELECT * FROM Distribuidores; -- Verificar que los distribuidores ingresados se agregaron correctamente a la tabla

-- Ingresar la relacion que tendran los distribuidores con las tiendas, es decir, que distribuidor atendera que tienda
SELECT * FROM Distribuidor_Tienda; -- Con esta linea verificamos que no hay relaciones registradas en la tabla 
INSERT INTO Distribuidor_Tienda (ID_Distribuidor, ID_Tienda)
VALUES (1, 1),
       (2, 2),
       (3, 3),
       (4, 1),
       (5, 5);
SELECT * FROM Distribuidor_Tienda;-- Verificar que las relaciones ingresadas se agregaron correctamente a la tabla
SELECT * FROM Vista_Distribuidor_Tienda; -- Esta vista simplifica la verificacion de los datos detallando la informacion del distribuidor asiganada a la tienda

SELECT * FROM Unidades; -- Con esta linea verificamos que no hay unidades registradas en la tabla 
-- Hacemos uso del procedimiento creado AgregarUnidades(ID_Producto, ID_Tienda, Cantidad de Unidades) para ingresar unidades en stock a cada tienda individualmente
-- Para este ejemplo en particular caa tienda tendra un stock de 10 unidades
CALL AgregarUnidades(1, 1, 10); -- Dado que es un procedimiento, se tiene que ejecutar individualmente por cada movimiento
CALL AgregarUnidades(1, 2, 10);
CALL AgregarUnidades(1, 3, 10);
CALL AgregarUnidades(1, 4, 10);
CALL AgregarUnidades(1, 5, 10); 
SELECT * FROM Unidades;-- Verificar que las unidades ingresadas se agregaron correctamente a la tabla

SELECT * FROM Pedidos; -- Con esta linea verificamos que no hay pedidos registrados en la tabla 
INSERT INTO Pedidos (ID_Cliente, Fecha_Pedido, Total_Pedido, ID_Tienda) -- La fecha se actualiza de manera automatica dependiendo de la fecha real
VALUES (1, CURDATE(), 400.00, 1),
       (2, CURDATE(), 800.00, 2),
       (3, CURDATE(), 1200.00, 3),
       (4, CURDATE(), 1600.00, 4),
       (5, CURDATE(), 2000.00, 5);
SELECT * FROM Pedidos; -- Verificar que los pedidos ingresados se agregaron correctamente a la tabla

SELECT * FROM Detalle_Pedidos; -- Con esta linea verificamos que no hay pedidos registrados en la tabla 
INSERT INTO Detalle_Pedidos (ID_Pedido, ID_Unidad) -- Ingresar el ID del usuario asi como la unidad vendida
VALUES 
      (1, 1), -- En este caso, el cliente 1 compro la unidad con ID 1
      (2, 11), (2, 12), -- En este caso, el cliente 2 compro las unidadescon ID 11 y 12 
      (3, 21), (3, 22), (3, 23), -- En este caso el cliente 3 compro las unidades 21, 22, y 23
      (4, 31), (4, 32), (4, 33), (4, 34), -- En este caso el cliente 4 compro las unidades 31, 32, 33 y 34
      (5, 41), (5, 42), (5, 43), (5, 44), (5, 45); -- En este caso el cliente 5 compro las unidades 41, 42, 43, 44 y 45
SELECT * FROM Detalle_Pedidos; -- Verificar que los pedidos ingresados se agregaron correctamente a la tabla
SELECT * FROM Vista_Pedidos; -- Esta vista simplifica la verificacion de los datos detallando cuantas unidades adquirio el cliente
SELECT * FROM Unidades; -- Si volvemos a verificar las unidades, veremos que las unidades ongresadas han sido marcadas como 'Vendido'
 
 -- Ejecutar la siguientes lineas una por una para reiniciar los registros 
 /*
SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE Detalle_Pedidos;
TRUNCATE TABLE Pedidos;
TRUNCATE TABLE Unidades;
TRUNCATE TABLE Distribuidor_Tienda;
TRUNCATE TABLE Distribuidores;
TRUNCATE TABLE Tiendas;
TRUNCATE TABLE Clientes;
TRUNCATE TABLE Productos;
SET FOREIGN_KEY_CHECKS = 1;
*/
