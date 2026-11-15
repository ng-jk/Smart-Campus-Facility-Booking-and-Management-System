using System;
using System.Data;
using System.Data.SqlClient;
using System.Web.UI.WebControls;
using Campus;

public partial class BookingHistory : CampusPage
{
    protected override bool Allowed(CampusUser user) { return Rules.IsBooker(user.Role); }

    protected override void OnLoad(EventArgs e)
    {
        base.OnLoad(e);
        if (IsPostBack) return;
        Status.Items.Add(new ListItem("All statuses", "-1"));
        for (int i = 0; i < Rules.States.Length; i++) Status.Items.Add(new ListItem(Rules.States[i], i.ToString()));
        string message = Session["BookingNotice"] as string;
        Session.Remove("BookingNotice");
        if (message != null) SetNotice(Feedback, message);
        BindHistory();
    }

    protected bool Eligible(int owner, int status, DateTime day, TimeSpan start)
    {
        return Rules.CanCancel(Viewer.Id, owner, status, day.Add(start), Rules.CampusNow);
    }

    private void BindHistory()
    {
        try
        {
            History.DataSource = Db.Rows(@"SELECT BookingId,UserId,Facility,BookingDate,StartAt,EndAt,Purpose,Status
              FROM dbo.BookingDetails WHERE UserId=@UserId AND (@Status=-1 OR Status=@Status)
              ORDER BY BookingDate DESC,StartAt DESC,BookingId DESC", false, Db.Arg("UserId", SqlDbType.Int, Viewer.Id),
              Db.Arg("Status", SqlDbType.Int, int.Parse(Status.SelectedValue)));
            History.DataBind();
        }
        catch (SqlException exception) { SetNotice(Feedback, Db.Explain(exception), true); }
    }

    protected void Filter_Click(object sender, EventArgs e)
    {
        Feedback.Visible = false;
        BindHistory();
    }

    protected void History_Command(object sender, ListViewCommandEventArgs e)
    {
        int id;
        if (e.CommandName != "Release" || !int.TryParse(Convert.ToString(e.CommandArgument), out id)) return;
        try
        {
            int changed = Db.Run("dbo.CancelBooking", Db.Arg("BookingId", SqlDbType.Int, id),
                Db.Arg("UserId", SqlDbType.Int, Viewer.Id));
            SetNotice(Feedback, changed == 1 ? "The booking was cancelled and the slot released."
                : "This booking is unavailable or no longer eligible for cancellation.", changed != 1);
            BindHistory();
        }
        catch (SqlException exception) { SetNotice(Feedback, Db.Explain(exception), true); }
    }
}
