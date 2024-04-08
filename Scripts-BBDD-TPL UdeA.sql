--===== Requerimiento: Desnormalización en la tabla Pais de la información de la Moneda =====

--Técnica requerida: aplicar 2do nivel de normalización (remoción de dependencias parciales)

--Justificación: Los campos de una tabla que no dependan 100% de la clave primaria, sino más 
--bien que dependan parcialmente, deben ser desagregados en otra tabla.

--Consideraciones: El siguiente script se puede ejecutar múltiples veces en diferentes
--sesiones (es decir, la ejecución del script no se limita a una única sesión con una única
--base de datos), por tanto, se crea un script más robusto y desacoplado.

--Condición: La aplicación del 2do nivel de normalización solo se dará siempre que exista en
--la tabla "Pais" el campo "Moneda".

DO $$
BEGIN
IF EXISTS(SELECT column_name 
	FROM information_schema.columns
	WHERE table_name='pais' AND column_name='moneda')
	THEN
	
	--1. Crear tabla Moneda  
	CREATE TABLE Moneda(
		Id SMALLSERIAL PRIMARY KEY,
		Moneda VARCHAR(100) UNIQUE NOT NULL ,
		Sigla VARCHAR(5) DEFAULT '' NOT NULL,
		Imagen BYTEA
		);
		
	--2. Insertar los distintos tipos de moneda;
	INSERT INTO Moneda (moneda) (SELECT DISTINCT Moneda FROM Pais);
				
	--3. Crear los 3 nuevos campos para la tabla Pais (IdMoneda,Mapa,Bandera)
	ALTER TABLE Pais ADD COLUMN IdMoneda INTEGER DEFAULT 1 NOT NULL;
	ALTER TABLE Pais ADD COLUMN Mapa BYTEA;
	ALTER TABLE Pais ADD COLUMN Bandera BYTEA;
				
	--4 Definir la clave foranea IdMoneda que referencia la llave primaria Id en la tabla Moneda.
	ALTER TABLE Pais ADD CONSTRAINT fk_Pais_IdMoneda FOREIGN KEY (IdMoneda) REFERENCES Moneda(Id);

	--5. Crear indice para la tabla Moneda en el campo Moneda (Busqueda más rapida por dicho campo, nos sirve para la actualización)
	CREATE UNIQUE INDEX idx_moneda_moneda ON Moneda(Moneda);

	--6. Actualizar el campo IdMoneda de la tabla Pais siempre y cuando exista el campo Moneda
	UPDATE Pais p SET IdMoneda=(SELECT m.Id FROM Moneda m
		WHERE p.Moneda=m.Moneda);
				
	--7. Antes de aplicar un "Hard deleting" a la columna Moneda de la tabla Pais, guardemos una copia de la misma para temas de
	--auditoria e analisis historico (Similar,pero no igual, a un "Soft deletion" a toda una columna y no a un solo registro)
	CREATE TABLE Pais_backup AS TABLE Pais;
				
	--8. Eliminamos la columna Moneda de la tabla Pais puesto que ya no la necesitamos más.
	ALTER TABLE Pais DROP COLUMN Moneda;
				
	END IF;
END $$;

--Consultas de prueba:
SELECT * FROM Moneda;
SELECT * FROM Pais;
SELECT * FROM Pais_backup;


--======= Requerimiento: Agregar campos para imágenes del Mapa y la Bandera del País ========

--Consideraciones: Para que este script pueda ejecutarse más de una vez sin afectar la 
--integridad de la base de datos, se requiere verificar que los campos que se están agregando
--a la tabla Pais no existan

DO $$
BEGIN
	
	--1. Verificamos si el campo Mapa ya existe en la tabla Pais, y si no está lo creamos
	IF NOT EXISTS (SELECT column_name
		FROM information_schema.columns 
		WHERE table_name='Pais' AND column_name='Mapa')
		THEN
			ALTER TABLE Pais ADD COLUMN Mapa BYTEA;
    ELSE
		RAISE NOTICE 'El campo Mapa ya existe en la tabla Pais';
  	END IF;

	--2. Verificamos si el campo Bandera ya existe en la tabla Pais, y si no está lo creamos
	IF NOT EXISTS (SELECT column_name
		FROM information_schema.columns 
		WHERE table_name='Pais' AND column_name='Bandera')
		THEN
			ALTER TABLE Pais ADD COLUMN Bandera BYTEA;
		ELSE
			RAISE NOTICE 'El campo Bandera ya existe en la tabla Pais';
	END IF;
	
END $$;