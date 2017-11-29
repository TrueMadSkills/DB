USE [#Karpenko]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID (N'[dbo].MatchCommand', N'U') IS NOT NULL 
   DROP TABLE [dbo].MatchCommand

IF OBJECT_ID (N'[dbo].Goals', N'U') IS NOT NULL 
   DROP TABLE [dbo].Goals

IF OBJECT_ID (N'[dbo].Games', N'U') IS NOT NULL 
   DROP TABLE [dbo].Games

IF OBJECT_ID (N'[dbo].Players', N'U') IS NOT NULL 
   DROP TABLE [dbo].Players

IF OBJECT_ID (N'[dbo].Commands', N'U') IS NOT NULL 
   DROP TABLE [dbo].Commands

IF OBJECT_ID (N'[dbo].TypesCommand', N'U') IS NOT NULL 
   DROP TABLE [dbo].TypesCommand

CREATE TABLE [dbo].Commands(
	ID int IDENTITY(1,1),
	Name nvarchar(50)
	PRIMARY KEY(ID)
)
GO

CREATE TABLE [dbo].Players(
	ID int IDENTITY(1,1),
	Name nvarchar(50),
	Surname nvarchar(50),
	Patronymic nvarchar(50),
	Command int FOREIGN KEY REFERENCES Commands(ID)
	PRIMARY KEY(ID)
)
GO

CREATE TABLE [dbo].Games(
	ID int IDENTITY(1,1),
	DateGame smalldatetime
	PRIMARY KEY(ID)
)
GO

CREATE TABLE [dbo].TypesCommand(
	ID int IDENTITY(1,1),
	TypeCommand nvarchar(50)
	PRIMARY KEY(ID)
)
GO

CREATE TABLE [dbo].MatchCommand(
	IDMatch int FOREIGN KEY REFERENCES Games(ID),
	IDCommand int FOREIGN KEY REFERENCES Commands(ID),
	Goalkeeper int FOREIGN KEY REFERENCES Players(ID),
	TypeCommand int FOREIGN KEY REFERENCES TypesCommand(ID),
	Goals int
)
GO

CREATE TABLE [dbo].Goals(
	ID int IDENTITY(1,1),
	IDMatch int FOREIGN KEY REFERENCES Games(ID),
	IDPlayer int FOREIGN KEY REFERENCES Players(ID)
	PRIMARY KEY(ID)
)
GO

--CREATE FUNCTION dbo.GetScoresCommand(@IDCommand int)  
--RETURNS int
--BEGIN
--	DECLARE @CountVictories int = (SELECT COUNT(t1.IDMatch) 
--									FROM MatchCommand t1
--									INNER JOIN MatchCommand t2 ON t1.IDMatch = t2.IDMatch
--									WHERE t1.Goals > t2.Goals AND t1.IDCommand = @IDCommand)
--	return 0;
--END;
--GO  

INSERT INTO TypesCommand values('Хозяин')
INSERT INTO TypesCommand values('Гость')
GO

INSERT INTO Commands values('Спартак')
INSERT INTO Commands values('Урал')
INSERT INTO Commands values('Рубин')
GO

INSERT INTO Players(Name, Command) values('1', 1)
INSERT INTO Players(Name, Command) values('2', 1)
INSERT INTO Players(Name, Command) values('3', 2)
INSERT INTO Players(Name, Command) values('4', 2)
INSERT INTO Players(Name, Command) values('5', 3)
INSERT INTO Players(Name, Command) values('6', 3)
GO

INSERT INTO Games values('10.02.2008')
INSERT INTO Games values('10.03.2008')
INSERT INTO Games values('10.04.2008')
INSERT INTO Games values('10.05.2008')
INSERT INTO Games values('10.06.2008')
GO

INSERT INTO Goals values(1, 5)
INSERT INTO Goals values(1, 3)
INSERT INTO Goals values(1, 4)
INSERT INTO Goals values(2, 5)
INSERT INTO Goals values(2, 1)
INSERT INTO Goals values(2, 2)
INSERT INTO Goals values(2, 1)
INSERT INTO Goals values(3, 1)
INSERT INTO Goals values(3, 3)
GO

INSERT INTO MatchCommand(IDMatch, IDCommand, Goalkeeper, TypeCommand, Goals) values(1, 3, 5, 1, 1)
INSERT INTO MatchCommand(IDMatch, IDCommand, Goalkeeper, TypeCommand, Goals) values(1, 2, 3, 2, 2)

INSERT INTO MatchCommand(IDMatch, IDCommand, Goalkeeper, TypeCommand, Goals) values(2, 3, 5, 2, 1)
INSERT INTO MatchCommand(IDMatch, IDCommand, Goalkeeper, TypeCommand, Goals) values(2, 1, 1, 1, 3)

INSERT INTO MatchCommand(IDMatch, IDCommand, Goalkeeper, TypeCommand, Goals) values(3, 2, 3, 1, 1)
INSERT INTO MatchCommand(IDMatch, IDCommand, Goalkeeper, TypeCommand, Goals) values(3, 1, 1, 2, 1)
GO

--DECLARE @IDCommand INT = 3;
--SELECT COUNT(t1.IDMatch) AS 'Число побед' 
--	FROM MatchCommand t1
--	INNER JOIN MatchCommand t2 ON t1.IDMatch = t2.IDMatch
--	WHERE t1.Goals > t2.Goals AND t1.IDCommand = @IDCommand

--DECLARE @IDCommand INT = 2;
--SELECT Count(t1.IDCommand)
--	FROM MatchCommand t1
--	INNER JOIN MatchCommand t2 ON t1.IDMatch = t2.IDMatch
--	WHERE t1.Goals > t2.Goals AND t1.IDCommand = @IDCommand AND t1.IDCommand != t2.IDCommand


IF OBJECT_ID (N'dbo.GetPointsCommand', N'FN') IS NOT NULL
	DROP FUNCTION dbo.GetPointsCommand
GO
CREATE FUNCTION dbo.GetPointsCommand(@CommandID int)  
RETURNS INT
BEGIN
	declare @pointsWins int = (SELECT Count(t1.IDCommand)
							FROM MatchCommand t1
							INNER JOIN MatchCommand t2 ON t1.IDMatch = t2.IDMatch
							WHERE t1.Goals > t2.Goals AND t1.IDCommand = @CommandID AND t1.IDCommand != t2.IDCommand)
	declare @pointsDraws int = (SELECT Count(t1.IDCommand)
							FROM MatchCommand t1
							INNER JOIN MatchCommand t2 ON t1.IDMatch = t2.IDMatch
							WHERE t1.Goals = t2.Goals AND t1.IDCommand = @CommandID AND t1.IDCommand != t2.IDCommand)
	return @pointsWins*3 + @pointsDraws;
END;
GO



SELECT Commands.Name AS 'Команда',
	dbo.GetPointsCommand(t1.IDCommand) AS 'Очки',
	SUM(t1.Goals) AS 'Голы',
	SUM(t2.Goals) AS 'Пропущено'
FROM MatchCommand t1
	INNER JOIN MatchCommand t2 ON t1.IDMatch = t2.IDMatch
	INNER JOIN Commands ON t1.IDCommand = Commands.ID
WHERE t1.IDCommand != t2.IDCommand
GROUP BY Commands.Name, t1.IDCommand
GO