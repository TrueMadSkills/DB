USE [#Karpenko]
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

IF object_id(N'dbo.IsValidAutoRegion', N'FN') IS NOT NULL
    DROP FUNCTION dbo.IsValidAutoRegion
GO

IF object_id(N'dbo.GetTypeAuto', N'FN') IS NOT NULL
    DROP FUNCTION dbo.GetTypeAuto
GO

IF OBJECT_ID('group_Region', 'U') IS NOT NULL
	DROP VIEW group_Region
GO

IF OBJECT_ID('View1', 'U') IS NOT NULL
	DROP VIEW View1
GO

CREATE FUNCTION dbo.IsValidAutoNum(@autoNum char(50))  
RETURNS BIT
BEGIN
	if len(@autoNum) != 6 or substring(@autoNum, 2, 3) = '000'
		return 0;
	declare @ind smallint = 3;
	declare @length int = len(@autoNum);
	declare @textPart char(100) = substring(@autoNum, 1, 1) + substring(@autoNum, 5, 2);
	while @ind > 0 begin
		if substring(@textPart, @ind, 1) not like '[АВМЕКНОРТУС]'
			return 0;
		set @ind -= 1;
	end;
	return 1;
END;
GO

CREATE FUNCTION dbo.IsValidAutoRegion(@autoRegion smallint)  
RETURNS BIT
BEGIN 
	declare @firstSymbol smallint = cast(@autoRegion/100 as int);
	if @autoRegion >= 100 and @firstSymbol != 1 and @firstSymbol != 2 and @firstSymbol != 7 or @autoRegion = 0
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
	--CONSTRAINT PK_ID_Station 
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
	AutoID int IDENTITY(1,1),
	AutoNum char(50) CHECK(dbo.IsValidAutoNum(AutoNum) = 1),
	RegionNum int  CHECK(dbo.IsValidAutoRegion(RegionNum) = 1) FOREIGN KEY REFERENCES [RegionsNums](RegistrationNumAuto),
	PRIMARY KEY (AutoID)
)
GO

CREATE TABLE [dbo].RegisteredAutos(
	RecordID int IDENTITY(1,1),
	PostID int FOREIGN KEY REFERENCES [Posts](PostID),
	AutoID int FOREIGN KEY REFERENCES [Automobiles](AutoID),
	DirectionID int FOREIGN KEY REFERENCES [Directions](DirectionID),
	RecordDate smalldatetime
)
GO

CREATE TRIGGER TriggerCheckRegisteredAutos
	ON RegisteredAutos AFTER INSERT, UPDATE--То есть будет запускаться после добавления записи в табличку RegisteredAutos
	AS 
	BEGIN
		--Найдём id автомобиля последней записи
		DECLARE @AutoID int = (SELECT TOP 1 AutoID
					FROM RegisteredAutos
					ORDER BY RecordID DESC)
		--По id нужного нам авто находим id направления
		DECLARE @DirectionID int = (SELECT TOP 1 DirectionID
							FROM RegisteredAutos
							WHERE AutoID = @AutoID
							ORDER BY RecordID DESC)
		--вот тут уже смотрим id направления предыдущей записи
		DECLARE @preDirectionID int = (SELECT TOP 1 DirectionID
						FROM (SELECT TOP 2 RecordID, DirectionID
								FROM RegisteredAutos
								WHERE AutoID = @AutoID
								ORDER BY RecordID DESC) AS ins
						ORDER BY RecordID ASC)
		--ну и проверка, а вдруг наш автомобиль впервые зарегистрирован, то есть находим первые 2 записи
		DECLARE @existRecord int = (SELECT TOP 2 COUNT(AutoID)
					FROM RegisteredAutos
					WHERE AutoID = @AutoID)
		--проверяем, совпали ли наши направления, причем число записей для данного авто больше одной
		IF @preDirectionID = @DirectionID AND @existRecord != 1
		BEGIN
			PRINT 'ERROR'
			ROLLBACK TRANSACTION
		END
	END
GO

--получаем тип авто
CREATE FUNCTION dbo.GetTypeAuto(@AutoID int, @DirectionID int, @PostID int, @RegionNum int)  
RETURNS char
BEGIN
	DECLARE @NUM_REGION int = 96;
	if @NUM_REGION = @RegionNum
		return 'Местный'
	DECLARE @preDirectionID int = (SELECT TOP 1 DirectionID
					FROM (SELECT TOP 2 RecordID, DirectionID
							FROM RegisteredAutos
							WHERE AutoID = @AutoID
							ORDER BY RecordID DESC) AS ins
					ORDER BY RecordID ASC)
	DECLARE @prePostID int = (SELECT TOP 1 DirectionID
					FROM (SELECT TOP 2 RecordID, DirectionID
							FROM RegisteredAutos
							WHERE AutoID = @AutoID
							ORDER BY RecordID DESC) AS ins
					ORDER BY RecordID ASC)
	DECLARE @existRecord int = (SELECT TOP 2 COUNT(AutoID)
				FROM RegisteredAutos
				WHERE AutoID = @AutoID)
	if @existRecord > 1 and @preDirectionID = 1 and @DirectionID = 2
		if @prePostID = @PostID
			return 'Иногородний';
		else
			return 'Транзитный';
	
	return 'Прочий';
END;
GO

--жесткий запрос, надо тестить, думаю, баги будут.. уже спать хочу, поэтому насрать..
CREATE VIEW View1 
AS SELECT dbo.GetTypeAuto(RegisteredAutos.AutoID, RegisteredAutos.DirectionID, RegisteredAutos.PostID, Automobiles.RegionNum) AS 'Тип авто',
	Automobiles.AutoNum AS 'Номер авто',
	Automobiles.RegionNum AS 'Номер региона',
	Regions.RegionName AS 'Имя Региона',
	RegisteredAutos.RecordDate
FROM RegisteredAutos INNER JOIN
	Automobiles ON RegisteredAutos.AutoID = Automobiles.AutoID INNER JOIN
	RegionsNums ON  Automobiles.RegionNum = RegionsNums.RegistrationNumAuto INNER JOIN
	Regions ON Regions.ConstitutionNum = RegionsNums.ConstitutionNum
WHERE Automobiles.RegionNum > 100
GROUP BY Automobiles.AutoNum, Automobiles.RegionNum

SELECT * 
FROM View1
GO

--индекс тупо ускоряет поиск с where при больших данных, создаётся очень просто
CREATE INDEX IndexRegisteredAutos
--тк искали в триггере по ид автомобиля
ON RegisteredAutos(AutoID)
--здесь пишем неключевые столбцы, не уверен, что так надо
INCLUDE (PostID, DirectionID, RecordDate);


INSERT INTO Regions(ConstitutionNum, RegionName) values (66, 'Свердловская область')
INSERT INTO Regions(ConstitutionNum, RegionName) values (74, 'Челябинская область')
INSERT INTO Regions(ConstitutionNum, RegionName) values (59, 'Пермский край')

INSERT INTO RegionsNums(RegistrationNumAuto, ConstitutionNum) values (66, 66)
INSERT INTO RegionsNums(RegistrationNumAuto, ConstitutionNum) values (96, 66)
INSERT INTO RegionsNums(RegistrationNumAuto, ConstitutionNum) values (196, 66)
INSERT INTO RegionsNums(RegistrationNumAuto, ConstitutionNum) values (74, 74)
INSERT INTO RegionsNums(RegistrationNumAuto, ConstitutionNum) values (174, 74)
INSERT INTO RegionsNums(RegistrationNumAuto, ConstitutionNum) values (59, 59)
INSERT INTO RegionsNums(RegistrationNumAuto, ConstitutionNum) values (81, 59)
INSERT INTO RegionsNums(RegistrationNumAuto, ConstitutionNum) values (159, 59)

INSERT INTO Posts values ('Север')
INSERT INTO Posts values ('Юг')
INSERT INTO Posts values ('Запад')
INSERT INTO Posts values ('Восток')

INSERT INTO Directions values('в город')
INSERT INTO Directions values('из города')

INSERT INTO Automobiles values('В123АН', 196)
INSERT INTO Automobiles values('Ё123АН', 196)
INSERT INTO Automobiles values('А111АА', 96)
INSERT INTO Automobiles values('А111АА', 396)

INSERT INTO RegisteredAutos(PostID, AutoID, DirectionID, RecordDate) values(1, 1, 1, '2017-10-06 15:40:00')
INSERT INTO RegisteredAutos(PostID, AutoID, DirectionID, RecordDate) values(2, 1, 1, '2017-10-06 15:45:00')
--Ромка ЛОХ