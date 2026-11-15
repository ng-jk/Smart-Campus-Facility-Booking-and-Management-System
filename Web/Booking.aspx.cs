using System;
using System.Data;
using System.Data.SqlClient;
using System.Web.UI.WebControls;
using Campus;

public partial class FacilityBooking : CampusPage
{
    protected override bool Allowed(CampusUser user) { return Rules.IsBooker(user.Role); }

    protected override void OnLoad(EventArgs e)
    {
        base.OnLoad(e);
        if (IsPostBack) return;
        Category.Items.Add(new ListItem("All types", ""));
        foreach (string category in Rules.Categories) Category.Items.Add(category);
        DateTime today = Rules.CampusNow.Date;
        Day.Text = Rules.IsoDay(today.AddDays(1));
        Day.Attributes["min"] = Rules.IsoDay(today);
        Day.Attributes["max"] = Rules.IsoDay(today.AddDays(30));
        try
        {
            BindCatalogue();
            Facility.DataSource = Db.Rows("SELECT FacilityId,Name FROM dbo.Facilities WHERE IsActive=1 ORDER BY Name", false);
            Facility.DataValueField = "FacilityId";
            Facility.DataTextField = "Name";
            Facility.DataBind();
            BindSlots();
        }
        catch (SqlException exception) { SetNotice(Feedback, Db.Explain(exception), true); }
    }

    private void BindCatalogue()
    {
        string search = Search.Text.Trim();
        if (search.Length > 80) search = search.Substring(0, 80);
        DataTable rows = Db.Rows(@"SELECT FacilityId,Name,Category,Location,Capacity FROM dbo.Facilities
            WHERE IsActive=1 AND (@Category='' OR Category=@Category)
            AND (@Search='' OR CHARINDEX(@Search,Name)>0 OR CHARINDEX(@Search,Location)>0)
            ORDER BY Name", false, Db.Arg("Category", SqlDbType.NVarChar, Category.SelectedValue, 30),
            Db.Arg("Search", SqlDbType.NVarChar, search, 80));
        Facilities.DataSource = rows;
        Facilities.DataBind();
        CatalogueEmpty.Visible = rows.Rows.Count == 0;
    }

    private bool Selection(out int facility, out DateTime day)
    {
        bool found = int.TryParse(Facility.SelectedValue, out facility);
        DateTime today = Rules.CampusNow.Date;
        return Rules.ParseDay(Day.Text, out day) && found && day >= today && day <= today.AddDays(30);
    }

    private void BindSlots()
    {
        Slot.Items.Clear();
        Slot.Items.Add(new ListItem("Choose an available slot", ""));
        int facility;
        DateTime day;
        if (!Selection(out facility, out day))
        {
            SubmitRequest.Enabled = false;
            SetNotice(Feedback, "Choose an available facility and a date in the next 30 days.", true);
            return;
        }
        DateTime now = Rules.CampusNow;
        DataTable rows = Db.Rows(@"SELECT t.SlotId,t.StartAt,t.EndAt FROM dbo.TimeSlots t
            WHERE (@Day>@Today OR t.StartAt>@Now)
              AND EXISTS (SELECT 1 FROM dbo.Facilities WHERE FacilityId=@Facility AND IsActive=1)
              AND NOT EXISTS (SELECT 1 FROM dbo.Bookings b
                  WHERE b.FacilityId=@Facility AND b.BookingDate=@Day AND b.SlotId=t.SlotId AND b.Status IN (0,1))
            ORDER BY t.StartAt", false, Db.Arg("Facility", SqlDbType.Int, facility),
            Db.Arg("Day", SqlDbType.Date, day), Db.Arg("Today", SqlDbType.Date, now.Date),
            Db.Arg("Now", SqlDbType.Time, now.TimeOfDay));
        foreach (DataRow row in rows.Rows)
            Slot.Items.Add(new ListItem(Rules.Slot(row["StartAt"], row["EndAt"]), row["SlotId"].ToString()));
        ViewState["SlotFacility"] = facility;
        ViewState["SlotDate"] = Rules.IsoDay(day);
        SubmitRequest.Enabled = rows.Rows.Count > 0;
        if (rows.Rows.Count == 0) SetNotice(Feedback, "No slots are available for this selection.");
    }

    protected void Apply_Click(object sender, EventArgs e)
    {
        try { BindCatalogue(); }
        catch (SqlException exception) { SetNotice(Feedback, Db.Explain(exception), true); }
    }

    protected void Facilities_Command(object sender, RepeaterCommandEventArgs e)
    {
        if (e.CommandName != "Pick") return;
        var option = Facility.Items.FindByValue(Convert.ToString(e.CommandArgument));
        if (option == null)
        {
            SetNotice(Feedback, "Reload the facility directory to refresh its selections.", true);
            return;
        }
        Facility.SelectedValue = option.Value;
        Availability_Click(sender, e);
    }

    protected void Availability_Click(object sender, EventArgs e)
    {
        try
        {
            Feedback.Visible = false;
            BindSlots();
        }
        catch (SqlException exception) { SetNotice(Feedback, Db.Explain(exception), true); }
    }

    protected void Submit_Click(object sender, EventArgs e)
    {
        int facility;
        DateTime day;
        if (!Selection(out facility, out day))
        {
            SetNotice(Feedback, "Choose an active facility and an eligible date.", true);
            return;
        }
        string purpose = Purpose.Text.Trim();
        byte slot;
        if (Convert.ToInt32(ViewState["SlotFacility"]) != facility || (string)ViewState["SlotDate"] != Rules.IsoDay(day))
        {
            Availability_Click(sender, e);
            if (Slot.Items.Count > 1) SetNotice(Feedback, "Select a time slot for the new facility or date.");
            return;
        }
        if (!byte.TryParse(Slot.SelectedValue, out slot) || purpose.Length == 0 || purpose.Length > 200)
        {
            SetNotice(Feedback, "Choose a time slot and enter a purpose of 1 to 200 characters.", true);
            return;
        }
        try
        {
            int id = Db.Run("dbo.CreateBooking", Db.Arg("UserId", SqlDbType.Int, Viewer.Id),
                Db.Arg("FacilityId", SqlDbType.Int, facility), Db.Arg("BookingDate", SqlDbType.Date, day),
                Db.Arg("SlotId", SqlDbType.TinyInt, slot), Db.Arg("Purpose", SqlDbType.NVarChar, purpose, 200));
            Session["BookingNotice"] = "Booking #" + id + " was submitted for review.";
            Response.Redirect(ResolveUrl("~/History.aspx"));
        }
        catch (SqlException exception)
        {
            if (exception.Number == 51004) Availability_Click(sender, e);
            SetNotice(Feedback, Db.Explain(exception), true);
        }
    }
}
