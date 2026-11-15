-- Optional development-only users. Shared password for this disposable fixture: CampusDemo-2026!
-- Keep these rows out of any deployed university instance.
USE CampusBookings;
GO
INSERT dbo.Users(UserName,DisplayName,RoleName,PasswordSalt,PasswordHash)
SELECT d.UserName,d.DisplayName,d.RoleName,d.Salt,d.Hash
FROM (VALUES
  (N'student.demo',N'Aisha Student','Student',0xd0f8bdbfa3179db91d118a592e395166,0x05a5581d3c2efc590d34fbdf8742ad52efe54491073acba79fad7a8ac5558246),
  (N'staff.demo',N'Ravi Staff','Staff',0x099acdaa52759f10273e1019787572b0,0x2a1d87f6d8f8b595a42539ad0747542c648888764a46f75abe6f102be899a568),
  (N'admin.demo',N'Campus Administrator','Administrator',0x2b839ec6136439aff9db683a34079918,0x428898d1a31ddaef5e439f46c1b57cdb4b42cbceb8973e9768db6103881c01cd)
) d(UserName,DisplayName,RoleName,Salt,Hash)
WHERE NOT EXISTS (SELECT 1 FROM dbo.Users u WHERE u.UserName=d.UserName);
GO
