--------------------------------------------------------------------
--------	SQL Server 2017 Developer’s Guide
--------	Chapter 07 -  Temporal Tables
---------- Querying Temporal Data in SQL Server 2017
--------------------------------------------------------------------

USE WideWorldImporters;
SELECT PersonID, FullName, OtherLanguages, ValidFrom, ValidTo 
FROM Application.People WHERE ValidFrom <= '2016-03-20 08:00:00' AND ValidTo > '2016-03-20 08:00:00' 
UNION ALL
SELECT PersonID, FullName, OtherLanguages, ValidFrom, ValidTo 
FROM Application.People_Archive WHERE ValidFrom <= '2016-03-20 08:00:00' AND ValidTo > '2016-03-20 08:00:00';
--1.109 rows are returned

--The query is logically equivalent to this one:
SELECT PersonID, FullName, OtherLanguages, ValidFrom, ValidTo 
FROM Application.People FOR SYSTEM_TIME AS OF '2016-03-20 08:00:00';

--prove that both resultset are identical
SELECT PersonID, FullName, OtherLanguages, ValidFrom, ValidTo 
FROM Application.People WHERE ValidFrom <= '2016-03-20 08:00:00' AND ValidTo > '2016-03-20 08:00:00' 
UNION ALL
SELECT PersonID, FullName, OtherLanguages, ValidFrom, ValidTo 
FROM Application.People_Archive WHERE ValidFrom <= '2016-03-20 08:00:00' AND ValidTo > '2016-03-20 08:00:00' 
EXCEPT
SELECT PersonID, FullName, OtherLanguages, ValidFrom, ValidTo 
FROM Application.People FOR SYSTEM_TIME AS OF '2016-03-20 08:00:00';
/*Result:
no rows
*/  

SELECT PersonID, FullName, OtherLanguages, ValidFrom, ValidTo 
FROM Application.People FOR SYSTEM_TIME AS OF '2016-03-20 08:00:00'
EXCEPT
(
SELECT PersonID, FullName, OtherLanguages, ValidFrom, ValidTo 
FROM Application.People WHERE ValidFrom <= '2016-03-20 08:00:00' AND ValidTo > '2016-03-20 08:00:00' 
UNION ALL
SELECT PersonID, FullName, OtherLanguages, ValidFrom, ValidTo 
FROM Application.People_Archive WHERE ValidFrom <= '2016-03-20 08:00:00' AND ValidTo > '2016-03-20 08:00:00'
);
/*Result:
no rows
*/

--A special case of a point-in-time query against a temporal table is a query where you specify the actual date as the point in time. 
--The following query returns actual data from the same temporal table:
DECLARE @Now AS DATETIME = CURRENT_TIMESTAMP;
SELECT PersonID, FullName, OtherLanguages, ValidFrom, ValidTo 
FROM Application.People FOR SYSTEM_TIME AS OF @Now;
--The query is logically equivalent to this one:
SELECT PersonID, FullName, OtherLanguages, ValidFrom, ValidTo 
FROM Application.People;
/*Result:
when you look at the execution plans for the execution of the first query both tables have been processed, 
while the non-temporal query had to retrieve data from the current table only
*/


--example using FROM/TO
SELECT PersonID, FullName, OtherLanguages, ValidFrom, ValidTo 
FROM Application.People FOR SYSTEM_TIME FROM '2016-03-20 08:00:00' TO '2016-05-31 23:14:00' WHERE PersonID = 7;
/*Result:
PersonID    FullName                                           OtherLanguages                                                                                                                                                                                                                                                   ValidFrom                   ValidTo
----------- -------------------------------------------------- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- --------------------------- ---------------------------
7           Amy Trefl                                          NULL                                                                                                                                                                                                                                                             2016-03-20 08:00:00.0000000 2016-05-31 23:13:00.0000000
7           Amy Trefl                                          ["Slovak","Spanish","Polish"]                                                                                                                                                                                                                                    2016-05-31 23:13:00.0000000 2016-05-31 23:14:00.0000000
*/

--example using BETWEEN
SELECT PersonID, FullName, OtherLanguages, ValidFrom, ValidTo 
FROM Application.People FOR SYSTEM_TIME BETWEEN '2016-03-20 08:00:01' AND '2016-05-31 23:14:00' WHERE PersonID = 7;
/*Result:
PersonID    FullName                                           OtherLanguages                                                                                                                                                                                                                                                   ValidFrom                   ValidTo
----------- -------------------------------------------------- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- --------------------------- ---------------------------
7           Amy Trefl                                          ["Slovak","Spanish","Polish"]                                                                                                                                                                                                                                    2016-05-31 23:14:00.0000000 9999-12-31 23:59:59.9999999
7           Amy Trefl                                          NULL                                                                                                                                                                                                                                                             2016-03-20 08:00:00.0000000 2016-05-31 23:13:00.0000000
7           Amy Trefl                                          ["Slovak","Spanish","Polish"]                                                                                                                                                                                                                                    2016-05-31 23:13:00.0000000 2016-05-31 23:14:00.0000000
*/

--example using CONTAINED IN
SELECT PersonID, FullName, OtherLanguages, ValidFrom, ValidTo 
FROM Application.People FOR SYSTEM_TIME CONTAINED IN ('2016-03-20 08:00:01','2016-05-31 23:14:00') WHERE PersonID = 7;
/*Result:
PersonID    FullName                                           OtherLanguages                                                                                                                                                                                                                                                   ValidFrom                   ValidTo
----------- -------------------------------------------------- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- --------------------------- ---------------------------
7           Amy Trefl                                          ["Slovak","Spanish","Polish"]                                                                                                                                                                                                                                    2016-05-31 23:13:00.0000000 2016-05-31 23:14:00.0000000
*/

--example using ALL
SELECT PersonID, FullName, OtherLanguages, ValidFrom, ValidTo 
FROM Application.People FOR SYSTEM_TIME ALL
WHERE PersonID = 7;
/*Result:
PersonID    FullName                                           OtherLanguages                                                                                                                                                                                                                                                   ValidFrom                   ValidTo
----------- -------------------------------------------------- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- --------------------------- ---------------------------
7           Amy Trefl                                          ["Slovak","Spanish","Polish"]                                                                                                                                                                                                                                    2016-05-31 23:14:00.0000000 9999-12-31 23:59:59.9999999
7           Amy Trefl                                          NULL                                                                                                                                                                                                                                                             2013-01-01 00:00:00.0000000 2013-01-05 08:00:00.0000000
7           Amy Trefl                                          NULL                                                                                                                                                                                                                                                             2013-01-05 08:00:00.0000000 2013-01-22 08:00:00.0000000
7           Amy Trefl                                          NULL                                                                                                                                                                                                                                                             2013-01-22 08:00:00.0000000 2013-02-26 08:00:00.0000000
7           Amy Trefl                                          NULL                                                                                                                                                                                                                                                             2013-02-26 08:00:00.0000000 2013-03-07 08:00:00.0000000
7           Amy Trefl                                          NULL                                                                                                                                                                                                                                                             2013-03-07 08:00:00.0000000 2013-04-24 08:00:00.0000000
7           Amy Trefl                                          NULL                                                                                                                                                                                                                                                             2013-04-24 08:00:00.0000000 2013-07-05 08:00:00.0000000
7           Amy Trefl                                          NULL                                                                                                                                                                                                                                                             2013-07-05 08:00:00.0000000 2013-08-31 08:00:00.0000000
7           Amy Trefl                                          NULL                                                                                                                                                                                                                                                             2013-08-31 08:00:00.0000000 2014-02-03 08:00:00.0000000
7           Amy Trefl                                          NULL                                                                                                                                                                                                                                                             2014-02-03 08:00:00.0000000 2014-04-23 08:00:00.0000000
7           Amy Trefl                                          NULL                                                                                                                                                                                                                                                             2014-04-23 08:00:00.0000000 2015-06-15 08:00:00.0000000
7           Amy Trefl                                          NULL                                                                                                                                                                                                                                                             2015-06-15 08:00:00.0000000 2016-03-20 08:00:00.0000000
7           Amy Trefl                                          NULL                                                                                                                                                                                                                                                             2016-03-20 08:00:00.0000000 2016-05-31 23:13:00.0000000
7           Amy Trefl                                          ["Slovak","Spanish","Polish"]                                                                                                                                                                                                                                    2016-05-31 23:13:00.0000000 2016-05-31 23:14:00.0000000
*/

--The query returns 14 rows, since there are 13 historical rows and one entry in the actual table. 
--Here is the logically equivalent, standard but a bit more complex query:
SELECT PersonID, FullName, OtherLanguages, ValidFrom, ValidTo 
FROM Application.People 
WHERE PersonID = 7
UNION ALL
SELECT PersonID, FullName, OtherLanguages, ValidFrom, ValidTo 
FROM Application.People_Archive
WHERE PersonID = 7;
