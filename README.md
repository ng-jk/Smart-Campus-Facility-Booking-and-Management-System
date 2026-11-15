# Smart Campus Facility Booking and Management System

PRG3204E Web Application Development, Assessment 3. ASP.NET Web Forms on .NET Framework 4.8, C#, and SQL Server.

## Run on Windows

1. Install .NET Framework 4.8 development tools, Visual Studio with **ASP.NET and web development** or standalone IIS Express, and SQL Server 2017+ (LocalDB works for development).
2. Connect to `(localdb)\MSSQLLocalDB` in SSMS with Windows Authentication. Execute `Database/Setup.sql`, then `Database/DemoData.sql`. With sqlcmd, use `sqlcmd -S "(localdb)\MSSQLLocalDB" -E -b -i Database\Setup.sql` and repeat with `Database\DemoData.sql`.
3. Open the **Web** folder in Visual Studio using **File > Open > Web Site** and start it with IIS Express. Alternatively, from this project folder run:

   ```powershell
   $site = (Resolve-Path '.\Web').Path
   & "$env:ProgramFiles\IIS Express\iisexpress.exe" "/path:$site" /port:41620 /clr:v4.0
   ```

4. Open `http://localhost:41620/Login.aspx`. If you chose another instance, adjust the `Campus` connection string in `Web/Web.config` first. Keep the Web folder as the website root so SQL and evidence files stay outside the served directory.

| Role | Development account |
| --- | --- |
| Student | `student.demo` |
| Staff | `staff.demo` |
| Administrator | `admin.demo` |

The shared password for these synthetic accounts on a private local instance is `CampusDemo-2026!`. Use a different private browser window for each simultaneous role. Dates and slots use Malaysia time (UTC+8). Booking is open for today through 30 days ahead. Each room or lab has ten fixed one-hour slots beginning at 08:00.

For an IIS deployment, use HTTPS, set `requireSSL="true"` on Forms Authentication and `<httpCookies>`, and use a trusted SQL certificate. Run `Database/RuntimeRole.sql` and map the IIS service login to the `CampusWeb` role. Provision individual user accounts with independent salts and hashes using the password derivation in `Rules.Derive`. Load demo accounts only into the development database.

## Verify the application

- Precompile the website using `aspnet_compiler.exe -v / -p <absolute Web path> <unused build output folder>`. The .NET Framework compiler is in the Windows Microsoft.NET Framework or Framework64 folder.
- Run `Database/Verify.sql` as the database owner on a disposable development database after loading the seed scripts. Its transaction rolls back the test fixtures.
- The browser suite uses Node.js and Playwright with Chromium. Install Playwright in your QA environment, start the disposable site, and run `node QA/verify-browser.cjs` from the project root. To target another local URL, set `CAMPUS_BASE_URL`. `CAMPUS_EVIDENCE` sets the screenshot and JSON destination. The browser suite creates synthetic bookings and one synthetic facility in the development database.
- For a shortened expiry test, set `sessionState timeout="1"` in a **temporary QA copy**, start that copy and run `node QA/verify-expiry.cjs`. The normal application timeout is 20 minutes.
- Captured browser and SQL results and application screenshots are in `QA/Evidence`. The report explains the test environment and what each test confirmed.

The editable report contains the name and student ID fields. The supplied specification describes group evidence and uses a group-name PDF convention. For the individual submission, use the naming convention confirmed by the lecturer and supply any required Turnitin and AI reports through the university workflow.
