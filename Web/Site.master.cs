using System;
using System.Web.UI;
using Campus;

public partial class CampusShell : MasterPage
{
    protected override void OnLoad(EventArgs e)
    {
        base.OnLoad(e);
        CampusUser user = CampusUser.Current(Context);
        if (user == null) return;
        SignedIn.Visible = true;
        Account.Text = user.Name + " \u00b7 " + user.Role;
        BookLink.Visible = HistoryLink.Visible = Rules.IsBooker(user.Role);
        AdminLink.Visible = user.Role == "Administrator";
        var page = Request.AppRelativeCurrentExecutionFilePath;
        if (page == "~/Booking.aspx") BookLink.Attributes["aria-current"] = "page";
        if (page == "~/History.aspx") HistoryLink.Attributes["aria-current"] = "page";
        if (page == "~/Admin.aspx") AdminLink.Attributes["aria-current"] = "page";
    }

    protected void SignOut_Click(object sender, EventArgs e)
    {
        CampusUser.End(Context);
        Response.Redirect(ResolveUrl("~/Login.aspx?reason=logout"));
    }
}
