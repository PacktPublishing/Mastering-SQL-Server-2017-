--------------------------------------------------------------------
--------	SQL Server 2017 Developer’s Guide
--------	Chapter 07 -  Temporal Tables
---------- Converting Non-Temporal to Temporal Tables
--------------------------------------------------------------------

--You can download the AdventureWorks2017 database at https://github.com/Microsoft/sql-server-samples/releases/tag/adventureworks
USE AdventureWorks2017; 
--the ModifiedDate column will be replaced by temporal table functionality
ALTER TABLE HumanResources.Department DROP CONSTRAINT DF_Department_ModifiedDate;
ALTER TABLE HumanResources.Department DROP COLUMN ModifiedDate;
GO
ALTER TABLE HumanResources.Department 
ADD ValidFrom DATETIME2 GENERATED ALWAYS AS ROW START HIDDEN NOT NULL CONSTRAINT DF_Validfrom DEFAULT '20080430 00:00:00.0000000', 
   ValidTo DATETIME2 GENERATED ALWAYS AS ROW END HIDDEN NOT NULL CONSTRAINT DF_ValidTo DEFAULT '99991231 23:59:59.9999999', 
   PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo); 
GO 
ALTER TABLE HumanResources.Department SET (SYSTEM_VERSIONING = ON (HISTORY_TABLE = HumanResources.DepartmentHistory));
GO

--update one row in the table
UPDATE HumanResources.Department SET Name='Political Correctness' WHERE DepartmentID = 2;

--check the current and history tables
SELECT * FROM HumanResources.Department WHERE DepartmentID = 2;
/*
DepartmentID Name                   GroupName
------------ ---------------------- ---------------------------
2            Political Correctness  Research and Development
*/
SELECT * FROM HumanResources.DepartmentHistory;
/*
DepartmentID Name          GroupName                   ValidFrom        ValidTo
------------ -----------   -------------------------   ---------------  ----------------
2            Tool Design   Research and Development    2008-04-30       2017-12-15 
*/

