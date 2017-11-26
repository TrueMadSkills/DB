USE LAB_2
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID (N'RegisteredAutos', N'U') IS NOT NULL 
   DROP TABLE [dbo].RegisteredAutos

IF OBJECT_ID (N'Automobiles', N'U') IS NOT NULL 
   DROP TABLE [dbo].Automobiles

IF OBJECT_ID (N'Directions', N'U') IS NOT NULL 
   DROP TABLE [dbo].Directions

IF OBJECT_ID (N'AutoTypes', N'U') IS NOT NULL 
   DROP TABLE [dbo].AutoTypes

IF OBJECT_ID (N'RegionsNums', N'U') IS NOT NULL 
   DROP TABLE [dbo].RegionsNums

IF OBJECT_ID (N'Regions', N'U') IS NOT NULL 
   DROP TABLE [dbo].Regions

IF OBJECT_ID (N'Posts', N'U') IS NOT NULL 
   DROP TABLE [dbo].Posts

IF object_id(N'dbo.IsValidAutoNum', N'FN') IS NOT NULL
    DROP FUNCTION dbo.IsValidAutoNum
GO

IF object_id(N'dbo.TriggerCheckRegisteredAutos', N'TR') IS NOT NULL
    DROP TRIGGER dbo.TriggerCheckRegisteredAutos
GO

IF object_id(N'dbo.IsValidAutoRegion', N'FN') IS NOT NULL
    DROP FUNCTION dbo.IsValidAutoRegion
GO

IF object_id(N'dbo.GetTypeAuto', N'FN') IS NOT NULL
    DROP FUNCTION dbo.GetTypeAuto
GO

CREATE FUNCTION dbo.IsValidAutoNum(@autoNum char(50))  
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

CREATE TABLE [dbo].Regions(
	RegionName [nchar](50) NOT NULL,
	ConstitutionNum[int] NOT NULL
	PRIMARY KEY (ConstitutionNum)
)
GO

CREATE TABLE [dbo].RegionsNums(
	RegistrationNumAuto int NOT NULL,
	ConstitutionNum int FOREIGN KEY REFERENCES [Regions](ConstitutionNum),
	PRIMARY KEY (RegistrationNumAuto)
)
GO

CREATE TABLE [dbo].Posts(
	PostID int IDENTITY(1,1),
	PostName [nchar](50) NOT NULL
	PRIMARY KEY (PostID)
)
GO


CREATE TABLE [dbo].Directions(
	DirectionID int IDENTITY(1,1),
	DirectName nchar(50)
	PRIMARY KEY (DirectionID)
)
GO

CREATE TABLE [dbo].Automobiles(
	AutoNum nvarchar(50),
	RegionNum int FOREIGN KEY REFERENCES [RegionsNums](RegistrationNumAuto),
	PRIMARY KEY (AutoNum)
)
GO

CREATE TABLE [dbo].RegisteredAutos(
	RecordID int IDENTITY(1,1),
	PostID int FOREIGN KEY REFERENCES [Posts](PostID),
	AutoNum nvarchar(50) FOREIGN KEY REFERENCES [Automobiles](AutoNum) CHECK(dbo.IsValidAutoNum(AutoNum) = 1),
	DirectionID int FOREIGN KEY REFERENCES [Directions](DirectionID),
	RecordTime time(0)
)
GO

CREATE FUNCTION dbo.GetTypeAuto(@AutoNum nvarchar(50), @RegionNum int) 
	RETURNS char(50)
	BEGIN
		DECLARE @NUM_REGION int = 66;
		DECLARE @DirectionID int = (SELECT TOP 1 DirectionID
									FROM RegisteredAutos
									WHERE AutoNum = @AutoNum
									ORDER BY RecordID DESC)
		DECLARE @preDirectionID int =	(SELECT TOP 1 DirectionID
										FROM (SELECT TOP 2 RecordID, DirectionID
										FROM RegisteredAutos
										WHERE AutoNum = @AutoNum
										ORDER BY RecordID DESC) AS ins
										ORDER BY RecordID ASC)
		DECLARE @PostID int = (SELECT TOP 1 PostID
								FROM RegisteredAutos
								WHERE AutoNum = @AutoNum
								ORDER BY RecordID DESC)
		DECLARE @prePostID int = (SELECT TOP 1 PostID
									FROM (SELECT TOP 2 RecordID, PostID
									FROM RegisteredAutos
									WHERE AutoNum = @AutoNum
									ORDER BY RecordID DESC) AS ins
									ORDER BY RecordID ASC)
		DECLARE @existRecord int = (SELECT TOP 2 COUNT(AutoNum)
									FROM RegisteredAutos
									WHERE AutoNum = @AutoNum)
		if @existRecord > 1 and @preDirectionID = 1 and @DirectionID = 2
		begin
			if @prePostID = @PostID
				return 'Иногородний';
			else
				return 'Транзитный';
		end
		if @existRecord > 1 and @preDirectionID = 2 and @DirectionID = 1 and @NUM_REGION = @RegionNum
			return 'Местный'
		return 'Прочий';
	END;
GO

CREATE TRIGGER TriggerCheckRegisteredAutos
	ON RegisteredAutos INSTEAD OF INSERT
	AS 
	BEGIN
		DECLARE @PostID int = (SELECT TOP 1 PostID
					FROM inserted
					ORDER BY RecordID DESC)
		DECLARE @AutoNum nvarchar(50) = (SELECT TOP 1 AutoNum
					FROM inserted
					ORDER BY RecordID DESC)
		DECLARE @DirectionID int = (SELECT TOP 1 DirectionID
							FROM inserted
							WHERE AutoNum = @AutoNum
							ORDER BY RecordID DESC)
		DECLARE @Time time = (SELECT TOP 1 RecordTime
					FROM inserted
					ORDER BY RecordID DESC)
		DECLARE @preDirectionID int = (SELECT TOP 1 DirectionID
								FROM RegisteredAutos
								WHERE AutoNum = @AutoNum
								ORDER BY RecordID DESC) 
		DECLARE @existRecord int = (SELECT TOP 2 COUNT(AutoNum)
					FROM RegisteredAutos
					WHERE AutoNum = @AutoNum)
		IF @preDirectionID = @DirectionID AND @existRecord > 0
			BEGIN
				PRINT 'Машина не может два раза пересечь посты в одном направлении'
				ROLLBACK TRANSACTION
			END
		ELSE
			BEGIN
				IF NOT EXISTS (SELECT AutoNum FROM Automobiles WHERE AutoNum = @AutoNum)
				BEGIN
					declare @length int = len(@AutoNum);
					declare @region int = convert(int, substring(@AutoNum, 7, @length - 6));
					INSERT INTO Automobiles values (@AutoNum, @region);
				END
				INSERT INTO RegisteredAutos(PostID, AutoNum, DirectionID, RecordTime) values(@PostID, @AutoNum, @DirectionID, @Time) 
			END
	END
GO

---Представления---

IF OBJECT_ID (N'dbo.FirstAutosRegistration', N'U') IS NOT NULL
	DROP VIEW dbo.FirstAutosRegistration
GO

CREATE VIEW dbo.FirstAutosRegistration
AS
SELECT RegisteredAutos.AutoNum, MIN(RecordTime) AS firstTime
FROM dbo.RegisteredAutos
GROUP BY RegisteredAutos.AutoNum
GO

IF OBJECT_ID (N'dbo.FARfull', N'U') IS NOT NULL
	DROP VIEW dbo.FARfull
GO

CREATE VIEW dbo.FARfull
AS
SELECT DISTINCT far.AutoNum, far.firstTime AS FTime,  Directions.DirectName AS Dir
FROM dbo.FirstAutosRegistration AS far INNER JOIN
	 RegisteredAutos ON far.AutoNum = RegisteredAutos.AutoNum AND far.firstTime = RegisteredAutos.RecordTime JOIN
	 Directions ON RegisteredAutos.DirectionID = Directions.DirectionID
GO

IF OBJECT_ID (N'dbo.LastAutosRegistration', N'U') IS NOT NULL
	DROP VIEW dbo.LastAutosRegistration
GO

CREATE VIEW dbo.LastAutosRegistration
AS
SELECT AutoNum, MAX(RecordTime) AS lastTime
FROM dbo.RegisteredAutos
GROUP BY AutoNum
GO

IF OBJECT_ID (N'dbo.LARfull', N'U') IS NOT NULL
	DROP VIEW dbo.LARfull
GO

CREATE VIEW dbo.LARfull
AS
SELECT DISTINCT lar.AutoNum, lar.lastTime AS LTime, Directions.DirectName AS Dir
FROM dbo.LastAutosRegistration AS lar INNER JOIN
	 RegisteredAutos ON lar.AutoNum = RegisteredAutos.AutoNum AND lar.lastTime = RegisteredAutos.RecordTime JOIN
	 Directions ON RegisteredAutos.DirectionID = Directions.DirectionID
GO


IF OBJECT_ID(N'dbo.RegistrationRecordsView', N'U') IS NOT NULL
	DROP VIEW [dbo].[RegistrationRecordsView]
GO

CREATE VIEW RegistrationRecordsView
AS
SELECT DISTINCT dbo.GetTypeAuto(Automobiles.AutoNum, Regions.ConstitutionNum) AS 'Тип авто'
				, Automobiles.AutoNum AS 'Номер автомобиля'
				, Automobiles.RegionNum AS 'Номер региона'
				, Regions.RegionName AS 'Название региона'
				, far.FTime AS 'Время первой регистрации'
				, far.Dir AS 'Начальное направление'
				, lar.LTime AS 'Время последней регистрации'
				, lar.Dir AS 'Конечное направление'
FROM Automobiles INNER JOIN
	 RegionsNums ON Automobiles.RegionNum = RegionsNums.RegistrationNumAuto INNER JOIN
	 Regions ON RegionsNums.ConstitutionNum = Regions.ConstitutionNum INNER JOIN
	 FARfull AS far ON Automobiles.AutoNum = far.AutoNum INNER JOIN
	 --RegisteredAutos ON far.firstTime = RegisteredAutos.RecordTime AND Automobiles.AutoNum = RegisteredAutos.AutoNum INNER JOIN
	 --FARDirection ON Automobiles.AutoNum = 
	 --Directions ON RegisteredAutos.DirectionID = Directions.DirectionID INNER JOIN
	 LARfull AS lar ON Automobiles.AutoNum = lar.AutoNum
GO

CREATE INDEX IndexRegisteredAutos
ON RegisteredAutos(AutoNum)
INCLUDE (PostID, DirectionID, RecordTime);

SELECT * 
FROM RegistrationRecordsView
GO

---Заполнение---

INSERT INTO Regions(ConstitutionNum, RegionName) values (66, 'Свердловская область')
INSERT INTO Regions(ConstitutionNum, RegionName) values (74, 'Челябинская область')
INSERT INTO Regions(ConstitutionNum, RegionName) values (59, 'Пермский край')
INSERT INTO Regions(ConstitutionNum, RegionName) values (33, 'Владимирская область')
INSERT INTO Regions(ConstitutionNum, RegionName) values (86, 'Ханты-Мансийский автономный округ')

INSERT INTO RegionsNums(RegistrationNumAuto, ConstitutionNum) values (66, 66)
INSERT INTO RegionsNums(RegistrationNumAuto, ConstitutionNum) values (96, 66)
INSERT INTO RegionsNums(RegistrationNumAuto, ConstitutionNum) values (196, 66)
INSERT INTO RegionsNums(RegistrationNumAuto, ConstitutionNum) values (74, 74)
INSERT INTO RegionsNums(RegistrationNumAuto, ConstitutionNum) values (174, 74)
INSERT INTO RegionsNums(RegistrationNumAuto, ConstitutionNum) values (59, 59)
INSERT INTO RegionsNums(RegistrationNumAuto, ConstitutionNum) values (81, 59)
INSERT INTO RegionsNums(RegistrationNumAuto, ConstitutionNum) values (159, 59)
INSERT INTO RegionsNums(RegistrationNumAuto, ConstitutionNum) values (33, 33)
INSERT INTO RegionsNums(RegistrationNumAuto, ConstitutionNum) values (86, 86)
INSERT INTO RegionsNums(RegistrationNumAuto, ConstitutionNum) values (186, 86)

INSERT INTO Posts values ('Шоссе 66')
INSERT INTO Posts values ('Таганский')
INSERT INTO Posts values ('Вникудашный')
INSERT INTO Posts values ('Аварийный')

INSERT INTO Directions values('в город')
INSERT INTO Directions values('из города')

INSERT INTO RegisteredAutos(PostID, AutoNum, DirectionID, RecordTime) values(1, 'В123АН196', 1, '15:40:00')
INSERT INTO RegisteredAutos(PostID, AutoNum, DirectionID, RecordTime) values(2, 'А111АА96', 1, '15:45:00')
INSERT INTO RegisteredAutos(PostID, AutoNum, DirectionID, RecordTime) values(1, 'В123АН196', 2, '16:40:00')
INSERT INTO RegisteredAutos(PostID, AutoNum, DirectionID, RecordTime) values(4, 'Е228РУ66', 2, '04:15:00')
INSERT INTO RegisteredAutos(PostID, AutoNum, DirectionID, RecordTime) values(4, 'Е228РУ66', 1, '20:45:00')
INSERT INTO RegisteredAutos(PostID, AutoNum, DirectionID, RecordTime) values(3, 'В696НЕ186', 1, '08:03:00')
INSERT INTO RegisteredAutos(PostID, AutoNum, DirectionID, RecordTime) values(1, 'В696НЕ186', 2, '10:24:00')
INSERT INTO RegisteredAutos(PostID, AutoNum, DirectionID, RecordTime) values(2, 'М478ОР186', 2, '12:01:00')
INSERT INTO RegisteredAutos(PostID, AutoNum, DirectionID, RecordTime) values(4, 'М478ОР186', 1, '18:30:00')


--Тесты--
INSERT INTO RegisteredAutos(PostID, AutoNum, DirectionID, RecordTime) values(1, 'Й123АН196', 1, '15:40:00')
INSERT INTO RegisteredAutos(PostID, AutoNum, DirectionID, RecordTime) values(1, 'В12345196', 1, '15:40:00')
INSERT INTO RegisteredAutos(PostID, AutoNum, DirectionID, RecordTime) values(1, 'В123АН696', 1, '15:40:00')

INSERT INTO RegisteredAutos(PostID, AutoNum, DirectionID, RecordTime) values(1, 'В696НЕ186', 2, '11:54:00')
INSERT INTO RegisteredAutos(PostID, AutoNum, DirectionID, RecordTime) values(4, 'Е228РУ66', 1, '20:55:00')