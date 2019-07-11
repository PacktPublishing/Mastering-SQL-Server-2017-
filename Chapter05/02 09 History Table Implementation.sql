--------------------------------------------------------------------
--------	SQL Server 2017 Developer’s Guide
--------	Chapter 07 -  Temporal Tables
----------	History Table Implementation
--------------------------------------------------------------------

--create a sample table
CREATE TABLE dbo.Mila
(
   Id INT NOT NULL IDENTITY (1,1) PRIMARY KEY CLUSTERED,
   C1 INT NOT NULL,
   C2 NVARCHAR(4000) NULL
)
GO
INSERT INTO dbo.Mila(C1, C2)  SELECT message_id, text FROM sys.messages WHERE language_id = 1033;
GO 50

ALTER TABLE dbo.Mila
ADD ValidFrom DATETIME2 GENERATED ALWAYS AS ROW START NOT NULL CONSTRAINT DF_Mila_ValidFrom DEFAULT '20170101',
   ValidTo DATETIME2 GENERATED ALWAYS AS ROW END NOT NULL CONSTRAINT DF_Mila_ValidTo DEFAULT '99991231 23:59:59.9999999',
   PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo);
GO
ALTER TABLE dbo.Mila SET (SYSTEM_VERSIONING = ON (HISTORY_TABLE = dbo.Mila_History)); 
GO

--update all rows
UPDATE dbo.Mila SET C1 = C1 + 1;
--update a single row
UPDATE dbo.Mila SET C1 = 44 WHERE Id = 1;

--Now, assume that you want to check the state of the row with the ID of 1 in some time in tha past. 
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
SELECT * FROM dbo.Mila FOR SYSTEM_TIME AS OF '20170505 08:00:00' WHERE Id = 1;
GO
/*
Id   C1   C2                                   ValidFrom                   ValidTo
---- ---- ---------------------------------    --------------------------- ---------------------------
1    21   Warning: Fatal error %d occurred..   2017-01-01 00:00:00.0000000 2017-12-13 16:57:49.6072092
*/
/*
SQL Server Execution Times:
   CPU time = 0 ms,  elapsed time = 0 ms.
SQL Server parse and compile time: 
   CPU time = 0 ms, elapsed time = 0 ms.

Table 'Mila_History'. Scan count 1, logical reads 10583, physical reads 0, read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob read-ahead reads 0.
Table 'Mila'. Scan count 0, logical reads 3, physical reads 0, read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob read-ahead reads 0.

 SQL Server Execution Times:
   CPU time = 188 ms,  elapsed time = 193 ms.
SQL Server parse and compile time: 
   CPU time = 0 ms, elapsed time = 0 ms.

 SQL Server Execution Times:
   CPU time = 0 ms,  elapsed time = 0 ms.
*/
--it is clear that you need an index with this column as the leading column:
CREATE CLUSTERED INDEX ix_Mila_History ON dbo.Mila_History(Id, ValidTo, ValidFrom) WITH DROP_EXISTING;
GO

--execute the query again
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
SELECT * FROM dbo.Mila FOR SYSTEM_TIME AS OF '20170505 08:00:00' WHERE Id = 1;
GO
/*
SQL Server Execution Times:
   CPU time = 0 ms,  elapsed time = 0 ms.
SQL Server parse and compile time: 
   CPU time = 0 ms, elapsed time = 0 ms.

Table 'Mila_History'. Scan count 1, logical reads 4, physical reads 0, read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob read-ahead reads 0.
Table 'Mila'. Scan count 0, logical reads 3, physical reads 0, read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob read-ahead reads 0.

 SQL Server Execution Times:
   CPU time = 0 ms,  elapsed time = 0 ms.
SQL Server parse and compile time: 
   CPU time = 0 ms, elapsed time = 0 ms.

 SQL Server Execution Times:
   CPU time = 0 ms,  elapsed time = 0 ms.
*/

--Cleanup
 
ALTER TABLE dbo.Mila SET (SYSTEM_VERSIONING = OFF);    
ALTER TABLE dbo.Mila DROP PERIOD FOR SYSTEM_TIME;    
DROP TABLE IF EXISTS dbo.Mila; 
DROP TABLE IF EXISTS dbo.Mila_History; 
GO 
