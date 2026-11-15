using System;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Globalization;
using System.Security.Cryptography;
using System.Web;
using System.Web.Security;
using System.Web.UI;

namespace Campus
{
    public static class Db
    {
        public static SqlParameter Arg(string name, SqlDbType type, object value, int size = 0)
        {
            var parameter = new SqlParameter("@" + name, type);
            if (size > 0) parameter.Size = size;
            parameter.Value = value ?? DBNull.Value;
            return parameter;
        }

        private static SqlCommand Command(SqlConnection connection, string sql, bool procedure, SqlParameter[] args)
        {
            var command = new SqlCommand(sql, connection);
            command.CommandType = procedure ? CommandType.StoredProcedure : CommandType.Text;
            command.Parameters.AddRange(args);
            return command;
        }

        public static DataTable Rows(string sql, bool procedure, params SqlParameter[] args)
        {
            using (var connection = new SqlConnection(ConfigurationManager.ConnectionStrings["Campus"].ConnectionString))
            using (var command = Command(connection, sql, procedure, args))
            using (var adapter = new SqlDataAdapter(command))
            {
                var table = new DataTable();
                adapter.Fill(table);
                return table;
            }
        }

        public static int Run(string procedure, params SqlParameter[] args)
        {
            using (var connection = new SqlConnection(ConfigurationManager.ConnectionStrings["Campus"].ConnectionString))
            using (var command = Command(connection, procedure, true, args))
            {
                connection.Open();
                return Convert.ToInt32(command.ExecuteScalar());
            }
        }

        public static string Explain(SqlException exception)
        {
            switch (exception.Number)
            {
                case 51001: return "Enter an eligible date, time and purpose.";
                case 51002: return "Only students and staff can request bookings.";
                case 51003: return "The facility is no longer available.";
                case 51004: return "That slot is already held. Choose a different slot.";
                case 51005: return "This action is restricted to administrators.";
                case 51006: return "Resolve future bookings before deactivating this facility.";
                case 2601:
                case 2627: return "A facility with this name already exists.";
                default:
                    System.Diagnostics.Trace.TraceWarning("Campus SQL operation failed ({0}).", exception.Number);
                    return "The database operation could not be completed. Please try again.";
            }
        }
    }

    public static class Rules
    {
        public const int PasswordIterations = 210000;
        public static readonly string[] Categories = { "Discussion room", "Computer lab", "Meeting room", "Multimedia room" };
        public static readonly string[] States = { "Pending", "Approved", "Rejected", "Cancelled" };

        public static DateTime CampusNow { get { return DateTime.UtcNow.AddHours(8); } }

        public static bool IsBooker(string role) { return role == "Student" || role == "Staff"; }

        public static bool CanCancel(int viewer, int owner, int state, DateTime start, DateTime now)
        {
            return viewer == owner && (state == 0 || state == 1) && start > now;
        }

        public static bool CanReview(int state, DateTime start, DateTime now)
        {
            return state == 0 && start > now;
        }

        public static bool ParseDay(string value, out DateTime day)
        {
            return DateTime.TryParseExact(value, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out day);
        }

        public static string IsoDay(DateTime day) { return day.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture); }

        public static string Slot(object start, object end)
        {
            return ((TimeSpan)start).ToString(@"hh\:mm") + "\u2013" + ((TimeSpan)end).ToString(@"hh\:mm");
        }

        public static byte[] Derive(string password, byte[] salt)
        {
            using (var pbkdf = new Rfc2898DeriveBytes(password, salt, PasswordIterations, HashAlgorithmName.SHA256))
                return pbkdf.GetBytes(32);
        }

        public static string Token()
        {
            var bytes = new byte[32];
            using (var random = RandomNumberGenerator.Create()) random.GetBytes(bytes);
            return Convert.ToBase64String(bytes);
        }

        public static bool Equal(byte[] a, byte[] b)
        {
            if (a == null || b == null || a.Length != b.Length) return false;
            int difference = 0;
            for (var i = 0; i < a.Length; i++) difference |= a[i] ^ b[i];
            return difference == 0;
        }
    }

    public sealed class CampusUser
    {
        public int Id { get; private set; }
        public string Name { get; private set; }
        public string Role { get; private set; }
        public string Binding { get; private set; }

        private CampusUser(DataRow row)
        {
            Id = (int)row["UserId"];
            Name = (string)row["DisplayName"];
            Role = (string)row["RoleName"];
            Binding = Rules.Token();
        }

        public static CampusUser SignIn(string name, string password)
        {
            DataTable rows = Db.Rows(@"SELECT UserId,DisplayName,RoleName,PasswordSalt,PasswordHash
                FROM dbo.Users WHERE UserName=@Name", false, Db.Arg("Name", SqlDbType.NVarChar, name, 50));
            DataRow row = rows.Rows.Count == 0 ? null : rows.Rows[0];
            var salt = row == null ? new byte[16] : (byte[])row["PasswordSalt"];
            var expected = row == null ? new byte[32] : (byte[])row["PasswordHash"];
            bool matches = Rules.Equal(Rules.Derive(password, salt), expected);
            return row != null && matches ? new CampusUser(row) : null;
        }

        public static CampusUser Current(HttpContext context)
        {
            var user = context.Session["CampusUser"] as CampusUser;
            var identity = context.User == null ? null : context.User.Identity as FormsIdentity;
            return user != null && identity != null && identity.IsAuthenticated
                && !identity.Ticket.Expired && identity.Ticket.UserData == user.Binding
                && identity.Name == user.Id.ToString(CultureInfo.InvariantCulture) ? user : null;
        }

        public void Start(HttpContext context)
        {
            context.Session.Clear();
            context.Session["CampusUser"] = this;
            context.Session["CampusCsrf"] = Rules.Token();
            var now = DateTime.Now;
            var ticket = new FormsAuthenticationTicket(2, Id.ToString(CultureInfo.InvariantCulture),
                now, now.AddHours(8), false, Binding, FormsAuthentication.FormsCookiePath);
            var cookie = new HttpCookie(FormsAuthentication.FormsCookieName, FormsAuthentication.Encrypt(ticket));
            cookie.Path = FormsAuthentication.FormsCookiePath;
            cookie.HttpOnly = true;
            cookie.Secure = context.Request.IsSecureConnection || FormsAuthentication.RequireSSL;
            cookie.SameSite = SameSiteMode.Lax;
            context.Response.Cookies.Set(cookie);
        }

        public static void End(HttpContext context)
        {
            FormsAuthentication.SignOut();
            context.Session.Clear();
            context.Session.Abandon();
            context.Response.Cookies.Set(new HttpCookie("ASP.NET_SessionId", "")
            {
                Expires = DateTime.UtcNow.AddDays(-1),
                Path = "/",
                HttpOnly = true,
                Secure = context.Request.IsSecureConnection
            });
        }
    }

    public abstract class CampusPage : Page
    {
        protected CampusUser Viewer { get { return CampusUser.Current(Context); } }
        protected virtual bool NeedsLogin { get { return true; } }
        protected virtual bool Allowed(CampusUser user) { return true; }

        protected override void OnInit(EventArgs e)
        {
            Response.Cache.SetCacheability(HttpCacheability.NoCache);
            Response.Cache.SetNoStore();

            CampusUser viewer = Viewer;
            if (NeedsLogin && viewer == null)
            {
                CampusUser.End(Context);
                Response.Redirect(ResolveUrl("~/Login.aspx?reason=signin"));
                return;
            }
            if (viewer != null && !Allowed(viewer))
                throw new HttpException(403, "This page is restricted to another role.");

            string token = Session["CampusCsrf"] as string;
            if (token == null)
            {
                token = Rules.Token();
                Session["CampusCsrf"] = token;
            }
            ViewStateUserKey = token;
            if (Request.HttpMethod == "POST" && Request.Form["campusToken"] != token)
                throw new HttpException(400, "This form has expired. Reopen the page and try again.");
            ClientScript.RegisterHiddenField("campusToken", token);
            base.OnInit(e);
        }

        protected void SetNotice(System.Web.UI.WebControls.Label label, string message, bool error = false)
        {
            label.Text = HttpUtility.HtmlEncode(message);
            label.Visible = true;
            label.CssClass = error ? "notice error" : "notice";
        }
    }
}
