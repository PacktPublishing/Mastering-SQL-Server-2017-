--------------------------------------------------------------------
--------	SQL Server 2017 Developer’s Guide
--------	Chapter 07 -  Temporal Tables
---------- Altering and Droping Temporal Tables
--------------------------------------------------------------------
----------------------------------
--Altering Temporal Tables
----------------------------------

-- create a temporal tabl and populate with sample data :
USE tempdb; 
CREATE TABLE dbo.Product 
( 
   ProductId INT NOT NULL CONSTRAINT PK_Product PRIMARY KEY, 
   ProductName NVARCHAR(50) NOT NULL, 
   Price MONEY NOT NULL, 
   ValidFrom DATETIME2 GENERATED ALWAYS AS ROW START NOT NULL, 
   ValidTo DATETIME2 GENERATED ALWAYS AS ROW END NOT NULL, 
   PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo) 
) 
WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = dbo.ProductHistory)); 
GO
INSERT INTO dbo.Product (ProductId,ProductName,Price)
SELECT message_id,'PROD' + CAST(message_id AS NVARCHAR), severity FROM sys.messages WHERE language_id = 1033;
GO

/*Now, you will add three new columns into the temporal table:

    A column named Color, which allows NULL values
    A column named Category, where a non-nullable value is mandatory
    A LOB column named Description
*/

--But before you add them, you will create an Extended Events (XE) session to trace what happens under the hood 
--when you add a new column to a temporal table. Use the following code to create and start the XE session:
CREATE EVENT SESSION AlteringTemporalTable ON SERVER 
ADD EVENT sqlserver.sp_statement_starting(
    WHERE (sqlserver.database_id = 2)),
ADD EVENT sqlserver.sp_statement_completed(
    WHERE (sqlserver.database_id = 2)),
ADD EVENT sqlserver.sql_statement_starting(
    WHERE (sqlserver.database_id = 2)),
ADD EVENT sqlserver.sql_statement_completed(
    WHERE (sqlserver.database_id = 2))
ADD TARGET package0.event_file (SET filename = N'AlteringTemporalTable')
WITH (MAX_DISPATCH_LATENCY = 1 SECONDS)
GO
ALTER EVENT SESSION AlteringTemporalTable ON SERVER STATE = start; 
GO

--Now you can now execute 3 ALTER statements and check teh contecnt of the XE session to see what happenned

--This action will be done instantely
ALTER TABLE dbo.Product ADD Color NVARCHAR(15);
GO
--This action will be online (metadata operation) in the Enterprise Edition only. 
ALTER TABLE dbo.Product ADD Category SMALLINT NOT NULL CONSTRAINT DF_Category DEFAULT 1;
GO
--This action will be offline opeation in all editions 
--(you can see in XE session that SQL Server executed the UPDATE Products SET Description = DEFAULT statement)
ALTER TABLE dbo.Product ADD Description NVARCHAR(MAX) NOT NULL CONSTRAINT DF_Description DEFAULT N'N/A';
GO

--You can also use the ALTER TABLE statement to add the HIDDEN attribute to period columns or to remove it. 
--This code line adds the HIDDEN attribute to the columns ValidFrom and ValidTo:
ALTER TABLE dbo.Product ALTER COLUMN Valid_From ADD HIDDEN;
ALTER TABLE dbo.Product ALTER COLUMN Valid_From DROP HIDDEN;
GO

--Clearly, you can also remove the HIDDEN attribute:
ALTER TABLE dbo.Product ALTER COLUMN ValidFrom DROP HIDDEN; 
ALTER TABLE dbo.Product ALTER COLUMN ValidTo DROP HIDDEN; 
GO


--there are some changes that are not allowed for temporal tables:

--Adding SPARSE column
ALTER TABLE dbo.Product ADD Size NVARCHAR(5) SPARSE;
/*Result:
Msg 11418, Level 16, State 2, Line 20
Cannot alter table 'ProductHistory' because the table either contains sparse columns or a column set column which are incompatible with compression. 
*/
--Adding an identity column as follows
ALTER TABLE dbo.Product ADD ProductNumber INT IDENTITY (1,1);
/*Result:
Msg 13704, Level 16, State 1, Line 26
System-versioned table schema modification failed because history table 'WideWorldImporters.dbo.ProductHistory' has IDENTITY column specification. Consider dropping all IDENTITY column specifications and trying again.
*/

--If you need to add an identity column to a temporal table, you have to set its SYSTEM_VERSIONING attribute to false. 
--The following code demonstrates, how to add the identity column ProductNumber and the sparse column Size into the temporal table dbo.Product::
ALTER TABLE dbo.ProductHistory REBUILD PARTITION=ALL WITH (DATA_COMPRESSION=NONE); 
GO
BEGIN TRAN   
	ALTER TABLE dbo.Product SET (SYSTEM_VERSIONING = OFF);   
	ALTER TABLE dbo.Product ADD Size NVARCHAR(5) SPARSE;   
	ALTER TABLE dbo.ProductHistory ADD Size NVARCHAR(5) SPARSE;   
	ALTER TABLE dbo.Product ADD ProductNumber INT IDENTITY (1,1);   
	ALTER TABLE dbo.ProductHistory ADD ProductNumber INT NOT NULL DEFAULT 0;   
	ALTER TABLE dbo.Product SET(SYSTEM_VERSIONING = ON (HISTORY_TABLE = dbo. ProductHistory));   
COMMIT;   


----------------------------------
--Droping Temporal Tables
----------------------------------
--You cannot drop a system-versioned temporal table, you need tp set the SYSTEM_VERSIONING option to OFF
ALTER TABLE dbo.Product SET (SYSTEM_VERSIONING = OFF);   
ALTER TABLE dbo.Product DROP PERIOD FOR SYSTEM_TIME;   
GO
