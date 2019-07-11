--------------------------------------------------------------------
--------	SQL Server 2017 Developer’s Guide
--------	Chapter 07 -  Temporal Tables
---------- Temporal Tables with Memory-Optimized Tables
--------------------------------------------------------------------


USE WideWorldImporters;
GO
--ensure that the dbo.Product temporal table does not exist
ALTER TABLE dbo.Product SET (SYSTEM_VERSIONING = OFF);   
ALTER TABLE dbo.Product DROP PERIOD FOR SYSTEM_TIME;   
DROP TABLE IF EXISTS dbo.Product;
DROP TABLE IF EXISTS dbo.ProductHistory;
GO

--create a memory-optimized temporal table
CREATE TABLE dbo.Product
(
   ProductId INT NOT NULL PRIMARY KEY NONCLUSTERED,
   ProductName NVARCHAR(50) NOT NULL,
   Price MONEY NOT NULL,
   ValidFrom DATETIME2 GENERATED ALWAYS AS ROW START HIDDEN NOT NULL,
   ValidTo DATETIME2 GENERATED ALWAYS AS ROW END HIDDEN NOT NULL,
   PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo)
)
WITH (MEMORY_OPTIMIZED = ON, DURABILITY = SCHEMA_AND_DATA, SYSTEM_VERSIONING = ON (HISTORY_TABLE = dbo.ProductHistory));
GO

--After the execution of this query, you can see that one memory-optimized table is
SELECT CONCAT(SCHEMA_NAME(schema_id),'.', name) AS table_name, is_memory_optimized, temporal_type_desc 
FROM sys.tables WHERE name IN ('Product','ProductHistory');
GO
/*
table_name        is_memory_optimized temporal_type_desc
----------------- ------------------- ------------------------------
dbo.Product         1                 SYSTEM_VERSIONED_TEMPORAL_TABLE
dbo.ProductHistory  0                 HISTORY_TABLE
*/

--Here is the code which you can use to find its name and properties
SELECT CONCAT(SCHEMA_NAME(schema_id),'.', name) AS table_name, internal_type_desc 
FROM sys.internal_tables WHERE name = CONCAT('memory_optimized_history_table_', OBJECT_ID('dbo.Product'));
GO
/*
table_name                                            internal_type_desc
--------------------------------------------------  ----------------------------------
sys.memory_optimized_history_table_1575676661        INTERNAL_TEMPORAL_HISTORY_TABLE
*/

--Use the following code to create a native compiled stored procedure that handles inserting and updating products:
CREATE OR ALTER PROCEDURE dbo.SaveProduct  
(   
@ProductId INT,
@ProductName NVARCHAR(50),
@Price MONEY
)   
WITH NATIVE_COMPILATION, SCHEMABINDING, EXECUTE AS OWNER   
AS    
   BEGIN ATOMIC WITH   
   (TRANSACTION ISOLATION LEVEL = SNAPSHOT, LANGUAGE = N'English')   
	UPDATE dbo.Product SET ProductName = @ProductName, Price = @Price   
	WHERE ProductId = @ProductId
	IF @@ROWCOUNT = 0
		INSERT INTO dbo.Product(ProductId,ProductName,Price) VALUES (@ProductId, @ProductName, @Price);
END
GO

--Now you can for instance add two rows and update one of it by using the above procedure:
EXEC dbo.SaveProduct 1, N'Home Jersey Benfica', 89.95;
EXEC dbo.SaveProduct 2, N'Away Jersey Juventus', 89.95;
EXEC dbo.SaveProduct 1, N'Home Jersey Benfica', 79.95;
GO
/*Result:
ProductId   ProductName                                        Price
----------- -------------------------------------------------- ---------------------
2           Away Jersey Juventus                               89,95
1           Home Jersey Benfica                                79,95

ProductId   ProductName            Price         ValidFrom                   ValidTo
----------- ---------------------- ------------ --------------------------- ---------------------------
1           Home Jersey Benfica    89,95        2017-12-17 20:25:50.9933289 2017-12-17 20:25:51.0018353
*/

--Cleanup
DROP PROCEDURE IF EXISTS dbo.SaveProduct;
GO
ALTER TABLE dbo.Product SET (SYSTEM_VERSIONING = OFF);   
ALTER TABLE dbo.Product DROP PERIOD FOR SYSTEM_TIME;   
DROP TABLE IF EXISTS dbo.Product;
DROP TABLE IF EXISTS dbo.ProductHistory;
GO
