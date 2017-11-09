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

CREATE FUNCTION dbo.IsValidAutoNum(@autoNum char(50))  
RETURNS BIT
BEGIN
	if len(@autoNum) != 6 or substring(@autoNum, 2, 3) = '000'
		return 0;
	declare @ind smallint = 3;
	declare @length int = len(@autoNum);
	declare @textPart char(100) = substring(@autoNum, 1, 1) + substring(@autoNum, 5, 2);
	while @ind > 0 begin
		if substring(@textPart, @ind, 1) not like '[ABCEYHKTMOPАВМЕКНОРТУС]'
			return 0;
		set @ind -= 1;
	end;
	return 1;
END;
GO

CREATE TABLE [dbo].Regions(
	RegionName [nvarchar](50) NOT NULL,
	ConstitutionNum[int] NOT NULL
	--CONSTRAINT PK_ID_Station 
	PRIMARY KEY (ConstitutionNum)
)
GO

CREATE TABLE [dbo].RegionsNums(
	RegistrationNumAuto int NOT NULL,
	ConstitutionNum int FOREIGN KEY REFERENCES [Regions](ConstitutionNum),
	--CONSTRAINT PK_ID_Station 
	PRIMARY KEY (RegistrationNumAuto)
)
GO

CREATE TABLE [dbo].Posts(
	PostID int IDENTITY(1,1),
	PostName [nvarchar](50) NOT NULL
	--CONSTRAINT PK_ID_Station 
	PRIMARY KEY (PostID)
)
GO


CREATE TABLE [dbo].Directions(
	DirectionID int IDENTITY(1,1),
	DirectName [nvarchar](50)
	PRIMARY KEY (DirectionID)
)
GO

--CREATE TABLE [dbo].AutoTypes(
--	TypeID int IDENTITY(1,1),
--	TypeName nchar
--	PRIMARY KEY (TypeID)
--)
--GO

CREATE TABLE [dbo].Automobiles(
	AutoID int IDENTITY(1,1),
	AutoNum char(50) CHECK(dbo.IsValidAutoNum(AutoNum) = 1),
	RegionNum int FOREIGN KEY REFERENCES [RegionsNums](RegistrationNumAuto),
	DirectionID int FOREIGN KEY REFERENCES [Directions](DirectionID)
	PRIMARY KEY (AutoID)
)
GO

CREATE TABLE [dbo].RegisteredAutos(
	RecordID int IDENTITY(1,1),
	PostID int FOREIGN KEY REFERENCES [Posts](PostID),
	AutoID int FOREIGN KEY REFERENCES [Automobiles](AutoID),
	RecordDate smalldatetime
)
GO

INSERT INTO dbo.Regions values ('Свердловская область', 66) 
INSERT INTO dbo.Regions values ('Челябинская область', 74) 
INSERT INTO dbo.Regions values ('Пермский край', 59) 

INSERT INTO dbo.RegionsNums values (66, 66) 
INSERT INTO dbo.RegionsNums values (96, 66) 
INSERT INTO dbo.RegionsNums values (196, 66) 
INSERT INTO dbo.RegionsNums values (74, 74) 
INSERT INTO dbo.RegionsNums values (174, 74) 
INSERT INTO dbo.RegionsNums values (59, 59) 
INSERT INTO dbo.RegionsNums values (81, 59) 
INSERT INTO dbo.RegionsNums values (159, 59) 

INSERT INTO dbo.Posts values ('Север') 
INSERT INTO dbo.Posts values ('Юг') 
INSERT INTO dbo.Posts values ('Запад') 
INSERT INTO dbo.Posts values ('Восток') 

INSERT INTO dbo.Directions values('в город') 
INSERT INTO dbo.Directions values('из города') 

INSERT INTO dbo.Automobiles values('В123АН', 196, 1) 
INSERT INTO dbo.Automobiles values('Ё123АН', 196, 1)
