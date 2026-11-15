-- Run with sqlcmd -b or in SSMS on a SQL Server development instance.
-- The database and seed rows are created only if absent.
USE master;
GO
IF DB_ID(N'CampusBookings') IS NULL CREATE DATABASE CampusBookings;
GO
USE CampusBookings;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
SET ARITHABORT ON;
GO
IF OBJECT_ID(N'dbo.Users',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Users (
        UserId int IDENTITY PRIMARY KEY,
        UserName nvarchar(50) NOT NULL UNIQUE,
        DisplayName nvarchar(80) NOT NULL,
        RoleName varchar(13) NOT NULL CHECK (RoleName IN ('Student','Staff','Administrator')),
        PasswordSalt binary(16) NOT NULL,
        PasswordHash binary(32) NOT NULL
    );
    CREATE TABLE dbo.Facilities (
        FacilityId int IDENTITY PRIMARY KEY,
        Name nvarchar(80) NOT NULL UNIQUE CHECK (LEN(LTRIM(RTRIM(Name))) > 0),
        Category nvarchar(30) NOT NULL CHECK (Category IN ('Discussion room','Computer lab','Meeting room','Multimedia room')),
        Location nvarchar(80) NOT NULL CHECK (LEN(LTRIM(RTRIM(Location))) > 0),
        Capacity int NOT NULL CHECK (Capacity BETWEEN 1 AND 500),
        IsActive bit NOT NULL DEFAULT 1
    );
    CREATE TABLE dbo.TimeSlots (
        SlotId tinyint PRIMARY KEY,
        StartAt time(0) NOT NULL UNIQUE,
        EndAt time(0) NOT NULL,
        CHECK (StartAt < EndAt),
        CHECK (SlotId BETWEEN 1 AND 10 AND DATEPART(hour, StartAt) = SlotId + 7
            AND DATEPART(minute, StartAt) = 0 AND DATEPART(second, StartAt) = 0
            AND DATEDIFF(second, StartAt, EndAt) = 3600)
    );
    CREATE TABLE dbo.Bookings (
        BookingId int IDENTITY PRIMARY KEY,
        UserId int NOT NULL REFERENCES dbo.Users(UserId),
        FacilityId int NOT NULL REFERENCES dbo.Facilities(FacilityId),
        BookingDate date NOT NULL,
        SlotId tinyint NOT NULL REFERENCES dbo.TimeSlots(SlotId),
        Purpose nvarchar(200) NOT NULL CHECK (LEN(LTRIM(RTRIM(Purpose))) > 0),
        Status tinyint NOT NULL DEFAULT 0 CHECK (Status BETWEEN 0 AND 3),
        CreatedUtc datetime2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
        ChangedUtc datetime2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
        ReviewedBy int NULL REFERENCES dbo.Users(UserId),
        CHECK ((Status IN (0,3)) OR ReviewedBy IS NOT NULL)
    );
    -- 0 Pending and 1 Approved both hold a slot. 2 Rejected and 3 Cancelled release it.
    CREATE UNIQUE INDEX UX_Bookings_HeldSlot
        ON dbo.Bookings(FacilityId, BookingDate, SlotId) WHERE Status IN (0,1);
    CREATE INDEX IX_Bookings_UserDate ON dbo.Bookings(UserId, BookingDate DESC);
    CREATE INDEX IX_Bookings_DateFacility ON dbo.Bookings(BookingDate, FacilityId) INCLUDE (Status);
    INSERT dbo.TimeSlots VALUES
       (1,'08:00','09:00'),(2,'09:00','10:00'),(3,'10:00','11:00'),(4,'11:00','12:00'),
       (5,'12:00','13:00'),(6,'13:00','14:00'),(7,'14:00','15:00'),(8,'15:00','16:00'),
       (9,'16:00','17:00'),(10,'17:00','18:00');
    INSERT dbo.Facilities(Name,Category,Location,Capacity) VALUES
       (N'Orchid Discussion Room',N'Discussion room',N'Library, Level 2',8),
       (N'Turing Computer Lab',N'Computer lab',N'Technology Block, Level 1',32),
       (N'Meranti Meeting Room',N'Meeting room',N'Administration Block, Level 3',14),
       (N'Studio B',N'Multimedia room',N'Media Centre, Level 1',24);
END;
GO
CREATE OR ALTER VIEW dbo.BookingDetails AS
SELECT b.BookingId,b.UserId,u.DisplayName,f.FacilityId,f.Name AS Facility,b.BookingDate,b.SlotId,
       t.StartAt,t.EndAt,b.Purpose,b.Status,b.CreatedUtc,b.ChangedUtc,b.ReviewedBy
FROM dbo.Bookings b
JOIN dbo.Users u ON u.UserId=b.UserId
JOIN dbo.Facilities f ON f.FacilityId=b.FacilityId
JOIN dbo.TimeSlots t ON t.SlotId=b.SlotId;
GO
CREATE OR ALTER PROCEDURE dbo.CreateBooking
    @UserId int, @FacilityId int, @BookingDate date, @SlotId tinyint, @Purpose nvarchar(200)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @Now datetime2 = DATEADD(hour,8,SYSUTCDATETIME()), @Start time(0), @Id int;
    SELECT @Start=StartAt FROM dbo.TimeSlots WHERE SlotId=@SlotId;
    IF @BookingDate IS NULL OR @Start IS NULL OR @BookingDate<CAST(@Now AS date)
       OR @BookingDate>DATEADD(day,30,CAST(@Now AS date))
       OR (@BookingDate=CAST(@Now AS date) AND @Start<=CAST(@Now AS time))
       OR NULLIF(LTRIM(RTRIM(@Purpose)),N'') IS NULL
       THROW 51001,'Enter an eligible date, time and purpose.',1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE UserId=@UserId AND RoleName IN ('Student','Staff'))
       THROW 51002,'Only students and staff can request bookings.',1;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS (SELECT 1 FROM dbo.Facilities WITH (UPDLOCK,HOLDLOCK) WHERE FacilityId=@FacilityId AND IsActive=1)
            THROW 51003,'The facility is no longer available.',1;
        INSERT dbo.Bookings(UserId,FacilityId,BookingDate,SlotId,Purpose)
        VALUES (@UserId,@FacilityId,@BookingDate,@SlotId,@Purpose);
        SET @Id=CONVERT(int,SCOPE_IDENTITY());
        COMMIT;
        SELECT @Id;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK;
        IF ERROR_NUMBER() IN (2601,2627) THROW 51004,'That slot is already held. Choose a different slot.',1;
        THROW;
    END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE dbo.CancelBooking @UserId int, @BookingId int
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Now datetime2 = DATEADD(hour,8,SYSUTCDATETIME());
    UPDATE b SET Status=3, ChangedUtc=SYSUTCDATETIME()
    FROM dbo.Bookings b JOIN dbo.TimeSlots t ON t.SlotId=b.SlotId
    WHERE b.BookingId=@BookingId AND b.UserId=@UserId AND b.Status IN (0,1)
      AND (b.BookingDate>CAST(@Now AS date)
        OR (b.BookingDate=CAST(@Now AS date) AND t.StartAt>CAST(@Now AS time)));
    SELECT @@ROWCOUNT;
END;
GO
CREATE OR ALTER PROCEDURE dbo.ReviewBooking @ActorId int, @BookingId int, @Decision tinyint
AS
BEGIN
    SET NOCOUNT ON;
    IF @Decision IS NULL OR @Decision NOT IN (1,2)
       OR NOT EXISTS (SELECT 1 FROM dbo.Users WHERE UserId=@ActorId AND RoleName='Administrator')
        THROW 51005,'The review is not permitted.',1;
    DECLARE @Now datetime2 = DATEADD(hour,8,SYSUTCDATETIME());
    UPDATE b SET Status=@Decision, ReviewedBy=@ActorId, ChangedUtc=SYSUTCDATETIME()
    FROM dbo.Bookings b JOIN dbo.TimeSlots t ON t.SlotId=b.SlotId
    WHERE b.BookingId=@BookingId AND b.Status=0
      AND (b.BookingDate>CAST(@Now AS date)
        OR (b.BookingDate=CAST(@Now AS date) AND t.StartAt>CAST(@Now AS time)));
    SELECT @@ROWCOUNT;
END;
GO
CREATE OR ALTER PROCEDURE dbo.SaveFacility
    @ActorId int, @FacilityId int, @Name nvarchar(80), @Category nvarchar(30),
    @Location nvarchar(80), @Capacity int
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE UserId=@ActorId AND RoleName='Administrator')
        THROW 51005,'The change is not permitted.',1;
    IF @FacilityId=0
        INSERT dbo.Facilities(Name,Category,Location,Capacity) VALUES (@Name,@Category,@Location,@Capacity);
    ELSE
        UPDATE dbo.Facilities SET Name=@Name,Category=@Category,Location=@Location,Capacity=@Capacity
        WHERE FacilityId=@FacilityId;
    SELECT @@ROWCOUNT;
END;
GO
CREATE OR ALTER PROCEDURE dbo.DeactivateFacility @ActorId int, @FacilityId int
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE UserId=@ActorId AND RoleName='Administrator')
        THROW 51005,'The change is not permitted.',1;
    DECLARE @Now datetime2 = DATEADD(hour,8,SYSUTCDATETIME()), @Active bit, @Changed int;
    BEGIN TRY
        BEGIN TRANSACTION;
        SELECT @Active=IsActive FROM dbo.Facilities WITH (UPDLOCK,HOLDLOCK) WHERE FacilityId=@FacilityId;
        IF EXISTS (SELECT 1 FROM dbo.Bookings b JOIN dbo.TimeSlots t ON t.SlotId=b.SlotId
          WHERE b.FacilityId=@FacilityId AND b.Status IN (0,1)
          AND (b.BookingDate>CAST(@Now AS date)
            OR (b.BookingDate=CAST(@Now AS date) AND t.StartAt>CAST(@Now AS time))))
            THROW 51006,'Resolve future bookings before deactivating this facility.',1;
        UPDATE dbo.Facilities SET IsActive=0 WHERE FacilityId=@FacilityId AND @Active=1;
        SET @Changed=@@ROWCOUNT;
        COMMIT;
        SELECT @Changed;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK;
        THROW;
    END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE dbo.UsageReport @From date, @Through date
AS
BEGIN
    SET NOCOUNT ON;
    SELECT f.Name AS Facility, f.IsActive, COUNT(b.BookingId) AS Total,
       SUM(CASE WHEN b.Status=0 THEN 1 ELSE 0 END) AS Pending,
       SUM(CASE WHEN b.Status=1 THEN 1 ELSE 0 END) AS Approved,
       SUM(CASE WHEN b.Status=2 THEN 1 ELSE 0 END) AS Rejected,
       SUM(CASE WHEN b.Status=3 THEN 1 ELSE 0 END) AS Cancelled,
       SUM(CASE WHEN b.Status=1 THEN 60 ELSE 0 END) AS ApprovedMinutes
    FROM dbo.Facilities f LEFT JOIN dbo.Bookings b
      ON b.FacilityId=f.FacilityId AND b.BookingDate BETWEEN @From AND @Through
    GROUP BY f.FacilityId,f.Name,f.IsActive
    ORDER BY f.Name;
END;
GO
