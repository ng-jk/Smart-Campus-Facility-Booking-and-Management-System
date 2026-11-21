-- Run as a database owner. For deployment, map the IIS service login to a database
-- user and add that user to CampusWeb after executing this script.
USE CampusBookings;
GO
IF DATABASE_PRINCIPAL_ID(N'CampusWeb') IS NULL CREATE ROLE CampusWeb;
GRANT SELECT ON dbo.Roles TO CampusWeb;
GRANT SELECT ON dbo.Users TO CampusWeb;
GRANT SELECT ON dbo.Facilities TO CampusWeb;
GRANT SELECT ON dbo.TimeSlots TO CampusWeb;
GRANT SELECT ON dbo.Bookings (FacilityId,BookingDate,SlotId,Status) TO CampusWeb;
GRANT SELECT ON dbo.BookingDetails TO CampusWeb;
GRANT EXECUTE ON dbo.CreateBooking TO CampusWeb;
GRANT EXECUTE ON dbo.CancelBooking TO CampusWeb;
GRANT EXECUTE ON dbo.ReviewBooking TO CampusWeb;
GRANT EXECUTE ON dbo.SaveFacility TO CampusWeb;
GRANT EXECUTE ON dbo.DeactivateFacility TO CampusWeb;
GRANT EXECUTE ON dbo.UsageReport TO CampusWeb;
GO
