-- Run on the disposable development database after Setup.sql and DemoData.sql.
USE CampusBookings;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
SET ARITHABORT ON;
DECLARE @RoomName nvarchar(80)=N'QA DB '+CONVERT(nvarchar(36),NEWID());
DECLARE @RoomId int, @Id int, @OtherId int;
DECLARE @Day date=DATEADD(day,1,CAST(DATEADD(hour,8,SYSUTCDATETIME()) AS date));
DECLARE @Student int=(SELECT UserId FROM dbo.Users WHERE UserName=N'student.demo');
DECLARE @Staff int=(SELECT UserId FROM dbo.Users WHERE UserName=N'staff.demo');
DECLARE @Admin int=(SELECT UserId FROM dbo.Users WHERE UserName=N'admin.demo');
IF @Student IS NULL OR @Staff IS NULL OR @Admin IS NULL THROW 52001,'Demo users are required.',1;
DECLARE @Result table (Result int);
DECLARE @Usage table (Facility nvarchar(80), IsActive bit, Total int, Pending int,
    Approved int, Rejected int, Cancelled int, ApprovedMinutes int);
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT @Result EXEC dbo.SaveFacility @Admin,0,@RoomName,N'Meeting room',N'Test block',10;
    SELECT @RoomId=FacilityId FROM dbo.Facilities WHERE Name=@RoomName;
    IF @RoomId IS NULL OR NOT EXISTS (SELECT 1 FROM @Result WHERE Result=1)
        THROW 52002,'Facility insert did not persist in the test transaction.',1;
    DELETE FROM @Result;
    INSERT @Result EXEC dbo.SaveFacility @Admin,@RoomId,@RoomName,N'Meeting room',N'Test block',12;
    IF NOT EXISTS (SELECT 1 FROM dbo.Facilities WHERE FacilityId=@RoomId AND Capacity=12)
        THROW 52003,'Facility update was not retrieved.',1;
    PRINT 'D01 PASS: Facility insert, update and lookup returned the expected record.';

    DELETE FROM @Result;
    INSERT @Result EXEC dbo.CreateBooking @Student,@RoomId,@Day,1,N'Controlled SQL verification';
    SELECT @Id=Result FROM @Result;
    IF NOT EXISTS (SELECT 1 FROM dbo.BookingDetails WHERE BookingId=@Id AND UserId=@Student AND Status=0)
        THROW 52004,'Pending booking was not retrieved.',1;
    PRINT 'D02 PASS: Booking insert produced a pending record with the correct owner.';

    DELETE FROM @Result;
    INSERT @Result EXEC dbo.ReviewBooking @Admin,@Id,1;
    INSERT @Usage EXEC dbo.UsageReport @Day,@Day;
    IF NOT EXISTS (SELECT 1 FROM @Usage WHERE Facility=@RoomName AND Total=1 AND Approved=1 AND ApprovedMinutes=60)
        THROW 52005,'Usage report did not reflect the approved booking.',1;
    PRINT 'D03 PASS: Approval changed status and added 60 approved minutes to the report.';

    DELETE FROM @Result;
    INSERT @Result EXEC dbo.CancelBooking @Staff,@Id;
    IF NOT EXISTS (SELECT 1 FROM @Result WHERE Result=0)
       OR NOT EXISTS (SELECT 1 FROM dbo.Bookings WHERE BookingId=@Id AND Status=1)
        THROW 52006,'Owner scoping did not preserve the approved booking.',1;
    PRINT 'D04 PASS: The unrelated staff account does not own the booking and changed zero rows.';

    DELETE FROM @Result;
    INSERT @Result EXEC dbo.CancelBooking @Student,@Id;
    DELETE FROM @Result;
    INSERT @Result EXEC dbo.CreateBooking @Staff,@RoomId,@Day,1,N'Booking after cancellation';
    SELECT @OtherId=Result FROM @Result;
    DELETE FROM @Result;
    INSERT @Result EXEC dbo.ReviewBooking @Admin,@OtherId,2;
    IF NOT EXISTS (SELECT 1 FROM dbo.Bookings WHERE BookingId=@Id AND Status=3)
       OR NOT EXISTS (SELECT 1 FROM dbo.Bookings WHERE BookingId=@OtherId AND Status=2)
        THROW 52007,'Cancellation and rejection did not produce their expected states.',1;
    PRINT 'D05 PASS: Cancellation released the slot and the subsequent request was rejected.';

    DELETE FROM @Result;
    INSERT @Result EXEC dbo.DeactivateFacility @Admin,@RoomId;
    IF NOT EXISTS (SELECT 1 FROM dbo.Facilities WHERE FacilityId=@RoomId AND IsActive=0)
        THROW 52008,'Facility was not deactivated.',1;
    DELETE FROM dbo.Bookings WHERE BookingId IN (@Id,@OtherId) AND FacilityId=@RoomId;
    IF @@ROWCOUNT<>2 THROW 52009,'The two test booking rows were not removed.',1;
    DELETE FROM dbo.Facilities WHERE FacilityId=@RoomId;
    IF @@ROWCOUNT<>1 THROW 52010,'The test facility was not removed.',1;
    PRINT 'D06 PASS: Deactivation preserved historical rows until the QA cleanup deleted its own fixture.';
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
