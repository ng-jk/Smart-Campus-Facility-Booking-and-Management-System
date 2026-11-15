using System;
using System.Data.SqlClient;
using Campus;

public partial class CampusLogin : CampusPage
{
    protected override bool NeedsLogin { get { return false; } }

    protected override void OnLoad(EventArgs e)
    {
        base.OnLoad(e);
        if (Viewer != null) RedirectHome(Viewer);
        if (IsPostBack) return;
        if (Request.QueryString["reason"] == "signin")
            SetNotice(Feedback, "Sign in to continue. Your previous session may have expired.");
        else if (Request.QueryString["reason"] == "logout")
            SetNotice(Feedback, "You have signed out.");
    }

    protected void Enter_Click(object sender, EventArgs e)
    {
        string name = UserName.Text.Trim();
        string password = Password.Text;
        if (name.Length == 0 || name.Length > 50 || password.Length == 0 || password.Length > 128)
        {
            SetNotice(Feedback, "Enter your username and password.", true);
            return;
        }
        try
        {
            CampusUser user = CampusUser.SignIn(name, password);
            if (user == null)
            {
                SetNotice(Feedback, "The username or password is incorrect.", true);
                return;
            }
            user.Start(Context);
            RedirectHome(user);
        }
        catch (SqlException exception)
        {
            SetNotice(Feedback, Db.Explain(exception), true);
        }
    }

    private void RedirectHome(CampusUser user)
    {
        Response.Redirect(ResolveUrl(user.Role == "Administrator" ? "~/Admin.aspx" : "~/Booking.aspx"));
    }
}
