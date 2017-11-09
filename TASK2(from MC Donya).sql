USE master
GO

IF EXISTS (
	SELECT name 
		FROM sys.databases 
		WHERE name = N'Voronin'
)
DROP DATABASE Voronin
GO

CREATE DATABASE Voronin
GO

USE Voronin
GO

CREATE SCHEMA cars
GO

IF OBJECT_ID (N'cars.IsValidAutoNum', N'FN') IS NOT NULL
	DROP FUNCTION cars.IsValidAutoNum
GO

CREATE FUNCTION cars.IsValidAutoNum(@autoNum char(50))  
RETURNS BIT
BEGIN
	if len(@autoNum) != 6 or substring(@autoNum, 2, 3) = '000'
		return 0;
	declare @ind smallint = 3;
	declare @length int = len(@autoNum);
	declare @textPart char(100) = substring(@autoNum, 1, 1) + substring(@autoNum, 5, 2);
	while @ind > 0 begin
		if substring(@textPart, @ind, 1) not like '[АВЕКМНОРСТУХ]'
			return 0;
		set @ind -= 1;
	end;
	return 1;
END;
GO

IF object_id(N'cars.IsValidAutoRegion', N'FN') IS NOT NULL
    DROP FUNCTION dbo.IsValidAutoRegion
GO

CREATE FUNCTION cars.IsValidAutoRegion(@autoRegion smallint)  
RETURNS BIT
BEGIN
	declare @firstSymbol smallint = cast(@autoRegion/100 as int);
	if @autoRegion >= 100 and @firstSymbol != 1 and @firstSymbol != 2 and @firstSymbol != 7 or @autoRegion = 0
		return 0;
	return 1;
END;
GO

IF OBJECT_ID (N'cars.Regions', N'U') IS NOT NULL
	DROP TABLE cars.Regions
GO

CREATE TABLE cars.Regions
	(ConstitutionNum int PRIMARY KEY NOT NULL,
	RegionName nvarchar(50) NOT NULL)
GO

IF OBJECT_ID (N'cars.RegionNumbers', N'U') IS NOT NULL
	DROP TABLE cars.RegionNumbers
GO

CREATE TABLE cars.RegionNumbers
	(AutoRegionNumber int PRIMARY KEY NOT NULL,
	ConstitutionNum int FOREIGN KEY REFERENCES cars.Regions(ConstitutionNum) NOT NULL)
GO

IF OBJECT_ID (N'cars.Posts', N'U') IS NOT NULL
	DROP TABLE cars.Posts
GO

CREATE TABLE cars.Posts
	(PostID int PRIMARY KEY IDENTITY(1,1) NOT NULL,
	PostName nvarchar(50) NOT NULL)
GO

IF OBJECT_ID (N'cars.Directions', N'U') IS NOT NULL
	DROP TABLE cars.Directions
GO

CREATE TABLE cars.Directions
	(DirectionID int PRIMARY KEY IDENTITY(1,1) NOT NULL,
	DirectionName nvarchar(50) NOT NULL)
GO

IF OBJECT_ID (N'cars.Autos', N'U') IS NOT NULL
	DROP TABLE cars.Autos
GO

CREATE TABLE cars.Autos
	(AutoID int PRIMARY KEY IDENTITY(1,1) NOT NULL,
	AutoNumber nvarchar(50) CHECK(cars.IsValidAutoNum(AutoNumber) = 1) NOT NULL,
	RegionNumber int CHECK(cars.IsValidAutoRegion(RegionNumber) = 1)
	    FOREIGN KEY REFERENCES cars.RegionNumbers(AutoRegionNumber) NOT NULL)
GO

IF OBJECT_ID (N'cars.RegistrationRecords', N'U') IS NOT NULL
	DROP TABLE cars.RegistrationRecords
GO

CREATE TABLE cars.RegistrationRecords
	(RecordID int PRIMARY KEY IDENTITY(1,1) NOT NULL,
	PostID int FOREIGN KEY REFERENCES cars.Posts(PostID) NOT NULL,
	AutoID int FOREIGN KEY REFERENCES cars.Autos(AutoID) NOT NULL,
	Direction int FOREIGN KEY REFERENCES cars.Directions(DirectionID) NOT NULL,
	RecordTime time(0) NOT NULL)
GO

CREATE TRIGGER CheckDirection
ON cars.RegistrationRecords
AFTER INSERT
AS
BEGIN
	DECLARE @insertedRecordID int
	DECLARE @insertedAutoID int
	DECLARE @insertedDirection int
	SET @insertedRecordID = (SELECT TOP 1 RecordID
						   FROM inserted
						   ORDER BY RecordID DESC)
	SET @insertedAutoID = (SELECT TOP 1 AutoID
						   FROM inserted
						   ORDER BY RecordID DESC)
	SET @insertedDirection = (SELECT TOP 1 Direction
							  FROM inserted
							  ORDER BY RecordID DESC)
	DECLARE @lastCapturedAutoDirection int
	SET @lastCapturedAutoDirection = (SELECT TOP 1 Direction
								  FROM cars.RegistrationRecords
								  WHERE cars.RegistrationRecords.AutoID = @insertedAutoID and
								   cars.RegistrationRecords.RecordID < @insertedRecordID
								  ORDER BY RecordID DESC)
	IF @insertedDirection = @lastCapturedAutoDirection
	BEGIN
		PRINT 'Автомобиль не может несколько раз подряд въехать/выехать'
		ROLLBACK TRANSACTION
	END
END
GO

INSERT INTO cars.Regions values (66, 'Свердловская область')
INSERT INTO cars.Regions values (74, 'Челябинская область')
INSERT INTO cars.Regions values (59, 'Пермский край')
GO

INSERT INTO cars.RegionNumbers values (66, 66)
INSERT INTO cars.RegionNumbers values (96, 66)
INSERT INTO cars.RegionNumbers values (196, 66)
INSERT INTO cars.RegionNumbers values (74, 74)
INSERT INTO cars.RegionNumbers values (174, 74)
INSERT INTO cars.RegionNumbers values (59, 59)
INSERT INTO cars.RegionNumbers values (81, 59)
INSERT INTO cars.RegionNumbers values (159, 59)
GO

INSERT INTO cars.Posts values ('Север')
INSERT INTO cars.Posts values ('Юг')
INSERT INTO cars.Posts values ('Запад')
INSERT INTO cars.Posts values ('Восток')
GO

INSERT INTO cars.Directions values('в город')
INSERT INTO cars.Directions values('из города')
GO

INSERT INTO cars.Autos values('В123АН', 196)
INSERT INTO cars.Autos values('В124АН', 74)
--INSERT INTO cars.Autos values('Ё123АН', 196, 1) проверка check
GO

INSERT INTO cars.RegistrationRecords values(1, 2, 1, '14:15:16')
INSERT INTO cars.RegistrationRecords values(2, 2, 2, '14:30:16')
--INSERT INTO cars.RegistrationRecords values(1, 2, 1, '14:15:17')
--INSERT INTO cars.RegistrationRecords values(1, 1, 2, '14:15:18')
--INSERT INTO cars.RegistrationRecords values(1, 1, 1, '14:15:18') проверка триггера
--TRUNCATE TABLE cars.RegistrationRecords
GO


----------два вспомогательных представления для вычисления типов авто-------------
IF OBJECT_ID (N'cars.FirstAutosRegistration', N'U') IS NOT NULL
	DROP VIEW cars.FirstAutosRegistration
GO

CREATE VIEW cars.FirstAutosRegistration
AS
SELECT AutoID, PostID, Direction, MIN(RecordTime) AS firstTime
FROM cars.RegistrationRecords
GROUP BY AutoID, PostID, Direction
GO

IF OBJECT_ID (N'cars.LastAutosRegistration', N'U') IS NOT NULL
	DROP VIEW cars.LastAutosRegistration
GO

CREATE VIEW cars.LastAutosRegistration
AS
SELECT AutoID, PostID, Direction, MAX(RecordTime) AS lastTime
FROM cars.RegistrationRecords
GROUP BY AutoID, PostID, Direction
GO
-----------------------------------------------------------------------------------

----------Типы автомобилей---------------------------------------------------------
IF OBJECT_ID (N'cars.TransitionalAutos', N'U') IS NOT NULL
	DROP VIEW cars.TransitionalAutos
GO

CREATE VIEW cars.TransitionalAutos
AS
SELECT DISTINCT cars.Autos.AutoNumber AS 'Номер'
				, cars.Autos.RegionNumber AS 'Номер региона'
				, cars.Regions.RegionName AS 'Название региона'
				, far.firstTime AS 'Время первого въезда'
				, lar.lastTime AS 'Время последнего выезда'
FROM cars.Autos INNER JOIN
	 cars.RegionNumbers ON cars.Autos.RegionNumber = cars.RegionNumbers.AutoRegionNumber INNER JOIN
	 cars.Regions ON cars.RegionNumbers.ConstitutionNum = cars.Regions.ConstitutionNum INNER JOIN
	 cars.FirstAutosRegistration AS far ON cars.Autos.AutoID = far.AutoID INNER JOIN
	 cars.LastAutosRegistration AS lar ON cars.Autos.AutoID = lar.AutoID
WHERE firstTime < lastTime 
	  AND far.Direction = 1 
	  AND lar.Direction = 2
	  AND far.PostID != lar.PostID
	  AND cars.RegionNumbers.ConstitutionNum != 66
GO