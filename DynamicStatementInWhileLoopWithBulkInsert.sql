IF OBJECT_ID('tempdb.dbo.#VIGO_CEC') IS NOT NULL
	DROP TABLE #VIGO_CEC

CREATE TABLE #VIGO_CEC
(
Variant_NetSuiteID INT NOT NULL,
[Flow Rate/GPM (at Max PSI)] DECIMAL(18,2),
[CEC Compliant] NVARCHAR(5)
)

BULK INSERT #VIGO_CEC
FROM '\\Server\Scripts\BulkInserts\VIGO_CEC_Compliant_SKUs.txt'
WITH
(
	FIELDTERMINATOR = '\t',
	ROWTERMINATOR = '\n'
);

SELECT * FROM #VIGO_CEC

IF OBJECT_ID ('Tempdb.dbo.#TablesWithHDF') IS NOT NULL 
    DROP TABLE #TablesWithHDF
IF OBJECT_ID ('Tempdb.dbo.#TablesWithHDFAndRow') IS NOT NULL 
    DROP TABLE #TablesWithHDFAndRow

DECLARE @Category NVARCHAR(25)
DECLARE @Count INT
DECLARE @SQLQuery NVARCHAR(MAX)
DECLARE @HDF NVARCHAR(50)

SET @Count = 1;
SET @HDF = 'Flow Rate/GPM (at Max PSI)'

SELECT TABLE_NAME AS Category, ROW_NUMBER()OVER(ORDER BY TABLE_NAME ASC) AS RowNUM INTO #TablesWithHDF
FROM  Product.INFORMATION_SCHEMA.COLUMNS S
WHERE S.TABLE_SCHEMA  = 'Category'
AND S.COLUMN_NAME = @HDF

SELECT DISTINCT ch.Category, hdf.HumanDecisionFactorName INTO #TablesWithHDF
FROM Product.Product.HumanDecisionFactors hdf
INNER JOIN Product.Merch.CategoryHumanDecisionFactors chdf ON hdf.HumanDecisionFactorID = chdf.HumanDecisionFactorID
INNER JOIN Product.Merch.CategoryHierarchy ch ON chdf.CategoryHierarchyId=ch.CategoryHierarchyId
INNER JOIN Product.Merch.GlobalProduct gp ON ch.Category=gp.Category
WHERE Manufacturer = 'Vigo'
AND HumanDecisionFactorName = @HDF

SELECT *, ROW_NUMBER() OVER(ORDER BY Category) as RowNUM INTO #TablesWithHDFAndRow 
FROM #TablesWithHDF

WHILE (SELECT COUNT(Category) FROM #TablesWithHDFAndRow) >= @Count
BEGIN

SET @Category = (SELECT Category FROM #TablesWithHDFAndRow WHERE @Count = RowNUM)

SET @SQLquery = N'WITH newCEC AS
				 (
				 SELECT c.globalproductid, c.[' + @HDF + '] AS OLD, vigo.[' + @HDF + '] AS NEW, gp.category, gp.manufacturer
				 FROM Product.Category.[' + @Category + '] c
				 INNER JOIN Product.Merch.GlobalProduct gp ON c.globalproductid = gp.globalproductid
				 INNER JOIN Product.Merch.GlobalVariant gv ON gp.globalproductid = gv.globalproductid
				 INNER JOIN #VIGO_CEC vigo ON gv.Variant_NetSuiteID = vigo.Variant_NetSuiteID
				 )
					
				 UPDATE newCEC
				 SET OLD = NEW'



EXEC sp_sqlexec @SQLQuery;
PRINT @SQLQuery
SET @Count = @Count + 1
END;