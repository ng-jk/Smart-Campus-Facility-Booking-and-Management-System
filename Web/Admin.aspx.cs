using System;
using System.Data;
using System.Data.SqlClient;
using System.Web.UI.WebControls;
using Campus;

public partial class CampusAdmin : CampusPage
{
    protected override bool Allowed(CampusUser user) { return user.Role == "Administrator"; }

    protected override void OnLoad(EventArgs e)
    {
        base.OnLoad(e);
        string view = Request.QueryString["view"];
        RoomsPanel.Visible = view == "facilities";
        ReportPanel.Visible = view == "report";
        QueuePanel.Visible = !RoomsPanel.Visible && !ReportPanel.Visible;
        HyperLink selected = RoomsPanel.Visible ? RoomsLink : ReportPanel.Visible ? ReportLink : QueueLink;
        selected.Attributes["aria-current"] = "page";
        if (IsPostBack) return;
        try
        {
            if (RoomsPanel.Visible)
            {
                foreach (string category in Rules.Categories) RoomType.Items.Add(category);
                BindRooms();
            }
            else if (ReportPanel.Visible)
            {
                DateTime today = Rules.CampusNow.Date;
                ReportFrom.Text = Rules.IsoDay(today.AddDays(-30));
                ReportThrough.Text = Rules.IsoDay(today.AddDays(30));
                BindReport();
            }
            else
            {
                QueueStatus.Items.Add(new ListItem("All statuses", "-1"));
                for (int i = 0; i < Rules.States.Length; i++) QueueStatus.Items.Add(new ListItem(Rules.States[i], i.ToString()));
                QueueStatus.SelectedValue = "0";
                BindQueue();
            }
        }
        catch (SqlException exception) { SetNotice(Feedback, Db.Explain(exception), true); }
    }

    private void BindQueue()
    {
        string term = Query.Text.Trim();
        if (term.Length > 80) term = term.Substring(0, 80);
        Queue.DataSource = Db.Rows(@"SELECT BookingId,DisplayName,Facility,BookingDate,StartAt,EndAt,Purpose,Status
            FROM dbo.BookingDetails WHERE (@Status=-1 OR Status=@Status)
            AND (@Search='' OR CHARINDEX(@Search,DisplayName)>0 OR CHARINDEX(@Search,Facility)>0)
            ORDER BY BookingDate DESC,StartAt,BookingId DESC", false,
            Db.Arg("Search", SqlDbType.NVarChar, term, 80),
            Db.Arg("Status", SqlDbType.Int, int.Parse(QueueStatus.SelectedValue)));
        Queue.DataBind();
    }

    protected bool Reviewable(int status, DateTime date, TimeSpan start)
    {
        return Rules.CanReview(status, date.Add(start), Rules.CampusNow);
    }

    protected void QueueFilter_Click(object sender, EventArgs e)
    {
        if (!QueuePanel.Visible) return;
        try { BindQueue(); }
        catch (SqlException exception) { SetNotice(Feedback, Db.Explain(exception), true); }
    }

    protected void Queue_Command(object sender, ListViewCommandEventArgs e)
    {
        int id;
        bool approval = e.CommandName == "ApproveRequest";
        if (!QueuePanel.Visible || (!approval && e.CommandName != "RejectRequest") ||
            !int.TryParse(Convert.ToString(e.CommandArgument), out id)) return;
        try
        {
            int changed = Db.Run("dbo.ReviewBooking", Db.Arg("ActorId", SqlDbType.Int, Viewer.Id),
                Db.Arg("BookingId", SqlDbType.Int, id), Db.Arg("Decision", SqlDbType.TinyInt, approval ? 1 : 2));
            SetNotice(Feedback, changed == 1 ? (approval ? "Booking approved." : "Booking rejected. The slot was released.")
                : "This booking is no longer awaiting a decision.", changed != 1);
            BindQueue();
        }
        catch (SqlException exception) { SetNotice(Feedback, Db.Explain(exception), true); }
    }

    private void BindRooms()
    {
        Rooms.DataSource = Db.Rows("SELECT FacilityId,Name,Category,Location,Capacity,IsActive FROM dbo.Facilities ORDER BY IsActive DESC,Name", false);
        Rooms.DataBind();
    }

    protected void Rooms_Command(object sender, ListViewCommandEventArgs e)
    {
        int id;
        if (!RoomsPanel.Visible || !int.TryParse(Convert.ToString(e.CommandArgument), out id)) return;
        try
        {
            if (e.CommandName == "LoadFacility")
            {
                var rows = Db.Rows("SELECT Name,Category,Location,Capacity FROM dbo.Facilities WHERE FacilityId=@Id",
                    false, Db.Arg("Id", SqlDbType.Int, id));
                if (rows.Rows.Count == 0)
                {
                    SetNotice(Feedback, "This facility is unavailable.", true);
                    return;
                }
                DataRow row = rows.Rows[0];
                ViewState["EditingFacility"] = id;
                RoomName.Text = (string)row["Name"];
                RoomType.SelectedValue = (string)row["Category"];
                RoomLocation.Text = (string)row["Location"];
                Capacity.Text = row["Capacity"].ToString();
                EditorTitle.Text = "Edit facility";
                ResetEditor.Visible = true;
            }
            else if (e.CommandName == "CloseFacility")
            {
                int changed = Db.Run("dbo.DeactivateFacility", Db.Arg("ActorId", SqlDbType.Int, Viewer.Id),
                    Db.Arg("FacilityId", SqlDbType.Int, id));
                SetNotice(Feedback, changed == 1 ? "Facility deactivated." : "The facility is already inactive.");
                BindRooms();
            }
        }
        catch (SqlException exception) { SetNotice(Feedback, Db.Explain(exception), true); }
    }

    protected void Save_Click(object sender, EventArgs e)
    {
        if (!RoomsPanel.Visible) return;
        string name = RoomName.Text.Trim(), location = RoomLocation.Text.Trim(), category = RoomType.SelectedValue;
        int seats;
        if (name.Length == 0 || name.Length > 80 || location.Length == 0 || location.Length > 80 ||
            Array.IndexOf(Rules.Categories, category) < 0 || !int.TryParse(Capacity.Text, out seats) || seats < 1 || seats > 500)
        {
            SetNotice(Feedback, "Enter a name and location of up to 80 characters, a facility type and 1 to 500 seats.", true);
            return;
        }
        try
        {
            int changed = Db.Run("dbo.SaveFacility", Db.Arg("ActorId", SqlDbType.Int, Viewer.Id),
                Db.Arg("FacilityId", SqlDbType.Int, Convert.ToInt32(ViewState["EditingFacility"])),
                Db.Arg("Name", SqlDbType.NVarChar, name, 80), Db.Arg("Category", SqlDbType.NVarChar, category, 30),
                Db.Arg("Location", SqlDbType.NVarChar, location, 80), Db.Arg("Capacity", SqlDbType.Int, seats));
            if (changed != 1)
            {
                SetNotice(Feedback, "The facility could not be saved.", true);
                return;
            }
            ViewState.Remove("EditingFacility");
            RoomName.Text = RoomLocation.Text = Capacity.Text = "";
            RoomType.SelectedIndex = 0;
            EditorTitle.Text = "Add facility";
            ResetEditor.Visible = false;
            SetNotice(Feedback, "Facility saved.");
            BindRooms();
        }
        catch (SqlException exception) { SetNotice(Feedback, Db.Explain(exception), true); }
    }

    private void BindReport()
    {
        DateTime from, through;
        Usage.Visible = false;
        if (!Rules.ParseDay(ReportFrom.Text, out from) || !Rules.ParseDay(ReportThrough.Text, out through) ||
            from > through || (through - from).TotalDays > 366)
        {
            SetNotice(Feedback, "Enter an ordered date range spanning at most 367 calendar days.", true);
            return;
        }
        Usage.DataSource = Db.Rows("dbo.UsageReport", true, Db.Arg("From", SqlDbType.Date, from),
            Db.Arg("Through", SqlDbType.Date, through));
        Usage.DataBind();
        Usage.Visible = true;
    }

    protected void Generate_Click(object sender, EventArgs e)
    {
        if (!ReportPanel.Visible) return;
        try { BindReport(); }
        catch (SqlException exception) { SetNotice(Feedback, Db.Explain(exception), true); }
    }
}
