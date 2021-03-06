USE [AdventureWorksDW2014] --Troque aqui caso queira utilizar seu banco de dados próprio
GO
DROP PROCEDURE IF EXISTS [dbo].[upCubeDocSearch]
GO
DROP PROCEDURE IF EXISTS [dbo].[upCubeDocMeasuresInMeasureGroup]
GO
DROP PROCEDURE IF EXISTS [dbo].[upCubeDocMeasureGroupsInCube]
GO
DROP PROCEDURE IF EXISTS [dbo].[upCubeDocMeasureGroupsForDimension]
GO
DROP PROCEDURE IF EXISTS [dbo].[upCubeDocListCatalog]
GO
DROP PROCEDURE IF EXISTS [dbo].[upCubeDocDimensionsInCube]
GO
DROP PROCEDURE IF EXISTS [dbo].[upCubeDocDimensionsForMeasureGroup]
GO
DROP PROCEDURE IF EXISTS [dbo].[upCubeDocCubes]
GO
DROP PROCEDURE IF EXISTS [dbo].[upCubeDocBUSMatrix]
GO
DROP PROCEDURE IF EXISTS [dbo].[upCubeDocAttributesInDimension]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[upCubeDocAttributesInDimension]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[upCubeDocAttributesInDimension] AS' 
END
GO

ALTER PROCEDURE [dbo].[upCubeDocAttributesInDimension]
(
	@DataSource				NVARCHAR(255),
	@Catalog				NVARCHAR(255),
	@Cube					NVARCHAR(255),
	@Dimension				NVARCHAR(255)
)
AS

	DECLARE
		@Query				NVARCHAR(MAX)
  
	SET @Query =
	'SELECT *,
		    CASE WHEN CAST([LEVEL_ORIGIN] AS INT) & 1 = 1 THEN
					  1
				 ELSE
					  0
				 END AS IsHierarchy,
		    CASE WHEN CAST([LEVEL_ORIGIN] AS INT) & 2 = 2 THEN
					  1
				 ELSE
					  0
				 END AS IsAttribute,
		    CASE WHEN CAST([LEVEL_ORIGIN] AS INT) & 4 = 4 THEN
					  1
				 ELSE
					  0
				 END AS IsKey
	   FROM OPENROWSET (''MSOLAP'',
					    ''DATASOURCE=' + @DataSource + ';Initial Catalog=' + @Catalog + ';'',
					    ''SELECT *
						    FROM $SYSTEM.MDSCHEMA_LEVELS
						   WHERE [LEVEL_NUMBER] > 0
						     AND [LEVEL_IS_VISIBLE]''
					   )
	  WHERE CAST([CUBE_NAME] AS VARCHAR(255)) = ''' + @Cube + '''
	    AND CAST([DIMENSION_UNIQUE_NAME] AS VARCHAR(255)) = ''' + @Dimension + ''''

	EXEC sp_executesql @Query

GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[upCubeDocBUSMatrix]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[upCubeDocBUSMatrix] AS' 
END
GO

ALTER PROCEDURE [dbo].[upCubeDocBUSMatrix]
(
	@DataSource				NVARCHAR(255),
	@Catalog				NVARCHAR(255),
	@Cube					NVARCHAR(255)
)
AS

	DECLARE
		@Query				NVARCHAR(MAX)
  
	SET @Query =
	'SELECT bus.[CATALOG_NAME],bus.[CUBE_NAME],
		    bus.[MEASUREGROUP_NAME],
		    bus.[MEASUREGROUP_CARDINALITY],
		    bus.[DIMENSION_UNIQUE_NAME],
		    bus.[DIMENSION_CARDINALITY],
		    bus.[DIMENSION_IS_FACT_DIMENSION],
		    bus.[DIMENSION_GRANULARITY],
		    dim.[DIMENSION_MASTER_NAME],
		    1 AS Relationship
	   FROM OPENROWSET (''MSOLAP'',
					    ''DATASOURCE=' + @DataSource + ';Initial Catalog=' + @Catalog + ';'',
					    ''SELECT [CATALOG_NAME],
							     [CUBE_NAME],
							     [MEASUREGROUP_NAME],
							     [MEASUREGROUP_CARDINALITY],
							     [DIMENSION_UNIQUE_NAME],
							     [DIMENSION_CARDINALITY],
							     [DIMENSION_IS_FACT_DIMENSION],
							     [DIMENSION_GRANULARITY]
						    FROM $SYSTEM.MDSCHEMA_MEASUREGROUP_DIMENSIONS
						   WHERE [DIMENSION_IS_VISIBLE]''
					  ) bus
 INNER JOIN OPENROWSET (''MSOLAP'',
					    ''DATASOURCE=' + @DataSource + ';Initial Catalog=' + @Catalog + ';'',
					    ''SELECT [CATALOG_NAME],
								 [CUBE_NAME],
								 [DIMENSION_UNIQUE_NAME],
								 [DIMENSION_MASTER_NAME]
							FROM $SYSTEM.MDSCHEMA_DIMENSIONS
						   WHERE [DIMENSION_IS_VISIBLE]
						     AND DIMENSION_CAPTION <> ''''Measures'''''') dim ON CAST(bus.[CATALOG_NAME] AS VARCHAR(255)) = CAST(dim.[CATALOG_NAME] AS VARCHAR(255))
																			 AND CAST(bus.[CUBE_NAME] AS VARCHAR(255)) = CAST(dim.[CUBE_NAME] AS VARCHAR(255))
																			 AND CAST(bus.[DIMENSION_UNIQUE_NAME] AS VARCHAR(255)) = CAST(dim.[DIMENSION_UNIQUE_NAME] AS VARCHAR(255))
	 WHERE CAST(bus.[CUBE_NAME] AS VARCHAR(255)) = ''' + @Cube + '''
	   AND EXISTS (SELECT 1
					 FROM OPENROWSET (''MSOLAP'',
									  ''DATASOURCE=' + @DataSource + ';Initial Catalog=' + @Catalog + ';'',
									  ''SELECT [CATALOG_NAME],
											   [CUBE_NAME],
											   [MEASUREGROUP_NAME]
										  FROM $SYSTEM.MDSCHEMA_MEASURES
										 WHERE [MEASURE_IS_VISIBLE]''
									 ) m
					WHERE CAST(bus.[CATALOG_NAME] AS VARCHAR(255)) = CAST(m.[CATALOG_NAME] AS VARCHAR(255))
					  AND CAST(bus.[CUBE_NAME] AS VARCHAR(255)) = CAST(m.[CUBE_NAME] AS VARCHAR(255))
					  AND CAST(bus.[MEASUREGROUP_NAME] AS VARCHAR(255)) = CAST(m.[MEASUREGROUP_NAME] AS VARCHAR(255))
				  )'

	EXEC sp_executesql @Query

GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[upCubeDocCubes]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[upCubeDocCubes] AS' 
END
GO


ALTER PROCEDURE [dbo].[upCubeDocCubes]
(
	@DataSource				NVARCHAR(255),
	@Catalog				NVARCHAR(255)
)
AS

	DECLARE
		@Query				NVARCHAR(MAX)
  
	SET @Query =
	'SELECT *
	  FROM OPENROWSET (''MSOLAP'',
					   ''DATASOURCE=' + @DataSource + ';Initial Catalog=' + @Catalog + ';'',
					   ''SELECT *
						   FROM $SYSTEM.MDSCHEMA_CUBES
						  WHERE [CUBE_SOURCE] = 1''
					  )'

	EXEC sp_executesql @Query

GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[upCubeDocDimensionsForMeasureGroup]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[upCubeDocDimensionsForMeasureGroup] AS' 
END
GO

ALTER PROCEDURE [dbo].[upCubeDocDimensionsForMeasureGroup]
(
	@DataSource				NVARCHAR(255),
	@Catalog				NVARCHAR(255),
	@Cube					NVARCHAR(255),
	@MeasureGroup			NVARCHAR(255)
)
AS

	DECLARE
		@Query				NVARCHAR(MAX) = ''
  
	SET @Query = @Query +
	'DECLARE
		@BoxSize			INT,
		@Stretch			FLOAT

	 SET @BoxSize = 250
	 SET @Stretch = 1.4
	 
	 ;WITH BaseData AS
	 (
	
	 SELECT mgd.*,
			d.[DESCRIPTION],
			mgd.[DIMENSION_UNIQUE_NAME] AS DimensionCaption,
			mgd.[MEASUREGROUP_NAME] AS MeasureGroupCaption
	  FROM OPENROWSET (''MSOLAP'',
					   ''DATASOURCE=' + @DataSource + ';Initial Catalog=' + @Catalog + ';'',
					   ''SELECT [CATALOG_NAME] + [CUBE_NAME] + [MEASUREGROUP_NAME] + [DIMENSION_UNIQUE_NAME] AS Seq,
								[CATALOG_NAME],
								[CUBE_NAME],
								[MEASUREGROUP_NAME],
								[MEASUREGROUP_CARDINALITY],
								[DIMENSION_UNIQUE_NAME],
								[DIMENSION_CARDINALITY],
								[DIMENSION_IS_VISIBLE],
								[DIMENSION_IS_FACT_DIMENSION],
								[DIMENSION_GRANULARITY]
						   FROM $SYSTEM.MDSCHEMA_MEASUREGROUP_DIMENSIONS
						  WHERE [DIMENSION_IS_VISIBLE]''
					  ) mgd
INNER JOIN OPENROWSET (''MSOLAP'',
					   ''DATASOURCE=' + @DataSource + ';Initial Catalog=' + @Catalog + ';'',
					   ''SELECT [CATALOG_NAME],
								[CUBE_NAME],
								[DIMENSION_UNIQUE_NAME],
								[DESCRIPTION]
						   FROM $SYSTEM.MDSCHEMA_DIMENSIONS
						  WHERE [DIMENSION_IS_VISIBLE]
						    AND [DIMENSION_CAPTION] <> ''''Measures''''''
					  ) d ON CAST(mgd.[CATALOG_NAME] AS VARCHAR(255)) = CAST(d.[CATALOG_NAME] AS VARCHAR(255))
						 AND CAST(mgd.[CUBE_NAME] AS VARCHAR(255)) = CAST(d.[CUBE_NAME] AS VARCHAR(255))
						 AND CAST(mgd.[DIMENSION_UNIQUE_NAME] AS VARCHAR(255)) = CAST(d.[DIMENSION_UNIQUE_NAME] AS VARCHAR(255))
	 WHERE CAST(mgd.[CUBE_NAME] AS VARCHAR(255)) = ''' + @Cube + '''
	   AND CAST(mgd.[MEASUREGROUP_NAME] AS VARCHAR(255)) = ''' + @MeasureGroup + '''
	   AND EXISTS (SELECT 1
					 FROM OPENROWSET (''MSOLAP'',
									  ''DATASOURCE=' + @DataSource + ';Initial Catalog=' + @Catalog + ';'',
									  ''SELECT [CATALOG_NAME],
											   [CUBE_NAME],
											   [MEASUREGROUP_NAME]
										  FROM $SYSTEM.MDSCHEMA_MEASURES
										 WHERE [MEASURE_IS_VISIBLE]''
									 ) m
					WHERE CAST(mgd.[CATALOG_NAME] AS VARCHAR(255)) = CAST(m.[CATALOG_NAME] AS VARCHAR(255))
					  AND CAST(mgd.[CUBE_NAME] AS VARCHAR(255)) = CAST(m.[CUBE_NAME] AS VARCHAR(255))
					  AND CAST(mgd.[MEASUREGROUP_NAME] AS VARCHAR(255)) = CAST(m.[MEASUREGROUP_NAME] AS VARCHAR(255))
				  )
	   
	 ),
	 TotCount AS
	 (
	  SELECT COUNT(*) AS RecCount FROM BaseData
	 ),
	 RecCount AS
	 (
      SELECT RANK() OVER (ORDER BY CAST(Seq AS VARCHAR(255))) AS RecID,
			 RecCount,
			 BaseData.*
		FROM BaseData
  CROSS JOIN TotCount
	 ),
	 Angles AS
	 (
	  SELECT *,
			 SIN(RADIANS((CAST(RecID AS FLOAT) / CAST(RecCount AS FLOAT)) * 360)) * 1000 AS x,
			 COS(RADIANS((CAST(RecID AS FLOAT) / CAST(RecCount AS FLOAT)) * 360)) * 1000 AS y
		FROM RecCount
	 ),
	 Results AS
	 (
	  SELECT *,
			 geometry::STGeomFromText(''POINT('' + CAST(y AS VARCHAR(20)) + '' '' + CAST(x AS VARCHAR(20)) + '')'',4326) AS Posn,
			 geometry::STPolyFromText(''POLYGON (('' + CAST((y * @Stretch) + @BoxSize AS VARCHAR(20)) + '' '' + CAST(x + (@BoxSize / 2) AS VARCHAR(20)) + '', '' + CAST((y * @Stretch) - @BoxSize AS VARCHAR(20)) + '' '' + CAST(x + (@BoxSize / 2) AS VARCHAR(20)) + '', '' + CAST((y * @Stretch) - @BoxSize AS VARCHAR(20)) + '' '' + CAST(x-(@BoxSize/2) AS VARCHAR(20)) + '', '' + CAST((y * @Stretch) + @BoxSize AS VARCHAR(20)) + '' '' + CAST(x - (@BoxSize / 2) AS VARCHAR(20)) + '', '' + CAST((y * @Stretch) + @BoxSize AS VARCHAR(20)) + '' '' + CAST(x + (@BoxSize / 2) AS VARCHAR(20)) + '' ))'', 0) AS Box,
			 geometry::STLineFromText(''LINESTRING (0 0, '' + CAST((y * @Stretch) AS VARCHAR(20)) + '' '' + CAST(x AS VARCHAR(20)) + '')'', 0) AS Line,
			 geometry::STPolyFromText(''POLYGON (('' + CAST(0 + @BoxSize AS VARCHAR(20)) + '' '' + CAST(0 + (@BoxSize / 2) AS VARCHAR(20)) + '', '' + CAST(0 - @BoxSize AS VARCHAR(20)) + '' '' + CAST(0 + (@BoxSize / 2) AS VARCHAR(20)) + '', '' + CAST(0 - @BoxSize AS VARCHAR(20)) + '' '' + CAST(0 - (@BoxSize / 2) AS VARCHAR(20)) + '', '' + CAST(0+@BoxSize AS VARCHAR(20)) + '' '' + CAST(0 - (@BoxSize / 2) AS VARCHAR(20)) + '', '' + CAST(0 + @BoxSize AS VARCHAR(20)) + '' '' + CAST(0 + (@BoxSize / 2) AS VARCHAR(20)) + '' ))'', 0) AS CenterBox
		FROM Angles
	 )

	 SELECT *
	   FROM Results'

	EXEC sp_executesql @Query

GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[upCubeDocDimensionsInCube]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[upCubeDocDimensionsInCube] AS' 
END
GO

ALTER PROCEDURE [dbo].[upCubeDocDimensionsInCube]
(
	@DataSource				NVARCHAR(255),
	@Catalog				NVARCHAR(255),
	@Cube					NVARCHAR(255)
)
AS

	DECLARE
		@Query				NVARCHAR(MAX)
  
	SET @Query =
	'SELECT *
	  FROM OPENROWSET (''MSOLAP'',
					   ''DATASOURCE=' + @DataSource + ';Initial Catalog=' + @Catalog + ';'',
					   ''SELECT *
						   FROM $SYSTEM.MDSCHEMA_DIMENSIONS
						  WHERE [DIMENSION_IS_VISIBLE]
						    AND [DIMENSION_CAPTION] <> ''''Measures''''''
					  )
	 WHERE CAST([CUBE_NAME] AS VARCHAR(255)) = ''' + @Cube + ''''

	EXEC sp_executesql @Query

GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[upCubeDocListCatalog]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[upCubeDocListCatalog] AS' 
END
GO



ALTER PROCEDURE [dbo].[upCubeDocListCatalog]
(
	@DataSource				NVARCHAR(255)	
)
AS

	DECLARE
		@Query				NVARCHAR(MAX)
  
	SET @Query =
	'SELECT *
	  FROM OPENROWSET (''MSOLAP'',
					   ''DATASOURCE=' + @DataSource + ';'',
					   ''SELECT *
						   FROM $SYSTEM.dbschema_catalogs''
					  )'

	EXEC sp_executesql @Query

GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[upCubeDocMeasureGroupsForDimension]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[upCubeDocMeasureGroupsForDimension] AS' 
END
GO

ALTER PROCEDURE [dbo].[upCubeDocMeasureGroupsForDimension]
(
	@DataSource				NVARCHAR(255),
	@Catalog				NVARCHAR(255),
	@Cube					NVARCHAR(255),
	@Dimension				NVARCHAR(255)
)
AS

	DECLARE
		@Query				NVARCHAR(MAX)
  
	SET @Query =
	'SELECT mgd.*,
			mg.[DESCRIPTION]
	  FROM OPENROWSET (''MSOLAP'',
					   ''DATASOURCE=' + @DataSource + ';Initial Catalog=' + @Catalog + ';'',
					   ''SELECT [CATALOG_NAME],
								[CUBE_NAME],
								[MEASUREGROUP_NAME],
								[MEASUREGROUP_CARDINALITY],
								[DIMENSION_UNIQUE_NAME]
						   FROM $SYSTEM.MDSCHEMA_MEASUREGROUP_DIMENSIONS
						  WHERE [DIMENSION_IS_VISIBLE]''
					  ) mgd
INNER JOIN OPENROWSET (''MSOLAP'',
					   ''DATASOURCE=' + @DataSource + ';Initial Catalog=' + @Catalog + ';'',
					   ''SELECT [CATALOG_NAME],
								[CUBE_NAME],
								[MEASUREGROUP_NAME],
								[DESCRIPTION]
						   FROM $SYSTEM.MDSCHEMA_MEASUREGROUPS''
					  ) mg ON CAST(mgd.[CATALOG_NAME] AS VARCHAR(255)) = CAST(mg.[CATALOG_NAME] AS VARCHAR(255))
						  AND CAST(mgd.[CUBE_NAME] AS VARCHAR(255)) = CAST(mg.[CUBE_NAME] AS VARCHAR(255))
						  AND CAST(mgd.[MEASUREGROUP_NAME] AS VARCHAR(255)) = CAST(mg.[MEASUREGROUP_NAME] AS VARCHAR(255))
	 WHERE CAST(mgd.[CUBE_NAME] AS VARCHAR(255)) = ''' + @Cube + '''
	   AND CAST(mgd.[DIMENSION_UNIQUE_NAME] AS VARCHAR(255)) = ''' + @Dimension + '''
	   AND EXISTS (SELECT 1
					 FROM OPENROWSET (''MSOLAP'',
									  ''DATASOURCE=' + @DataSource + ';Initial Catalog=' + @Catalog + ';'',
									  ''SELECT [CATALOG_NAME],
											   [CUBE_NAME],
											   [MEASUREGROUP_NAME]
										  FROM $SYSTEM.MDSCHEMA_MEASURES
										 WHERE [MEASURE_IS_VISIBLE]''
									 ) m
					WHERE CAST(mgd.[CATALOG_NAME] AS VARCHAR(255)) = CAST(m.[CATALOG_NAME] AS VARCHAR(255))
					  AND CAST(mgd.[CUBE_NAME] AS VARCHAR(255)) = CAST(m.[CUBE_NAME] AS VARCHAR(255))
					  AND CAST(mgd.[MEASUREGROUP_NAME] AS VARCHAR(255)) = CAST(m.[MEASUREGROUP_NAME] AS VARCHAR(255))
				  )'

	EXEC sp_executesql @Query

GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[upCubeDocMeasureGroupsInCube]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[upCubeDocMeasureGroupsInCube] AS' 
END
GO

ALTER PROCEDURE [dbo].[upCubeDocMeasureGroupsInCube]
(
	@DataSource				NVARCHAR(255),
	@Catalog				NVARCHAR(255),
	@Cube					NVARCHAR(255)
)
AS

	DECLARE
		@Query				NVARCHAR(MAX)
  
	SET @Query =
	'SELECT mg.*
	  FROM OPENROWSET (''MSOLAP'',
					   ''DATASOURCE=' + @DataSource + ';Initial Catalog=' + @Catalog + ';'',
					   ''SELECT *
						   FROM $SYSTEM.MDSCHEMA_MEASUREGROUPS''
					  ) mg
	 WHERE CAST(mg.[CUBE_NAME] AS VARCHAR(255)) = ''' + @Cube + '''
	   AND EXISTS (SELECT 1
					 FROM OPENROWSET (''MSOLAP'',
									  ''DATASOURCE=' + @DataSource + ';Initial Catalog=' + @Catalog + ';'',
									  ''SELECT [CATALOG_NAME],
											   [CUBE_NAME],
											   [MEASUREGROUP_NAME]
										  FROM $SYSTEM.MDSCHEMA_MEASURES
										 WHERE [MEASURE_IS_VISIBLE]''
									 ) m
					WHERE CAST(mg.[CATALOG_NAME] AS VARCHAR(255)) = CAST(m.[CATALOG_NAME] AS VARCHAR(255))
					  AND CAST(mg.[CUBE_NAME] AS VARCHAR(255)) = CAST(m.[CUBE_NAME] AS VARCHAR(255))
					  AND CAST(mg.[MEASUREGROUP_NAME] AS VARCHAR(255)) = CAST(m.[MEASUREGROUP_NAME] AS VARCHAR(255))
				  )'

	EXEC sp_executesql @Query

GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[upCubeDocMeasuresInMeasureGroup]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[upCubeDocMeasuresInMeasureGroup] AS' 
END
GO

ALTER PROCEDURE [dbo].[upCubeDocMeasuresInMeasureGroup]
(
	@DataSource				NVARCHAR(255),
	@Catalog				NVARCHAR(255),
	@Cube					NVARCHAR(255),
	@MeasureGroup			NVARCHAR(255)
)
AS

	DECLARE
		@Query				NVARCHAR(MAX)
  
	SET @Query =
	'SELECT *
	  FROM OPENROWSET (''MSOLAP'',
					   ''DATASOURCE=' + @DataSource + ';Initial Catalog=' + @Catalog + ';'',
					   ''SELECT *
						   FROM $SYSTEM.MDSCHEMA_MEASURES
						  WHERE [MEASURE_IS_VISIBLE]''
					  )
	 WHERE CAST([CUBE_NAME] AS VARCHAR(255)) = ''' + @Cube + '''
	   AND CAST([MEASUREGROUP_NAME] AS VARCHAR(255)) = ''' + @MeasureGroup + ''''

	EXEC sp_executesql @Query

GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[upCubeDocSearch]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[upCubeDocSearch] AS' 
END
GO

ALTER PROCEDURE [dbo].[upCubeDocSearch]
(
	@DataSource				NVARCHAR(255),
	@Catalog				NVARCHAR(255),
	@Search					VARCHAR(255)
)
AS

	DECLARE
		@Query				NVARCHAR(MAX) = ''

	SET @Query = @Query +
	';WITH MetaData AS
	 (
	 
	 -- Cubes
	 SELECT CAST(''Cube'' AS VARCHAR(20)) AS [Type],
		    CAST([CATALOG_NAME] AS VARCHAR(255)) AS [Catalog],
		    CAST([CUBE_NAME] AS VARCHAR(255)) AS [Cube],
		    CAST([CUBE_NAME] AS VARCHAR(255)) AS [Name],
		    CAST([DESCRIPTION] AS VARCHAR(4000)) AS [Description],
		    CAST([CUBE_NAME] AS VARCHAR(255)) AS [Link]
	   FROM OPENROWSET (''MSOLAP'',
					    ''DATASOURCE=' + @DataSource + ';Initial Catalog=' + @Catalog + ';'',
					    ''SELECT *
						    FROM $SYSTEM.MDSCHEMA_CUBES
						   WHERE [CUBE_SOURCE] = 1''
					   )
	 
	  UNION ALL

	 -- Dimensions
	 SELECT CAST(''Dimension'' AS VARCHAR(20)) AS [Type],
		    CAST(DIM.[CATALOG_NAME] AS VARCHAR(255)) AS [Catalog],
		    CAST(DIM.[CUBE_NAME] AS VARCHAR(255)) AS [Cube],
		    CAST(DIM.DIMENSION_NAME AS VARCHAR(255)) AS [Name],
		    CAST(DIM.[DESCRIPTION] AS VARCHAR(4000)) AS [Description],
		    CAST(DIM.DIMENSION_UNIQUE_NAME AS VARCHAR(255)) AS [Link]
	   FROM OPENROWSET (''MSOLAP'',
					    ''DATASOURCE=' + @DataSource + ';Initial Catalog=' + @Catalog + ';'',
					    ''SELECT *
						    FROM $SYSTEM.MDSCHEMA_DIMENSIONS
						   WHERE [DIMENSION_IS_VISIBLE]
						     AND [DIMENSION_CAPTION] <> ''''Measures''''''
					   ) DIM
 INNER JOIN OPENROWSET (''MSOLAP'',
					    ''DATASOURCE=' + @DataSource + ';Initial Catalog=' + @Catalog + ';'',
					    ''SELECT *
						    FROM $SYSTEM.MDSCHEMA_CUBES
						   WHERE [CUBE_SOURCE] = 1''
					   ) CUB ON CAST(DIM.[CATALOG_NAME] AS VARCHAR(255)) = CAST(CUB.[CATALOG_NAME] AS VARCHAR(255))
							AND CAST(DIM.[CUBE_NAME] AS VARCHAR(255)) = CAST(CUB.[CUBE_NAME] AS VARCHAR(255))
	  
	  UNION ALL

	 -- Attributes
	 SELECT CAST(''Attribute'' AS VARCHAR(20)) AS [Type],
		    CAST(ATT.[CATALOG_NAME] AS VARCHAR(255)) AS [Catalog],
		    CAST(ATT.[CUBE_NAME] AS VARCHAR(255)) AS [Cube],
		    CAST(ATT.LEVEL_CAPTION AS VARCHAR(255)) AS [Name],
		    CAST(ATT.[DESCRIPTION] AS VARCHAR(4000)) AS [Description],
		    CAST(ATT.DIMENSION_UNIQUE_NAME AS VARCHAR(255)) AS [Link]
	   FROM OPENROWSET (''MSOLAP'',
					    ''DATASOURCE=' + @DataSource + ';Initial Catalog=' + @Catalog + ';'',
					    ''SELECT *
						    FROM $SYSTEM.MDSCHEMA_LEVELS
						   WHERE [LEVEL_NUMBER] > 0
							 AND [LEVEL_IS_VISIBLE]''
					   ) ATT
 INNER JOIN OPENROWSET (''MSOLAP'',
					    ''DATASOURCE=' + @DataSource + ';Initial Catalog=' + @Catalog + ';'',
					    ''SELECT *
						    FROM $SYSTEM.MDSCHEMA_CUBES
						   WHERE [CUBE_SOURCE] = 1''
					   ) CUB ON CAST(ATT.[CATALOG_NAME] AS VARCHAR(255)) = CAST(CUB.[CATALOG_NAME] AS VARCHAR(255))
							AND CAST(ATT.[CUBE_NAME] AS VARCHAR(255)) = CAST(CUB.[CUBE_NAME] AS VARCHAR(255))

	  UNION ALL

	 -- Measure Groups
	 SELECT CAST(''Measure Group'' AS VARCHAR(20)) AS [Type],
		    CAST(MEAGRP.[CATALOG_NAME] AS VARCHAR(255)) AS [Catalog],
		    CAST(MEAGRP.[CUBE_NAME] AS VARCHAR(255)) AS [Cube],
		    CAST(MEAGRP.[MEASUREGROUP_NAME] AS VARCHAR(255)) AS [Name],
		    CAST(MEAGRP.[DESCRIPTION] AS VARCHAR(4000)) AS [Description],
		    CAST(MEAGRP.[MEASUREGROUP_NAME] AS VARCHAR(255)) AS [Link]
	   FROM OPENROWSET (''MSOLAP'',
					    ''DATASOURCE=' + @DataSource + ';Initial Catalog=' + @Catalog + ';'',
					    ''SELECT *
						    FROM $SYSTEM.MDSCHEMA_MEASUREGROUPS''
					   ) MEAGRP
 INNER JOIN OPENROWSET (''MSOLAP'',
					    ''DATASOURCE=' + @DataSource + ';Initial Catalog=' + @Catalog + ';'',
					    ''SELECT *
						    FROM $SYSTEM.MDSCHEMA_CUBES
						   WHERE [CUBE_SOURCE] = 1''
					   ) CUB ON CAST(MEAGRP.[CATALOG_NAME] AS VARCHAR(255)) = CAST(CUB.[CATALOG_NAME] AS VARCHAR(255))
							AND CAST(MEAGRP.[CUBE_NAME] AS VARCHAR(255)) = CAST(CUB.[CUBE_NAME] AS VARCHAR(255))
	  WHERE EXISTS (SELECT 1
					 FROM OPENROWSET (''MSOLAP'',
									  ''DATASOURCE=' + @DataSource + ';Initial Catalog=' + @Catalog + ';'',
									  ''SELECT [CATALOG_NAME],
											   [CUBE_NAME],
											   [MEASUREGROUP_NAME]
										  FROM $SYSTEM.MDSCHEMA_MEASURES
										 WHERE [MEASURE_IS_VISIBLE]''
									 ) M
					WHERE CAST(MEAGRP.[CATALOG_NAME] AS VARCHAR(255)) = CAST(M.[CATALOG_NAME] AS VARCHAR(255))
					  AND CAST(MEAGRP.[CUBE_NAME] AS VARCHAR(255)) = CAST(M.[CUBE_NAME] AS VARCHAR(255))
					  AND CAST(MEAGRP.[MEASUREGROUP_NAME] AS VARCHAR(255)) = CAST(M.[MEASUREGROUP_NAME] AS VARCHAR(255))
				  )

	  UNION ALL

	 -- Measures
	 SELECT CAST(''Measure'' AS VARCHAR(20)) AS [Type],
		    CAST(MEA.[CATALOG_NAME] AS VARCHAR(255)) AS [Catalog],
		    CAST(MEA.[CUBE_NAME] AS VARCHAR(255)) AS [Cube],
		    CAST(MEA.[MEASURE_NAME] AS VARCHAR(255)) AS [Name],
		    CAST(MEA.[DESCRIPTION] AS VARCHAR(4000)) AS [Description],
		    CAST(MEA.[MEASUREGROUP_NAME] AS VARCHAR(255)) AS [Link]
	   FROM OPENROWSET (''MSOLAP'',
					    ''DATASOURCE=' + @DataSource + ';Initial Catalog=' + @Catalog + ';'',
					    ''SELECT *
						    FROM $SYSTEM.MDSCHEMA_MEASURES
						   WHERE [MEASURE_IS_VISIBLE]''
					   ) MEA
 INNER JOIN OPENROWSET (''MSOLAP'',
					    ''DATASOURCE=' + @DataSource + ';Initial Catalog=' + @Catalog + ';'',
					    ''SELECT *
						    FROM $SYSTEM.MDSCHEMA_CUBES
						   WHERE [CUBE_SOURCE] = 1''
					   ) CUB ON CAST(MEA.[CATALOG_NAME] AS VARCHAR(255)) = CAST(CUB.[CATALOG_NAME] AS VARCHAR(255))
							AND CAST(MEA.[CUBE_NAME] AS VARCHAR(255)) = CAST(CUB.[CUBE_NAME] AS VARCHAR(255))
	)

	SELECT *
	  FROM MetaData
	 WHERE ''' + @Search + ''' <> ''''
	   AND (
			[Name] LIKE ''%' + @Search + '%''
		 OR
			[Description] LIKE ''%' + @Search + '%''
		   )
	  '

	EXEC sp_executesql @Query
GO
