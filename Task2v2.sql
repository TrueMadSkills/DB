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
CREATE FUNCTION cars.IsValidAutoNum(@autoNum nvarchar(50))  
RETURNS BIT
BEGIN
	declare @length int = len(@autoNum);
	if @length != 8 and @length != 9
		return 0;
	declare @textPart nvarchar(50) = substring(@autoNum, 1, 1) + substring(@autoNum, 5, 2);
	declare @numPart nvarchar(50) = substring(@autoNum, 2, 3);
	declare @regionPart nvarchar(50) = substring(@autoNum, 7, @length - 6);
	if @textPart not like '[АВЕКМНОРСТУХ][АВЕКМНОРСТУХ][АВЕКМНОРСТУХ]'
		return 0;
	if @numPart = '000' or @numPart not like '[0-9][0-9][0-9]'
		return 0;
	if @regionPart = '00' or (@regionPart not like '[0-9][0-9]' and @regionPart not like '[1,2,7][0-9][0-9]')
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
	(AutoID nvarchar(50) PRIMARY KEY NOT NULL,
	AutoNumber nvarchar(50) NOT NULL,
	RegionNumber int FOREIGN KEY REFERENCES cars.RegionNumbers(AutoRegionNumber) NOT NULL)
GO

IF OBJECT_ID (N'cars.RegistrationRecords', N'U') IS NOT NULL
	DROP TABLE cars.RegistrationRecords
GO
CREATE TABLE cars.RegistrationRecords
	(RecordID int PRIMARY KEY IDENTITY(1,1) NOT NULL,
	PostID int FOREIGN KEY REFERENCES cars.Posts(PostID) NOT NULL,
	AutoID nvarchar(50) CHECK(cars.IsValidAutoNum(AutoID) = 1)
	    FOREIGN KEY REFERENCES cars.Autos(AutoID) NOT NULL,
	Direction int FOREIGN KEY REFERENCES cars.Directions(DirectionID) NOT NULL,
	RecordTime time(0) NOT NULL)
GO

CREATE TRIGGER CheckDirection
ON cars.RegistrationRecords
INSTEAD OF INSERT
AS
BEGIN
	DECLARE @insertedPostID int = (SELECT TOP 1 PostID
								   FROM inserted
								   ORDER BY RecordTime DESC)
	DECLARE @insertedAutoID nvarchar(50) = (SELECT TOP 1 AutoID
											FROM inserted
											ORDER BY RecordTime DESC)
	DECLARE @insertedDirection int = (SELECT TOP 1 Direction
									  FROM inserted
									  ORDER BY RecordTime DESC)
	DECLARE @insertedTime time = (SELECT TOP 1 RecordTime
								  FROM inserted
								  ORDER BY RecordTime DESC)
	DECLARE @lastCapturedAutoDirection int = (SELECT TOP 1 Direction
											  FROM cars.RegistrationRecords
											  WHERE cars.RegistrationRecords.AutoID = @insertedAutoID and
												    cars.RegistrationRecords.RecordTime < @insertedTime
											  ORDER BY RecordTime DESC)
	IF NOT EXISTS (SELECT AutoID FROM Autos WHERE AutoID = @insertedAutoID)
	BEGIN
		declare @length int = len(@insertedAutoID);
		declare @numPart nvarchar(50) = substring(@insertedAutoID, 1, 6);
		declare @regionPart int = convert(int, substring(@insertedAutoID, 7, @length - 6));
		INSERT INTO Autos values (@insertedAutoID, @numPart, @regionPart);
	END
	IF NOT @insertedDirection = @lastCapturedAutoDirection 
	   OR NOT EXISTS (SELECT TOP 1 Direction
					  FROM cars.RegistrationRecords
					  WHERE cars.RegistrationRecords.AutoID = @insertedAutoID and
						  cars.RegistrationRecords.RecordTime < @insertedTime
					  ORDER BY RecordTime DESC)
		INSERT INTO cars.RegistrationRecords values (@insertedPostID, @insertedAutoID, @insertedDirection, @insertedTime);
	ELSE
		PRINT 'Автомобиль не может несколько раз подряд въехать/выехать'
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

INSERT INTO cars.RegistrationRecords values(1, 'А123ВС74', 1, '14:15:16')
INSERT INTO cars.RegistrationRecords values(2, 'А123ВС74', 2, '14:30:16')
INSERT INTO cars.RegistrationRecords values(1, 'А123ВС74', 1, '14:40:16')
INSERT INTO cars.RegistrationRecords values(2, 'А123ВС74', 2, '14:50:16')
INSERT INTO cars.RegistrationRecords values(1, 'У555ЕР59', 1, '16:40:16')
INSERT INTO cars.RegistrationRecords values(1, 'У555ЕР59', 2, '16:50:16')
INSERT INTO cars.RegistrationRecords values(4, 'К969НО196', 2, '18:40:16')
INSERT INTO cars.RegistrationRecords values(4, 'К969НО196', 1, '18:50:16')
INSERT INTO cars.RegistrationRecords values(3, 'А111АА81', 1, '23:55:16')
GO
--INSERT INTO cars.RegistrationRecords values(1, 'А123ВС96', 1, '14:15:17')
--INSERT INTO cars.RegistrationRecords values(1, 'А123ВС96', 1, '14:15:18')
--INSERT INTO cars.RegistrationRecords values(1, 'А123ВС96', 2, '14:15:19')
--TRUNCATE TABLE cars.Autos
--TRUNCATE TABLE cars.RegistrationRecords

CREATE FUNCTION cars.GetAutoType(@AutoID nvarchar(50), @ConstitutionNumber int) 
RETURNS nvarchar(50)
BEGIN
	DECLARE @homeRegion int = 66;
	DECLARE @lastDirection int = (SELECT TOP 1 Direction
								FROM cars.RegistrationRecords
								WHERE AutoID = @AutoID
								ORDER BY RecordID DESC)

	DECLARE @preLastDirection int = (SELECT TOP 1 Direction
								   FROM (SELECT TOP 2 RecordID, Direction
										 FROM cars.RegistrationRecords
										 WHERE AutoID = @AutoID
										 ORDER BY RecordID DESC) AS ins
								   ORDER BY RecordID)

	DECLARE @PostID int = (SELECT TOP 1 PostID
						   FROM cars.RegistrationRecords
						   WHERE AutoID = @AutoID
						   ORDER BY RecordID DESC)

	DECLARE @prePostID int = (SELECT TOP 1 PostID
							  FROM (SELECT TOP 2 RecordID, PostID
									FROM cars.RegistrationRecords
									WHERE AutoID = @AutoID
									ORDER BY RecordID DESC) AS ins
							  ORDER BY RecordID)

	DECLARE @existRecord int = (SELECT TOP 2 COUNT(AutoID)
								FROM cars.RegistrationRecords
								WHERE AutoID = @AutoID)

	if @existRecord > 1 and @preLastDirection = 1 and @lastDirection = 2
	begin
		if @prePostID = @PostID
			return 'Иногородний';
		else
			return 'Транзитный';
	end
	if @existRecord > 1 and @preLastDirection = 2 and @lastDirection = 1 and @homeRegion = @ConstitutionNumber
		return 'Местный'
	return 'Прочий';
END;
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
------------------------------------------------------------------------------------------------

----------Типы автомобилей (через view)---------------------------------------------------------
----Транзитные----
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

----Иногородние----
IF OBJECT_ID (N'cars.NonresidentAutos', N'U') IS NOT NULL
	DROP VIEW cars.NonresidentAutos
GO

CREATE VIEW cars.NonresidentAutos
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
	  AND far.PostID = lar.PostID
GO

----Местные----
IF OBJECT_ID (N'cars.LocalAutos', N'U') IS NOT NULL
	DROP VIEW cars.LocalAutos
GO

CREATE VIEW cars.LocalAutos
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
	  AND far.Direction = 2
	  AND lar.Direction = 1
	  AND cars.RegionNumbers.ConstitutionNum = 66
GO

----Прочие----
IF OBJECT_ID (N'cars.OtherAutos', N'U') IS NOT NULL
	DROP VIEW cars.OtherAutos
GO

CREATE VIEW cars.OtherAutos
AS
SELECT DISTINCT cars.Autos.AutoNumber AS 'Номер'
				, cars.Autos.RegionNumber AS 'Номер региона'
				, cars.Regions.RegionName AS 'Название региона'
FROM cars.Autos INNER JOIN
	 cars.RegionNumbers ON cars.Autos.RegionNumber = cars.RegionNumbers.AutoRegionNumber INNER JOIN
	 cars.Regions ON cars.RegionNumbers.ConstitutionNum = cars.Regions.ConstitutionNum INNER JOIN
	 cars.FirstAutosRegistration AS far ON cars.Autos.AutoID = far.AutoID INNER JOIN
	 cars.LastAutosRegistration AS lar ON cars.Autos.AutoID = lar.AutoID
EXCEPT SELECT [Номер], [Номер региона], [Название региона] FROM cars.TransitionalAutos
EXCEPT SELECT [Номер], [Номер региона], [Название региона] FROM cars.NonresidentAutos
EXCEPT SELECT [Номер], [Номер региона], [Название региона] FROM cars.LocalAutos
GO

----Универсальный селектор (через функцию определания типа)----

IF OBJECT_ID (N'cars.AutoTypes', N'U') IS NOT NULL
	DROP VIEW cars.AutoTypes
GO

CREATE VIEW cars.AutoTypes
AS
SELECT DISTINCT cars.GetAutoType(cars.Autos.AutoID, cars.Regions.ConstitutionNum) AS 'Тип авто'
				, cars.Autos.AutoNumber AS 'Номер'
				, cars.Autos.RegionNumber AS 'Номер региона'
				, cars.Regions.RegionName AS 'Название региона'
FROM cars.Autos INNER JOIN
	 cars.RegionNumbers ON cars.Autos.RegionNumber = cars.RegionNumbers.AutoRegionNumber INNER JOIN
	 cars.Regions ON cars.RegionNumbers.ConstitutionNum = cars.Regions.ConstitutionNum INNER JOIN
	 cars.FirstAutosRegistration AS far ON cars.Autos.AutoID = far.AutoID INNER JOIN
	 cars.LastAutosRegistration AS lar ON cars.Autos.AutoID = lar.AutoID
GO