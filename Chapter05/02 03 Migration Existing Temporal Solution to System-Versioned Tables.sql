-----------------------------------------------------------------------------------
--------	SQL Server 2017 Developer’s Guide
--------	Chapter 07 -  Temporal Tables
---------- Migration Existing Temporal Solution to System-Versioned Tables
-----------------------------------------------------------------------------------

--Assuming that the AdventureWorks2017 database is on the same server as WideWorldImporters
--You can download it at https://github.com/Microsoft/sql-server-samples/releases/tag/adventureworks
USE WideWorldImporters;
CREATE TABLE dbo.ProductListPrice
(
	ProductID INT NOT NULL CONSTRAINT PK_ProductListPrice PRIMARY KEY,
	ListPrice MONEY NOT NULL,
);
INSERT INTO dbo.ProductListPrice(ProductID,ListPrice)
SELECT ProductID,ListPrice FROM AdventureWorks2017.Production.Product;
GO
CREATE TABLE dbo.ProductListPriceHistory
(
	ProductID INT NOT NULL,
	ListPrice MONEY NOT NULL,
	StartDate DATETIME NOT NULL,
	EndDate DATETIME   NULL,
	CONSTRAINT PK_ProductListPriceHistory PRIMARY KEY CLUSTERED 
	(
		ProductID ASC,
		StartDate ASC
	)
);
INSERT INTO dbo.ProductListPriceHistory(ProductID,ListPrice,StartDate,EndDate)
SELECT ProductID, ListPrice, StartDate, EndDate FROM AdventureWorks2017.Production.ProductListPriceHistory; 

--Consider the rows for the product with ID 707 in both tables:
SELECT * FROM dbo.ProductListPrice WHERE ProductID = 707;
SELECT * FROM dbo.ProductListPriceHistory WHERE ProductID = 707;
/*Result:
ProductID   ListPrice
----------- ---------------------
707         34,99

ProductID   ListPrice             StartDate               EndDate
----------- --------------------- ----------------------- -----------------------
707         33.6442               2011-05-31 00:00:00.000 2012-05-29 00:00:00.000
707         33.6442               2012-05-30 00:00:00.000 2013-05-29 00:00:00.000
707         34.99                 2013-05-30 00:00:00.000 NULL
*/

-- create the temporal infrastructure in the current table:
ALTER TABLE dbo.ProductListPrice
ADD StartDate DATETIME2 GENERATED ALWAYS AS ROW START HIDDEN NOT NULL CONSTRAINT DF_StartDate1 DEFAULT SYSUTCDATETIME(),
   EndDate DATETIME2 GENERATED ALWAYS AS ROW END HIDDEN NOT NULL CONSTRAINT DF_EndDate1 DEFAULT '99991231 23:59:59.9999999',
   PERIOD FOR SYSTEM_TIME (StartDate, EndDate);
GO
--remove gaps
UPDATE dbo.ProductListPriceHistory SET EndDate = DATEADD(day,1,EndDate);
--update EndDate to StartDate of the actual record
UPDATE dbo.ProductListPriceHistory SET EndDate = (SELECT MAX(StartDate) FROM dbo.ProductListPrice) WHERE EndDate IS NULL;
--remove constraints
ALTER TABLE dbo.ProductListPriceHistory DROP CONSTRAINT PK_ProductListPriceHistory;
--change data type to DATETIME2
ALTER TABLE dbo.ProductListPriceHistory ALTER COLUMN StartDate DATETIME2 NOT NULL;
ALTER TABLE dbo.ProductListPriceHistory ALTER COLUMN EndDate DATETIME2 NOT NULL;

--Now both tables are ready for participating in the relation to act as a system-versioned temporal table in SQL Server 2017:
ALTER TABLE dbo.ProductListPrice SET (SYSTEM_VERSIONING = ON (HISTORY_TABLE = dbo.ProductListPriceHistory,  DATA_CONSISTENCY_CHECK = ON));

--update the price for the product with the ID 707 to 50 
UPDATE dbo.ProductListPrice SET ListPrice = 50 WHERE ProductID = 707;
--and then check the rows in both tables:
SELECT * FROM dbo.ProductListPrice WHERE ProductID = 707;
SELECT * FROM dbo.ProductListPriceHistory WHERE ProductID = 707;
/*Result:

ProductID   ListPrice
----------- ---------------
707         50,00

ProductID   ListPrice      StartDate               	 EndDate
----------- -------------- ----------------------- 	 -----------------------
707         33,6442       2011-05-31 00:00:00.000 	 2012-05-29 00:00:00.000
707         33,6442       2012-05-30 00:00:00.000 	 2013-05-29 00:00:00.000
707         34,99         2013-05-30 00:00:00.000 	 2016-08-19 18:14:55.9287816
707         34,99         2016-08-19 18:14:55.9287816 2016-08-19 18:15:12.6947253

*/
