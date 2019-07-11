--------------------------------------------------------------------
--------	SQL Server 2017 Developer’s Guide
--------	Chapter 07 -  Temporal Tables
----------	  Creating Temporal Tables
--------------------------------------------------------------------

USE WideWorldImporters; 
CREATE TABLE dbo.Product 
( 
   ProductId INT NOT NULL CONSTRAINT PK_Product PRIMARY KEY, 
   ProductName NVARCHAR(50) NOT NULL, 
   Price MONEY NOT NULL, 
   ValidFrom DATETIME2 GENERATED ALWAYS AS ROW START NOT NULL, 
   ValidTo DATETIME2 GENERATED ALWAYS AS ROW END NOT NULL, 
   PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo) 
) 
WITH (SYSTEM_VERSIONING = ON); 
GO

--user defined name for the  history table
USE WideWorldImporters; 
CREATE TABLE dbo.Product2 
( 
   ProductId INT NOT NULL CONSTRAINT PK_Product2 PRIMARY KEY, 
   ProductName NVARCHAR(50) NOT NULL, 
   Price MONEY NOT NULL, 
   ValidFrom DATETIME2 GENERATED ALWAYS AS ROW START NOT NULL, 
   ValidTo DATETIME2 GENERATED ALWAYS AS ROW END NOT NULL, 
   PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo) 
) 
WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = dbo.ProductHistory2)); 
GO

SELECT temporal_type_desc, p.data_compression_desc  
FROM sys.tables t 
INNER JOIN sys.partitions p ON t.object_id = p.object_id 
WHERE name = 'ProductHistory2'; 
/*
temporal_type_desc    data_compression_desc
--------------------- ---------------------
HISTORY_TABLE         PAGE
*/

-- extracts the index name and the columns used in the index:
SELECT i.name, i.type_desc, c.name, ic.index_column_id
FROM sys.indexes i
INNER JOIN sys.index_columns ic on ic.object_id = i.object_id
INNER JOIN sys.columns c on c.object_id = i.object_id AND ic.column_id = c.column_id
WHERE OBJECT_NAME(i.object_id) = 'ProductHistory2';
/*Result:
name                  type_desc     name       		index_column_id 
--------------------- ------------- ----------- 	------------
ix_ProductHistory2    CLUSTERED     ValidFrom		1
ix_ProductHistory2    CLUSTERED     ValidTo			2
*/
 

--remove the existing Product temporal table 
ALTER TABLE dbo.Product SET (SYSTEM_VERSIONING = OFF);   
ALTER TABLE dbo.Product DROP PERIOD FOR SYSTEM_TIME;   
DROP TABLE IF EXISTS dbo.Product;
DROP TABLE IF EXISTS dbo.ProductHistory;
GO

--creates first a history table, then a temporal table and finally assigns the history table to it. 
CREATE TABLE dbo.ProductHistory
(
   ProductId INT NOT NULL,
   ProductName NVARCHAR(50) NOT NULL,
   Price MONEY NOT NULL,
   ValidFrom DATETIME2 NOT NULL,
   ValidTo DATETIME2 NOT NULL
);
CREATE CLUSTERED COLUMNSTORE INDEX IX_ProductHistory ON dbo.ProductHistory;
CREATE NONCLUSTERED INDEX IX_ProductHistory_NC ON dbo.ProductHistory(ProductId, ValidFrom, ValidTo);
GO
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

----------------------------------------------
--Period columns as hidden attributes
----------------------------------------------
CREATE TABLE dbo.T1( 
   Id INT NOT NULL CONSTRAINT PK_T1 PRIMARY KEY, 
   Col1 INT NOT NULL, 
   ValidFrom DATETIME2 GENERATED ALWAYS AS ROW START NOT NULL, 
   ValidTo DATETIME2 GENERATED ALWAYS AS ROW END NOT NULL, 
   PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo) 
) 
WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = dbo.T1_Hist)); 
GO
INSERT INTO dbo.T1(Id, Col1) VALUES(1, 1);
GO
CREATE TABLE dbo.T2( 
   Id INT NOT NULL CONSTRAINT PK_T2 PRIMARY KEY, 
   Col1 INT NOT NULL, 
   ValidFrom DATETIME2 GENERATED ALWAYS AS ROW START HIDDEN NOT NULL, 
   ValidTo DATETIME2 GENERATED ALWAYS AS ROW END HIDDEN NOT NULL, 
   PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo) 
) 
WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = dbo.T2_Hist)); 
GO
INSERT INTO dbo.T2(Id, Col1) VALUES(1, 1);
GO

SELECT * FROM dbo.T1; 
/*
Id          Col1        ValidFrom                   ValidTo
----------- ----------- --------------------------- ---------------------------
1           1           2017-12-14 23:05:44.2068702 9999-12-31 23:59:59.9999999
*/


SELECT * FROM dbo.T2;
/*
Id          Col1
----------- -----------
1           1
*/

