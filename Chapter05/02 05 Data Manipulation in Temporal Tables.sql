--------------------------------------------------------------------
--------	SQL Server 2017 Developer’s Guide
--------	Chapter 07 -  Temporal Tables
---------- Data Manipulation in Temporal Tables
--------------------------------------------------------------------


--remove already created tables and create a temporal table again
USE WideWorldImporters;
ALTER TABLE dbo.Product SET (SYSTEM_VERSIONING = OFF);   
ALTER TABLE dbo.Product DROP PERIOD FOR SYSTEM_TIME;   
DROP TABLE IF EXISTS dbo.Product;
DROP TABLE IF EXISTS dbo.ProductHistory;
GO
CREATE TABLE dbo.Product
(
   ProductId INT NOT NULL CONSTRAINT PK_Product PRIMARY KEY,
   ProductName NVARCHAR(50) NOT NULL,
   Price MONEY NOT NULL,
   ValidFrom DATETIME2 GENERATED ALWAYS AS ROW START HIDDEN NOT NULL,
   ValidTo DATETIME2 GENERATED ALWAYS AS ROW END HIDDEN NOT NULL,
   PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo)
)
WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = dbo.ProductHistory));
GO

--insert a new row and check the tables
INSERT INTO dbo.Product(ProductId, ProductName, Price) VALUES(1, N'Fog', 150.00);
SELECT * FROM dbo.Product;
SELECT * FROM dbo.ProductHistory;

/*Result:
ProductId   ProductName                                        Price
----------- -------------------------------------------------- ---------------------
1           Fog                                                150,00

ProductId   ProductName                                        Price                 ValidFrom                   ValidTo
----------- -------------------------------------------------- --------------------- --------------------------- ---------------------------
*/

--update the price to 200
UPDATE dbo.Product SET Price = 200.00 WHERE ProductId = 1; 

SELECT * FROM dbo.Product;
SELECT * FROM dbo.ProductHistory;
/*Result:
ProductId   ProductName                                        Price
----------- -------------------------------------------------- ---------------------
1           Fog                                                200,00
ProductId   ProductName                                        Price                 ValidFrom                   ValidTo
----------- -------------------------------------------------- --------------------- --------------------------- ---------------------------
1           Fog                                                150,00                2017-11-12 11:28:06.8072636 2017-11-28 11:29:05.6520461
*/

--update the price to 180
UPDATE dbo.Product SET Price = 180.00 WHERE ProductId = 1; 
SELECT * FROM dbo.Product;
SELECT * FROM dbo.ProductHistory;
/*Result:
ProductId   ProductName                                        Price
----------- -------------------------------------------------- ---------------------
1           Fog                                                180,00
ProductId   ProductName                                        Price                 ValidFrom                   ValidTo
----------- -------------------------------------------------- --------------------- --------------------------- ---------------------------
1           Fog                                                150,00                2017-11-12 11:28:06.8072636 2017-11-28 11:29:05.6520461
1           Fog                                                200,00                2017-11-28 11:29:05.6520461 2017-11-29 11:29:42.8538668
*/
--update the price to 180
UPDATE dbo.Product SET Price = 180.00 WHERE ProductId = 1; 
SELECT * FROM dbo.Product;
SELECT * FROM dbo.ProductHistory;
/*Result:
ProductId   ProductName                                        Price
----------- -------------------------------------------------- ---------------------
1           Fog                                                180,00

ProductId   ProductName                                        Price                 ValidFrom                   ValidTo
----------- -------------------------------------------------- --------------------- --------------------------- ---------------------------
1           Fog                                                150,00                2017-11-12 11:28:06.8072636 2017-11-28 11:29:05.6520461
1           Fog                                                200,00                2017-11-28 11:29:05.6520461 2017-11-29 11:29:42.8538668
1           Fog                                                180,00                2017-11-29 11:29:42.8538668 2017-11-30 11:30:11.9324821
*/
DELETE FROM dbo.Product WHERE ProductId = 1;
SELECT * FROM dbo.Product;
SELECT * FROM dbo.ProductHistory;
/*Result:
ProductId   ProductName                                        Price
----------- -------------------------------------------------- ---------------------

ProductId   ProductName                                        Price                 ValidFrom                   ValidTo
----------- -------------------------------------------------- --------------------- --------------------------- ---------------------------
1           Fog                                                150,00                2017-11-12 11:28:06.8072636 2017-11-28 11:29:05.6520461
1           Fog                                                200,00                2017-11-28 11:29:05.6520461 2017-11-29 11:29:42.8538668
1           Fog                                                180,00                2017-11-29 11:29:42.8538668 2017-11-30 11:30:11.9324821
1           Fog                                                180,00                2017-11-30 11:30:11.9324821 2017-12-15 11:30:42.9330248
*/

--ValidFrom and ValidTo are UTC dates!

--Cleanup
ALTER TABLE dbo.Product SET (SYSTEM_VERSIONING = OFF);    
ALTER TABLE dbo.Product DROP PERIOD FOR SYSTEM_TIME;    
DROP TABLE IF EXISTS dbo.Product; 
DROP TABLE IF EXISTS dbo.ProductHistory;
GO
