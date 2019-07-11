--------------------------------------------------------------------
--------	SQL Server 2017 Developer’s Guide
--------	Chapter 07 -  Temporal Tables
---------- History Retention Policy in SQL Server 2017
--------------------------------------------------------------------
USE WideWorldImporters;
GO
--enable the temporal historical retention feature for this database:
ALTER DATABASE WideWorldImporters SET TEMPORAL_HISTORY_RETENTION ON;
GO

--create a sample table

CREATE TABLE dbo.T1(  
    Id INT NOT NULL PRIMARY KEY CLUSTERED,
    C1 INT,
    Vf DATETIME2 NOT NULL,
    Vt DATETIME2 NOT NULL 
) 
GO
CREATE TABLE dbo.T1_Hist(  
    Id INT NOT NULL,
    C1 INT,
    Vf DATETIME2 NOT NULL,
    Vt DATETIME2 NOT NULL 
) 
GO
--populate tables
INSERT INTO dbo.T1_Hist(Id, C1, Vf, Vt) VALUES
(1,1,'20171201','20171210'),
(1,2,'20171210','20171215');
GO
INSERT INTO dbo.T1(Id, C1, Vf, Vt) VALUES
(1,3,'20171215','99991231 23:59:59.9999999');
GO

SELECT * FROM dbo.T1;
/*
Id          C1          Vf                          Vt
----------- ----------- --------------------------- ---------------------------
1           3           2017-12-15 00:00:00.0000000 9999-12-31 23:59:59.9999999

*/
SELECT * FROM dbo.T1_Hist;
/*
Id          C1          Vf                          Vt
----------- ----------- --------------------------- ---------------------------
1           1           2017-12-01 00:00:00.0000000 2017-12-10 00:00:00.0000000
1           2           2017-12-10 00:00:00.0000000 2017-12-15 00:00:00.0000000
*/


--convert the T1 table into a temporal table and so define a retention policy that historical entries should be retained for one day only
ALTER TABLE dbo.T1 ADD PERIOD FOR SYSTEM_TIME (Vf, Vt);
GO
ALTER TABLE dbo.T1 SET
 (
     SYSTEM_VERSIONING = ON
     (
        HISTORY_TABLE = dbo.T1_Hist,
        HISTORY_RETENTION_PERIOD = 3 DAYS
     )
 );
GO
/*
Msg 13765, Level 16, State 1, Line 31
Setting finite retention period failed on system-versioned temporal table 'WideWorldImporters.dbo.T1' 
because the history table 'WideWorldImporters.dbo.T1_Hist' does not contain required clustered index. Consider creating a clustered columnstore or B-tree index starting with the column that matches end of SYSTEM_TIME period, on the history table.
*/

--The history table must have a row clustered index on the column representing the end of period; it won't work without it. 
--Use this code to create the index and run the previous code again:
CREATE CLUSTERED INDEX IX_CL_T1_Hist ON dbo.T1_Hist(Vt, Vf);
GO
ALTER TABLE dbo.T1 SET
 (
     SYSTEM_VERSIONING = ON
     (
        HISTORY_TABLE = dbo.T1_Hist,
        HISTORY_RETENTION_PERIOD = 3 DAYS
     )
 );
 
 /*
Commands completed successfully.
*/
 SELECT * FROM dbo.T1 FOR SYSTEM_TIME ALL;
 /*
 Id          C1          Vf                          Vt
----------- ----------- --------------------------- ---------------------------
1           3           2017-12-15 00:00:00.0000000 9999-12-31 23:59:59.9999999
1           2           2017-12-10 00:00:00.0000000 2017-12-15 00:00:00.0000000
*/
--Rows that meet the following criteria are not shown: Vt < DATEADD (Day, -3, SYSUTCDATETIME ());

SELECT * FROM dbo.T1 
UNION ALL
SELECT * FROM dbo.T1_Hist;
/*
Id          C1          Vf                          Vt
----------- ----------- --------------------------- ---------------------------
1           3           2017-12-15 00:00:00.0000000 9999-12-31 23:59:59.9999999
1           1           2017-12-01 00:00:00.0000000 2017-12-10 00:00:00.0000000
1           2           2017-12-10 00:00:00.0000000 2017-12-15 00:00:00.000000
*/
--when you query the history table directly, you can still see all rows

--check retention policy settings
SELECT temporal_type_desc, history_retention_period, history_retention_period_unit 
FROM sys.tables WHERE name = 'T1';
GO
/*
temporal_type_desc               history_retention_period    history_retention_period_unit
-------------------------------  -------------------------   -------------------------------
SYSTEM_VERSIONED_TEMPORAL_TABLE  3                           3
*/

--cleanup
ALTER TABLE dbo.T1 SET (SYSTEM_VERSIONING = OFF);   
ALTER TABLE dbo.T1 DROP PERIOD FOR SYSTEM_TIME;   
DROP TABLE IF EXISTS dbo.T1;
DROP TABLE IF EXISTS dbo.T1_Hist;
GO
