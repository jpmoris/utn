--1
--Hacer un trigger que al eliminar un Agente su estado Activo pase de True a False.

create Trigger TR_EliminarAgente on Agentes
INSTEAD OF DELETE
as
BEGIN
    Declare @IDAgente int
    SELECT @IDAgente = IDAgente from DELETED

    Declare @Activo BIT
    SELECT @Activo = Activo from Agentes WHERE IDAgente = @IDAgente

    if @Activo = 1 BEGIN
        Update Agentes set Activo = 0 where IDAgente = @IDAgente
    END
    ELSE BEGIN
        RAISERROR('Error al dar de baja el agente', 16, 0)
    END
END
GO
select * from agentes
GO
delete from Agentes where IDAgente = 12354
GO
--///////////////////////////////////////

--Modificar el trigger anterior para que al eliminar un Agente y
--si su estado Activo ya se encuentra previamente en False entonces realice las siguientes acciones:
--Cambiar todas las multas efectuadas por ese agente y establecer el valor NULL al campo IDAgente.
--Eliminar físicamente al agente en cuestión.

--Utilizar una transacción
ALTER Trigger TR_EliminarAgente on Agentes
INSTEAD OF DELETE
as
BEGIN
    Declare @IDAgente int
    SELECT @IDAgente = IDAgente from DELETED

    Declare @Activo BIT
    SELECT @Activo = Activo from Agentes WHERE IDAgente = @IDAgente

    if @Activo = 1 BEGIN
        Update Agentes set Activo = 0 where IDAgente = @IDAgente
    END

    if @Activo = 0 BEGIN
        -- TRANSACCIÓN
        BEGIN TRY
            BEGIN TRANSACTION
            --Cambiar todas las multas efectuadas por ese agente y establecer el valor NULL al campo IDAgente.
            --Eliminar físicamente al agente en cuestión.

            UPDATE Multas set IDAgente = NULL WHERE IDAgente = @IDAgente
            DELETE FROM Agentes where IDAgente = @IDAgente

            COMMIT TRANSACTION
        END TRY
        BEGIN CATCH
            PRINT ERROR_MESSAGE()
            ROLLBACK TRANSACTION
        END CATCH

    END
END

SELECT * FROM multas M WHERE M.IDMulta IN (12,42,43,44)


select * from Agentes WHERE ACTIVO = 0

DELETE FROM Agentes where IDAgente = 2

--

--Hacer un trigger que al insertar una multa realice las siguientes acciones:
--No permitir su ingreso si el Agente asociado a la multa no se encuentra Activo.   OK
    --Indicarlo con un mensaje claro que sea considerado una excepción.             OK
--Establecer el Monto de la multa a partir del tipo de infracción.                  OK
--Aplicar un recargo del 20% al monto de la multa si no es la primera multa del vehículo en el año. OK
--Aplicar un recargo del 25% al monto de la multa si no es la primera multa del mismo tipo de infracción del vehículo en el año. OK
--Establecer el estado Pagada como False.
GO
SELECT * FROM MULTAS
GO

ALTER TRIGGER TR_InsertarMulta ON Multas
INSTEAD OF INSERT
AS
BEGIN

    Declare @IDMulta INT
    SET @IDMulta = @@identity

    Declare @IDLocalidad Int
    select @IDLocalidad = IDLocalidad from INSERTED

    Declare @IDTipoInfraccion INT
    SELECT @IDTipoInfraccion = IDTipoInfraccion from INSERTED

    Declare @IDAgente INT
    SELECT @IDAgente = IDAgente from INSERTED 

    Declare @Activo BIT
    SELECT @ACTIVO = Activo from Agentes WHERE IDAgente = @IDAgente

    Declare @Patente varchar(10)
    SELECT @Patente = Patente from Inserted

    Declare @Fecha datetime
    SELECT @Fecha = FechaHora from INSERTED

    BEGIN TRY

        BEGIN TRANSACTION

            IF @Activo = 0 BEGIN
                RAISERROR('El agente está inactivo. Debe estar activo para labrar una multa', 16, 0)
            END
            --Declaro el monto
            Declare @Monto money
            SELECT @Monto = TI.ImporteReferencia FROM TipoInfracciones TI WHERE IDTipoInfraccion = @IDTipoInfraccion

            --Aplicar un recargo del 20% al monto de la multa si no es la primera multa del vehículo en el año.
            IF( dbo.FN_BuscarMultasPorAnio('HPM727', @Fecha) > 0 ) BEGIN
                SET @Monto = @Monto + (@Monto * 0.20)
            END

            --Aplicar un recargo del 25% al monto de la multa si no es la primera multa del mismo tipo de infracción del vehículo en el año.
            IF( dbo.FN_BuscarMultasPorTIyAnio('HPM727', @IDTipoInfraccion, @Fecha) > 0 ) BEGIN
                SET @Monto = @Monto + (@Monto * 0.25)
            END

            --Establecer el estado Pagada como False.
            -- REALIZO EL INSERT
            INSERT INTO Multas (IDLocalidad, IDTipoInfraccion, IDAgente, Patente, Monto, FechaHora, Pagada)
            VALUES (@IDLocalidad, @IDTipoInfraccion, @IDAgente, @Patente, @Monto, @Fecha, 0)

        COMMIT TRANSACTION

    END TRY
    BEGIN CATCH
        PRINT ERROR_MESSAGE()
        ROLLBACK TRANSACTION
    END CATCH
END
go

INSERT INTO Multas (IDLocalidad, IDTipoInfraccion, Monto, IDAgente, Patente, FechaHora)
VALUES (1, 4,100, 2, 'HPM727', GETDATE())


select * from multas

SELECT * FROM Agentes


select * from TipoInfracciones

---
--Hacer un trigger que al insertar un pago realice las siguientes verificaciones:
--Verificar que la multa que se intenta pagar se encuentra no pagada.
--Verificar que el Importe del pago sumado a los importes anteriores de la misma multa no superen el Monto a abonar.

--En ambos casos impedir el ingreso y mostrar un mensaje acorde.

--Si el pago cubre el Monto de la multa ya sea con un pago único o siendo la suma de pagos
--anteriores sobre la misma multa. Además de registrar el pago se debe modificar el estado Pagada de la multa relacionada.
GO
select Pagada from Multas
go
ALTER TRIGGER TR_InsertarPago ON Pagos
AFTER INSERT
AS
BEGIN
--Verificar que la multa que se intenta pagar se encuentra no pagada.
    BEGIN TRY

        BEGIN TRANSACTION
        
        Declare @IDMulta bigint
        SELECT @IDMulta = IDMulta from Inserted
        --Verificar que la multa que se intenta pagar se encuentra no pagada.
        Declare @Pagada BIT
        SELECT @Pagada = Pagada from Multas WHERE IDMulta = @IDMulta

        if @Pagada = 1 BEGIN
            RAISERROR('Esta multa ya fue pagada', 16, 1)
        END

        --Verificar que el Importe del pago sumado a los importes anteriores de la misma multa no superen el Monto a abonar.
        Declare @MontoMulta money
        Declare @MontoPagado money
        SELECT @MontoMulta = Monto FROM Multas WHERE IDMulta = @IDMulta
        SELECT @MontoPagado = ISNULL(SUM(Importe),0) FROM Pagos WHERE IDMulta = @IDMulta

        if @MontoPagado > @MontoMulta BEGIN
            RAISERROR('Ocurrió un error al procesar el pago, el importe total pagado supera el monto de la multa', 16, 1)
        END 

--Si el pago cubre el Monto de la multa ya sea con un pago único o siendo la suma de pagos
--anteriores sobre la misma multa. Además de registrar el pago se debe modificar el estado Pagada de la multa relacionada.
        Declare @PagoRealizado money
        SELECT @PagoRealizado = Importe from inserted 
        IF @PagoRealizado = 0 BEGIN
            RAISERROR('Realice un pago mayor a $0', 16, 1)
        END
        IF @PagoRealizado = @MontoMulta BEGIN
            PRINT 'Multa abonada en un pago único'
        END
        ELSE IF @PagoRealizado < @MontoMulta BEGIN
            PRINT 'Multa abonada parcialmente. Restan $' + CAST( (@MontoMulta - @MontoPagado) AS VARCHAR(10)) + ' por cancelar la multa'
        END

        -- SOLO CUANDO SE TERMINA DE PAGAR FINALMENTE LA MULTA SE CAMBIA A PAGADA
        IF @MontoPagado = @MontoMulta BEGIN
            UPDATE Multas SET Pagada = 1 WHERE IDMulta = @IDMulta
        END

    COMMIT TRANSACTION
    END TRY

    BEGIN CATCH
        ROLLBACK TRANSACTION
        PRINT ERROR_MESSAGE()
    END CATCH

END




-- DEBERIA SALTAR QUE YA ESTA PAGA

INSERT INTO Pagos (IDMulta, Importe, Fecha, IDMedioPago)
VALUES (7, 2000, GETDATE(), 1)

UPDATE Multas SET Pagada = 0 WHERE IDMulta = 7



SELECT * FROM pagos

select * from multas


SELECT ISNULL(SUM(Importe),0) FROM Pagos WHERE IDMulta = 7
select * from multas where idmulta = 7










--//////////////////////////////////////////////////////////////////////////////////
GO
SELECT COUNT(*) FROM Multas WHERE YEAR(2023) = YEAR(2023) AND PATENTE = 'HPM727'
go

SELECT * FROM MULTAS WHERE PATENTE = 'HPM727'

GO
--Aplicar un recargo del 20% al monto de la multa si no es la primera multa del vehículo en el año.
CREATE FUNCTION FN_BuscarMultasPorAnio (
    @patente varchar(10),
    @fecha datetime
) RETURNS Int
AS
BEGIN
    Declare @cant int
    SELECT @cant = count(*) from Multas WHERE year(FechaHora) = year(@fecha) AND Patente = @patente
    return @cant
END
GO
Declare @Fecha datetime
set @Fecha = getdate()
select dbo.FN_BuscarMultasPorAnio('HPM727', @Fecha)

go

--Aplicar un recargo del 25% al monto de la multa si no es la primera multa del mismo tipo de infracción del vehículo en el año.
CREATE FUNCTION FN_BuscarMultasPorTIyAnio (
    @patente varchar(10),
    @tipoinfraccion int,
    @fecha datetime
) RETURNS Int
AS
BEGIN
    Declare @cant int
    SELECT @cant = count(*) from Multas WHERE IDTipoInfraccion = @tipoinfraccion and year(FechaHora) = year(@fecha) AND Patente = @patente
    return @cant
END
GO
Declare @Fecha datetime
set @Fecha = getdate()
select dbo.FN_BuscarMultasPorTIyAnio('HPM727', 2, @Fecha)
--//////////////////////////////////////////////////////////////////////////////////
