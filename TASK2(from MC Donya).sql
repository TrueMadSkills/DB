USE master
GO

IF EXISTS (
	SELECT name 
		FROM sys.databases 
		WHERE name = N'Voronin'
)
DROP DATABASE Voronin
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

IF OBJECT_ID (N'Regions', N'U') IS NOT NULL
	DROP TABLE cars.Regions
GO

CREATE TABLE cars.Regions
	(ConstitutionNum int PRIMARY KEY NOT NULL,
	RegionName nvarchar(50) NOT NULL)
GO

IF OBJECT_ID (N'RegionNumbers', N'U') IS NOT NULL
	DROP TABLE cars.RegionNumbers
GO

CREATE TABLE cars.RegionNumbers
	(AutoRegionNumber int PRIMARY KEY NOT NULL,
	ConstitutionNum int FOREIGN KEY REFERENCES cars.Regions(ConstitutionNum) NOT NULL)
GO

IF OBJECT_ID (N'Posts', N'U') IS NOT NULL
	DROP TABLE cars.Posts
GO

CREATE TABLE cars.Posts
	(PostID int PRIMARY KEY IDENTITY(1,1) NOT NULL,
	PostName nvarchar(50) NOT NULL)
GO

IF OBJECT_ID (N'Directions', N'U') IS NOT NULL
	DROP TABLE cars.Directions
GO

CREATE TABLE cars.Directions
	(DirectionID int PRIMARY KEY IDENTITY(1,1) NOT NULL,
	DirectionName nvarchar(50) NOT NULL)
GO

IF OBJECT_ID (N'AutoTypes', N'U') IS NOT NULL
	DROP TABLE cars.AutoTypes
GO

--CREATE TABLE cars.AutoTypes
--	(TypeID int PRIMARY KEY NOT NULL,
--	TypeName nvarchar(50) NOT NULL)
--GO

IF OBJECT_ID (N'Autos', N'U') IS NOT NULL
	DROP TABLE cars.Autos
GO

CREATE TABLE cars.Autos
	(AutoID int PRIMARY KEY IDENTITY(1,1) NOT NULL,
	AutoNumber nvarchar(50) CHECK(cars.IsValidAutoNum(AutoNumber) = 1) NOT NULL,
	RegionNumber int FOREIGN KEY REFERENCES cars.RegionNumbers(AutoRegionNumber) NOT NULL,
	Direction int FOREIGN KEY REFERENCES cars.Directions(DirectionID) NOT NULL)
	--AutoType int FOREIGN KEY REFERENCES cars.AutoTypes(TypeID) NOT NULL)
GO

IF OBJECT_ID (N'RegistrationRecords', N'U') IS NOT NULL
	DROP TABLE cars.RegistrationRecords
GO

CREATE TABLE cars.RegistrationRecords
	(RecordID int IDENTITY(1,1) NOT NULL,
	PostID int FOREIGN KEY REFERENCES cars.Posts(PostID) NOT NULL,
	AutoID int FOREIGN KEY REFERENCES cars.Autos(AutoID) NOT NULL,
	RecordTime datetime NOT NULL)
GO

INSERT INTO cars.Regions values (66, 'Свердловская область')
INSERT INTO cars.Regions values (74, 'Челябинская область')
INSERT INTO cars.Regions values (59, 'Пермский край')

INSERT INTO cars.RegionNumbers values (66, 66)
INSERT INTO cars.RegionNumbers values (96, 66)
INSERT INTO cars.RegionNumbers values (196, 66)
INSERT INTO cars.RegionNumbers values (74, 74)
INSERT INTO cars.RegionNumbers values (174, 74)
INSERT INTO cars.RegionNumbers values (59, 59)
INSERT INTO cars.RegionNumbers values (81, 59)
INSERT INTO cars.RegionNumbers values (159, 59)

INSERT INTO cars.Posts values ('Север')
INSERT INTO cars.Posts values ('Юг')
INSERT INTO cars.Posts values ('Запад')
INSERT INTO cars.Posts values ('Восток')

INSERT INTO cars.Directions values('в город')
INSERT INTO cars.Directions values('из города')

INSERT INTO cars.Autos values('В123АН', 196, 1)
INSERT INTO cars.Autos values('Ё123АН', 196, 1)