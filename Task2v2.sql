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

--INSERT INTO cars.RegistrationRecords values(1, 'А123ВС96', 1, '14:15:17')
--INSERT INTO cars.RegistrationRecords values(1, 'А123ВС96', 1, '14:15:18')
--INSERT INTO cars.RegistrationRecords values(1, 'А123ВС96', 2, '14:15:19')
--TRUNCATE TABLE cars.Autos
--TRUNCATE TABLE cars.RegistrationRecords