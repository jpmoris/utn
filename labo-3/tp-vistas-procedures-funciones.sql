--Crear una vista llamada VW_Multas que permita visualizar la información
--de las multas con los datos del agente incluyendo apellidos y nombres,
--nombre de la localidad, patente del vehículo, fecha y monto de la multa.

CREATE VIEW VW_Multas
as
SELECT A.Apellidos, A.Nombres, M.Patente, M.FechaHora, M.Monto
FROM Multas M
INNER JOIN Agentes A on M.IDAgente = A.IDAgente
INNER JOIN Localidades L on M.IDLocalidad = L.IDLocalidad

alter view VW_Multas
as
SELECT A.Apellidos, A.Nombres, L.Localidad, M.Patente, M.FechaHora, M.Monto
FROM Multas M
INNER JOIN Agentes A on M.IDAgente = A.IDAgente
INNER JOIN Localidades L on M.IDLocalidad = L.IDLocalidad

select * from VW_Multas

--Modificar la vista VW_Multas para incluir el legajo del agente,
--la antigüedad en años, el nombre de la provincia junto al de la localidad
--y la descripción del tipo de multa.

alter view VW_Multas
as
SELECT A.LEGAJO, DateDiff(Year, 0, GetDate() - Cast(A.FechaIngreso as DateTime) ) as Antiguedad,
 A.Apellidos, A.Nombres, L.Localidad + ', ' + P.Provincia as Ubicacion, M.Patente, M.FechaHora, M.Monto, TI.Descripcion
FROM Multas M
INNER JOIN TipoInfracciones TI on m.IDTipoInfraccion = TI.IDTipoInfraccion
INNER JOIN Agentes A on M.IDAgente = A.IDAgente
INNER JOIN Localidades L on M.IDLocalidad = L.IDLocalidad
INNER JOIN Provincias P on L.IDProvincia = P.IDProvincia

--Crear un procedimiento almacenado llamado SP_MultasVehiculo que reciba un parámetro
--que representa la patente de un vehículo. Listar las multas que registra.
--Indicando fecha y hora de la multa, descripción del tipo de multa e importe a abonar.
--También una leyenda que indique si la multa fue abonada o no.

CREATE PROCEDURE SP_MultasVehiculo (
	@patente varchar(10)
)
AS
BEGIN 
	SELECT @patente = M.Patente from Multas M where @patente = M.Patente 
	BEGIN TRY
	SELECT CAST(m.FechaHora AS DATE) as Fecha, CAST(m.FechaHora AS time) as Hora, 
		CASE
			WHEN M.Pagada = 1 THEN 'Pagada'
			ELSE 'No pagada' 
		END AS 'Estado'
		FROM MULTAS M
		INNER JOIN TipoInfracciones TI on M.IDTipoInfraccion = TI.IDTipoInfraccion
		WHERE @patente = M.Patente
	END TRY
	BEGIN CATCH
	PRINT ERROR_MESSAGE()
	END CATCH
END

exec SP_MultasVehiculo 'AB123CD'

SELECT * FROM MULTAS


--Crear una función que reciba un parámetro que representa la patente de
--un vehículo y devuelva el total adeudado por ese vehículo en concepto de multas.

	SELECT M.Monto AS Monto M.Patente from Multas M where m.patente = 'ABC123'
	SELECT * FROM Pagos P INNER JOIN Multas M on P.IDMulta = M.IDMulta WHERE Patente = 'ABC123'

ALTER FUNCTION FN_DeudaVehiculo (
	@patente varchar(10)
) RETURNS Money
AS
BEGIN
	Declare @deuda money
	SELECT @deuda = ISNULL(Sum(Monto), 0) FROM Multas WHERE Patente = @patente
	return @deuda
END

select dbo.FN_DeudaVehiculo('ABC123') AS TotalDeuda FROM Multas
SELECT ISNULL(SUM(p.Importe), 0) FROM Multas M left JOIN Pagos P on P.IDMulta = M.IDMulta WHERE M.Patente = @patente AND 

SELECT dbo.FN_DeudaVehiculo('AB123CD') AS TotalDeuda


--Crear una función que reciba un parámetro que representa la patente de un vehículo y
--devuelva el total abonado por ese vehículo en concepto de multas.

ALTER FUNCTION FN_PagosVehiculo (
	@patente varchar(10)
) RETURNS Money
AS
BEGIN
	Declare @pagos money
	SELECT @pagos = ISNULL(SUM(p.Importe), 0)  FROM Multas M INNER JOIN Pagos P on P.IDMulta = M.IDMulta WHERE M.Patente = @patente 
	return @pagos
END

select Patente, dbo.FN_PagosVehiculo('ABC123') as Pagos from Multas where Patente = 'abc123'

--6
--Crear un procedimiento almacenado llamado SP_AgregarMulta que reciba
--IDTipoInfraccion, IDLocalidad, IDAgente, Patente, Fecha y hora, Monto a abonar y registre la multa.

-- verificar idtipo infraccion
-- verificar idagente
-- verificar idlocalidad


CREATE PROCEDURE SP_AgregarMulta(
	@tipoInfraccion int,
	@idLocalidad int,
	@idAgente int,
	@patente varchar(10),
	@fechahora datetime,
	@monto money
) AS
BEGIN
	BEGIN TRY
		-- COMPRUEBO EL ID TIPO INFRACCION
		IF @tipoInfraccion NOT IN (SELECT IDTipoInfraccion FROM TipoInfracciones)
			BEGIN
				RAISERROR('TIPO DE INFRACCION INVALIDO', 16, 1)
			END
		IF @idAgente NOT IN (SELECT IDAgente FROM Agentes)
			BEGIN
				RAISERROR('AGENTE INVALIDO', 16, 1)
			END
		IF @idLocalidad NOT IN (SELECT IDLocalidad from Localidades)
			BEGIN
				RAISERROR('LOCALIDAD INVALIDA', 16, 1)
			END
		-- realizo el insert
		INSERT INTO Multas (IDTipoInfraccion, IDLocalidad, IDAgente, Patente, FechaHora, Monto)
		VALUES (@tipoInfraccion, @idLocalidad, @idAgente, @patente, @fechahora, @monto)
	END TRY
	BEGIN CATCH
		PRINT ERROR_MESSAGE()
	END CATCH
END

Declare @fecha datetime
	SET @fecha = getdate()
exec SP_AgregarMulta 0, 1, 2, 'HPM727', @fecha, 15000

select * from multas

select * from localidades
select * from agentes

-- Crear un procedimiento almacenado llamado SP_ProcesarPagos que determine
-- el estado Pagada de todas las multas a partir de los pagos que se encuentran registrados
-- (La suma de todos los pagos de una multa debe ser igual o mayor al monto de la multa para
-- considerarlo Pagado).

-- DETERMINAR SI EXISTEN PAGOS DE LA ID MULTA
	-- VERIFICAR SI EL PAGO ES MAYOR AL MONTO DE ESE IDMULTA



ALTER PROCEDURE SP_ProcesarPagos
AS
BEGIN
		UPDATE Multas set Pagada = 1 WHERE IDMulta IN (SELECT M.IDMulta from PAGOS P
		INNER JOIN MULTAS M ON P.IDMULTA = M.IDMULTA
		WHERE Pagada = 0
		GROUP BY M.Patente, M.Monto, M.IDMulta 
		HAVING ISNULL(SUM(P.IMPORTE), 0) >= M.MONTO)
END

EXEC SP_ProcesarPagos
