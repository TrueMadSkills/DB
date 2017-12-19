--CREATE DATABASE Voronin
--GO
--DROP DATABASE Voronin
--GO

USE Voronin
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID (N'TariffInfo', N'U') IS NOT NULL 
   DROP TABLE TariffInfo
GO
IF OBJECT_ID (N'Crosses', N'U') IS NOT NULL 
   DROP TABLE Crosses
GO
IF OBJECT_ID (N'BestTariffes', N'U') IS NOT NULL 
   DROP TABLE BestTariffes
GO

CREATE TABLE TariffInfo(
	TariffID int IDENTITY(1,1) PRIMARY KEY,
	Name nvarchar(50),
	MonthlyFee real,
	MonthlyMinutes int,
	PricePerMin real
)
GO

CREATE TABLE Crosses(
	TariffID1 int FOREIGN KEY REFERENCES TariffInfo(TariffID),
	TariffID2 int FOREIGN KEY REFERENCES TariffInfo(TariffID),
	TimeCrossPoint real
)
GO

CREATE TABLE BestTariffes(
	TariffID int FOREIGN KEY REFERENCES TariffInfo(TariffID),
	TimeFrom real,
	TimeTo real
)
GO

INSERT INTO TariffInfo values('Повременной', 0, 0, 1)
INSERT INTO TariffInfo values('Смешанный', 30, 60, 2)
INSERT INTO TariffInfo values('Безлимитный', 100, 1000000, 0)
GO

IF OBJECT_ID (N'GetBestTariffID', N'FN') IS NOT NULL
	DROP FUNCTION GetBestTariffID
GO
CREATE FUNCTION GetBestTariffID(@MinutesAmount real)  
RETURNS INT
BEGIN
	DECLARE @ID int
	DECLARE @MonthlyFee real
	DECLARE @MonthlyMinutes int
	DECLARE @PricePerMin real

	DECLARE @minPrice real = 1000000
	DECLARE @minPriceID int = -1

	DECLARE @CURSOR CURSOR
	SET @CURSOR = CURSOR SCROLL
	FOR
	SELECT TariffID, MonthlyFee, MonthlyMinutes, PricePerMin 
	FROM TariffInfo

	OPEN @CURSOR
	FETCH NEXT FROM @CURSOR INTO @ID, @MonthlyFee, @MonthlyMinutes, @PricePerMin
	WHILE @@FETCH_STATUS = 0
	BEGIN
		DECLARE @currentPrice real
		IF @MinutesAmount <= @MonthlyMinutes
			SET @currentPrice = @MonthlyFee
		ELSE
			SET @currentPrice = @MonthlyFee + @PricePerMin * (@MinutesAmount - @MonthlyMinutes)
		IF @currentPrice < @minPrice
		BEGIN
			SET @minPrice = @currentPrice
			SET @minPriceID = @ID
		END
		FETCH NEXT FROM @CURSOR INTO @ID, @MonthlyFee, @MonthlyMinutes, @PricePerMin
	END
	CLOSE @CURSOR
	RETURN @minPriceID
END;
GO

SELECT *
FROM TariffInfo
WHERE TariffID = dbo.GetBestTariffID(110)
GO

---------------------------------------------------------------------------------------
DECLARE @ID1 int
DECLARE @MonthlyFee1 real
DECLARE @MonthlyMinutes1 int
DECLARE @PricePerMin1 real

DECLARE @ID2 int
DECLARE @MonthlyFee2 real
DECLARE @MonthlyMinutes2 int
DECLARE @PricePerMin2 real

DECLARE @lookInnerRecFrom int = 2

DECLARE @CURSOR_OUTER CURSOR
SET @CURSOR_OUTER = CURSOR SCROLL
FOR
SELECT TariffID, MonthlyFee, MonthlyMinutes, PricePerMin 
FROM TariffInfo

DECLARE @CURSOR_INNER CURSOR
SET @CURSOR_INNER = CURSOR SCROLL
FOR
SELECT TariffID, MonthlyFee, MonthlyMinutes, PricePerMin 
FROM TariffInfo
WHERE TariffID >= @lookInnerRecFrom

OPEN @CURSOR_OUTER
FETCH NEXT FROM @CURSOR_OUTER INTO @ID1, @MonthlyFee1, @MonthlyMinutes1, @PricePerMin1
WHILE @@FETCH_STATUS = 0
BEGIN
	OPEN @CURSOR_INNER
	FETCH NEXT FROM @CURSOR_INNER INTO @ID2, @MonthlyFee2, @MonthlyMinutes2, @PricePerMin2
	WHILE @@FETCH_STATUS = 0
	BEGIN
		DECLARE @currentCrossPoint real

		DECLARE @offset1 real = @PricePerMin1 * @MonthlyMinutes1 - @MonthlyFee1
		DECLARE @offset2 real = @PricePerMin2 * @MonthlyMinutes2 - @MonthlyFee2

		IF NOT (@MonthlyFee1 = 0 OR @PricePerMin2 = 0)
		BEGIN
			SET @currentCrossPoint = (@MonthlyFee1 + @offset2) / @PricePerMin2
			IF @currentCrossPoint > 0 AND @currentCrossPoint <= @MonthlyMinutes1 AND @currentCrossPoint >= @MonthlyMinutes2
				INSERT INTO Crosses values(@ID1, @ID2, @currentCrossPoint)
		END
		IF NOT (@MonthlyFee2 = 0 OR @PricePerMin1 = 0)
		BEGIN
			SET @currentCrossPoint = (@MonthlyFee2 + @offset1) / @PricePerMin1
			IF @currentCrossPoint > 0 AND @currentCrossPoint <= @MonthlyMinutes2 AND @currentCrossPoint >= @MonthlyMinutes1
				INSERT INTO Crosses values(@ID1, @ID2, @currentCrossPoint)
		END
		IF NOT @PricePerMin1 = @PricePerMin2
		BEGIN
			SET @currentCrossPoint = (@offset1 - @offset2) / (@PricePerMin1 - @PricePerMin2)
			IF @currentCrossPoint > 0 AND @currentCrossPoint >= @MonthlyMinutes1 AND @currentCrossPoint >= @MonthlyMinutes2
				INSERT INTO Crosses values(@ID1, @ID2, @currentCrossPoint)
		END
		FETCH NEXT FROM @CURSOR_INNER INTO @ID2, @MonthlyFee2, @MonthlyMinutes2, @PricePerMin2
	END
	CLOSE @CURSOR_INNER
	SET @lookInnerRecFrom += 1
	SET @CURSOR_INNER = CURSOR SCROLL
	FOR
	SELECT TariffID, MonthlyFee, MonthlyMinutes, PricePerMin 
	FROM TariffInfo
	WHERE TariffID >= @lookInnerRecFrom
	FETCH NEXT FROM @CURSOR_OUTER INTO @ID1, @MonthlyFee1, @MonthlyMinutes1, @PricePerMin1
END
CLOSE @CURSOR_OUTER
GO
------------------------------------------------------------------------------------------------
DECLARE @TimeFrom real = 0

DECLARE @TimeCrossPoint int

DECLARE @CURSOR_BEST CURSOR
SET @CURSOR_BEST = CURSOR SCROLL
FOR
SELECT TimeCrossPoint
FROM Crosses
ORDER BY TimeCrossPoint

OPEN @CURSOR_BEST
FETCH NEXT FROM @CURSOR_BEST INTO @TimeCrossPoint
WHILE @@FETCH_STATUS = 0
BEGIN
	INSERT INTO BestTariffes values(dbo.GetBestTariffID(@TimeFrom + (@TimeCrossPoint - @TimeFrom) / 2), @TimeFrom, @TimeCrossPoint)
	SET @TimeFrom = @TimeCrossPoint
	FETCH NEXT FROM @CURSOR_BEST INTO @TimeCrossPoint
END
CLOSE @CURSOR_BEST
INSERT INTO BestTariffes values(dbo.GetBestTariffID(@TimeFrom + (1000000 - @TimeFrom) / 2), @TimeFrom, 1000000)
GO

SELECT REPLACE(STR(TimeFrom) + ' - ' + STR(TimeTo), '  ', '') AS Интервал,
	   Name AS [Название тарифа]
FROM BestTariffes INNER JOIN
	 TariffInfo ON TariffInfo.TariffID = BestTariffes.TariffID
GO