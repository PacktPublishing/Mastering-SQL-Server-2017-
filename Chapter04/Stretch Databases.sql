
--------------------------------------------------------------------
--------    SQL Server 2017 Developer’s Guide
--------    Chapter 06 - Stretch Databases
--------------------------------------------------------------------
 
-------------------------------------------------------------
------Enable Stretch DB feature on the instance level
-------------------------------------------------------------

EXEC sys.sp_configure N'remote data archive', '1';
RECONFIGURE;
GO

-------------------------------------------------------------
------Enabling Stretch Database at the Database Level
-------------------------------------------------------------

--The following code creates a database master key for the sample database Mila.
DROP DATABASE IF EXISTS Mila; --Ensure that you create a new, empty database
GO
CREATE DATABASE Mila;
GO 
CREATE MASTER KEY ENCRYPTION BY PASSWORD='<very secure password>'; 


--Now, you need to create a credential.
CREATE DATABASE SCOPED CREDENTIAL MilaStretchCredential  
WITH 
IDENTITY = 'Vasilije', 
SECRET = '<very secure password>';

--Now you can finally enable Stretch DB feature by using ALTER DATABASE statement.  
--You need to set REMOTE_DATA_ARCHIVE and to define two parameters: Azure server and just created database scoped credential. 
--Here is the code that can be used to enable Stretch DB feature for the database Mila.
ALTER DATABASE Mila  
    SET REMOTE_DATA_ARCHIVE = ON  
        (  
            SERVER = 'MyStretchDatabaseServer.database.windows.net',  
            CREDENTIAL = [MilaStretchCredential] 
        );  



----------------------------------------------------
-- Enabling Stretch Database for a Table
----------------------------------------------------
USE Mila; 
CREATE TABLE dbo.T1( 
id INT NOT NULL,  
c1 VARCHAR(20) NOT NULL, 
c2 DATETIME NOT NULL, 
CONSTRAINT PK_T1 PRIMARY KEY CLUSTERED (id) 
); 
GO
INSERT INTO dbo.T1 (id, c1, c2) VALUES 
    (1, 'Benfica Lisbon','20180115'), 
    (2, 'Manchester United','20180202'), 
    (3, 'Rapid Vienna','20180128'), 
    (4, 'Juventus Torino','20180225'), 
    (5, 'Red Star Belgrade','20180225'); 
GO

--The following code example shows how to enable the Stretch DB feature for the table T1 in the database Mila:
USE Mila;
GO
CREATE FUNCTION dbo.StretchFilter(@col DATETIME)  
RETURNS TABLE  
WITH SCHEMABINDING   
AS   
       RETURN SELECT 1 AS is_eligible 
WHERE @col < CONVERT(DATETIME, '01.02.2018', 104);
GO
ALTER TABLE dbo.T1 
    SET ( 
	REMOTE_DATA_ARCHIVE = ON (  
        FILTER_PREDICATE = dbo.StretchFilter(c2),  
        MIGRATION_STATE = OUTBOUND
	) 
) ;  

----------------------------------------------
-- Queries
----------------------------------------------


--the entire table
SELECT * FROM dbo.T1;
/*Result:
id          c1                   c2
----------- -------------------- -----------------------
2           Manchester United    2018-02-02 00:00:00.000
4           Juventus Torino      2018-02-25 00:00:00.000
5           Red Star Belgrade    2018-02-25 00:00:00.000
1           Benfica Lisbon       2018-01-15 00:00:00.000
3           Rapid Vienna         2018-01-28 00:00:00.000

Execution plan: Remote Query operator + Clustered Index Scan
*/

SELECT * FROM dbo.T1 WHERE c2 >= '20180201';
/*Result:
id          c1                   c2
----------- -------------------- -----------------------
2           Manchester United    2018-02-02 00:00:00.000
4           Juventus Torino      2018-02-25 00:00:00.000
5           Red Star Belgrade    2018-02-25 00:00:00.000

Execution plan: Clustered Index Scan
*/

SELECT * FROM dbo.T1 WHERE c2 < '20180201';
/*Result:
id          c1                   c2
----------- -------------------- -----------------------
1           Benfica Lisbon       2018-01-15 00:00:00.000
3           Rapid Vienna         2018-01-28 00:00:00.000

Execution plan: Remote Query operator + Clustered Index Scan
*/

------------------------------------------------------
--Querying with REMOTE_DATA_ARCHIVE_OVERRIDE 
------------------------------------------------------
SELECT * FROM dbo.T1 WITH (REMOTE_DATA_ARCHIVE_OVERRIDE = STAGE_ONLY); --eligible data
/*Result:
id          c1                   c2                      batchID--917578307
----------- -------------------- ----------------------- --------------------
1           Benfica Lisbon       2018-01-15 00:00:00.000 1
3           Rapid Vienna         2018-01-28 00:00:00.000 1
*/

SELECT * FROM dbo.T1 WITH (REMOTE_DATA_ARCHIVE_OVERRIDE = REMOTE_ONLY); --remote data only
/*Result:
id          c1                   c2                      batchID--917578307
----------- -------------------- ----------------------- --------------------
1           Benfica Lisbon       2018-01-15 00:00:00.000 1
3           Rapid Vienna         2018-01-28 00:00:00.000 1
*/
 
SELECT * FROM dbo.T1 WITH (REMOTE_DATA_ARCHIVE_OVERRIDE = LOCAL_ONLY); --local data only
/*Result:
id          c1                   c2
----------- -------------------- -----------------------
2           Manchester United    2018-02-02 00:00:00.000
4           Juventus Torino      2018-02-25 00:00:00.000
5           Red Star Belgrade    2018-02-25 00:00:00.000
*/
-------------------------------------
--filter predicate functions
-------------------------------------
GO
--The following code creates a filter function that can be used to migrate 
--all rows where the column col has value older than 1st June 2016
CREATE FUNCTION dbo.StretchFilter(@col DATETIME)  
RETURNS TABLE  
WITH SCHEMABINDING   
AS   
       RETURN SELECT 1 AS is_eligible 
WHERE @col < CONVERT(DATETIME, '01.02.2018', 104);
GO


--The following code creates a filter function that can be used to migrate 
--all rows where the column status has values 2 or 3. (cancelled and done)

CREATE FUNCTION dbo.StretchFilter(@col TINYINT)  
RETURNS TABLE  
WITH SCHEMABINDING   
AS   
	RETURN SELECT 1 AS is_eligible WHERE @col IN (2, 3);
GO

--Sliding window implementation for filter function
--create a filter function to remove all rows older than 1st March 2018. 
CREATE FUNCTION dbo.StretchFilter20180301(@col DATETIME)  
RETURNS TABLE  
WITH SCHEMABINDING   
AS   
	RETURN SELECT 1 AS is_eligible WHERE @col < CONVERT(DATETIME, '01.03.2018', 104);
GO

--And assign it to the table T1:
ALTER TABLE dbo.T1   
SET (REMOTE_DATA_ARCHIVE = ON   
    (FILTER_PREDICATE = dbo.StretchFilter20180301 (c2),
     MIGRATION_STATE = OUTBOUND   
     )  
);  
GO

--Since you used SCHEMABINDING option, you cannot alter the function. Therefore, you need to create a new function. 
--The following code creates a new function dbo.StretchFilter20180401:
CREATE FUNCTION dbo.StretchFilter20180401(@col DATETIME)  
RETURNS TABLE  
WITH SCHEMABINDING   
AS   
	RETURN SELECT 1 AS is_eligible WHERE @col < CONVERT(DATETIME, '01.04.2018', 104);

--Now, you need to replace the function:
ALTER TABLE dbo.T1   
SET (REMOTE_DATA_ARCHIVE = ON   
    (FILTER_PREDICATE = dbo.StretchFilter20180401 (c2),
     MIGRATION_STATE = OUTBOUND   
     )  
);  

--And finally, to remove the previous function:
DROP FUNCTION IF EXISTS dbo.StretchFilter20180301;

-----------------
--Monitoring
---------------------

--check  migration status
USE Mila;
SELECT * FROM sys.dm_db_rda_migration_status;
/*Result:
table_id    database_id migrated_rows        start_time_utc          end_time_utc            error_number error_severity error_state
----------- ----------- -------------------- ----------------------- ----------------------- ------------ -------------- -----------
917578307   8           0                    2018-02-28 20:08:48.000 2018-02-28 20:09:21.110 NULL         NULL           NULL
917578307   8           0                    2018-02-28 20:09:28.010 2018-02-28 20:09:28.010 NULL         NULL           NULL
917578307   8           0                    2018-02-28 20:09:28.010 2018-02-28 20:10:08.407 1205         13			 55
917578307   8           0                    2018-02-28 20:10:09.407 2018-02-28 20:10:14.560 NULL         NULL           NULL
917578307   8           2                    2018-02-28 20:10:28.027 2018-02-28 20:10:51.563 NULL         NULL           NULL
917578307   9           0                    2018-02-28 20:10:51.563 2018-02-28 20:10:52.287 NULL         NULL           NULL
...
*/


--check archive databases
USE Mila;
SELECT * FROM sys.remote_data_archive_databases;
/*Result:
remote_database_id remote_database_name                           data_source_id federated_service_account
------------------ ---------------------------------------------- -------------- -------------------------
65536              RDAMilaA58713B7-0A91-4237-91C4-1173D113AD10    65536          0
*/
--check archive tables
USE Mila;
SELECT * FROM sys.remote_data_archive_tables;
/*Result:
object_id   remote_database_id remote_table_name                                                                                                                filter_predicate                                                                                                                                                                                                                                                 migration_direction migration_direction_desc                                     is_migration_paused is_reconciled
----------- ------------------ -------------------------------------------------------------------------------------------------------------------------------- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- ------------------- ------------------------------------------------------------ ------------------- -------------
917578307   65536              dbo_T1_917578307_74B91309-3BC0-4C8A-BE7A-4A1E53859322                                                                            ([dbo].[StretchFilter]([c2]))                                                                                                                                                                                                                                    0                   OUTBOUND                                                     0                   1
*/


--Check space used
USE Mila;
EXEC sp_spaceused 'dbo.T1', 'true', 'REMOTE_ONLY';
/*Result:
name               rows              reserved         data             index_size       unused
------------------ ----------------- ---------------- ---------------- ---------------- ----------------
T1                 2                 288 KB           16 KB            48 KB            224 KB
*/

--Disable Stretch Database for Tables by Using Transact-SQL
--You can use Transact-SQL to perform the same action. 
--The following code examples instructs SQL Server to disable Stretch DB feature for the stretch table T1, 
--but to transfer already migrated data for the table to the local database first:
USE Mila;
ALTER TABLE dbo.T1 SET (REMOTE_DATA_ARCHIVE (MIGRATION_STATE = INBOUND)); 
GO
--If you don’t need already migrated data (or you want to avoid data transfer costs) use the following code:
USE Mila;
ALTER TABLE dbo.T1 SET (REMOTE_DATA_ARCHIVE = OFF_WITHOUT_DATA_RECOVERY (MIGRATION_STATE = PAUSED)); 
GO
--Disable Stretch Database for a Database
ALTER DATABASE Mila SET (REMOTE_DATA_ARCHIVE = OFF_WITHOUT_DATA_RECOVERY (MIGRATION_STATE = PAUSED));  
GO

