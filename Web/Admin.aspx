<%@ Page Language="C#" MasterPageFile="~/Site.master" CodeFile="Admin.aspx.cs" Inherits="CampusAdmin" Title="Administration | Campus Booking" %>
<asp:Content ContentPlaceHolderID="Main" runat="server">
    <div class="heading"><h1>Administration</h1><p>Manage facilities, review booking requests and check usage.</p></div>
    <nav class="tabs" aria-label="Administration">
        <asp:HyperLink ID="QueueLink" runat="server" NavigateUrl="~/Admin.aspx">Booking queue</asp:HyperLink>
        <asp:HyperLink ID="RoomsLink" runat="server" NavigateUrl="~/Admin.aspx?view=facilities">Facilities</asp:HyperLink>
        <asp:HyperLink ID="ReportLink" runat="server" NavigateUrl="~/Admin.aspx?view=report">Usage report</asp:HyperLink>
    </nav>
    <asp:Label ID="Feedback" runat="server" Visible="false" aria-live="polite" />
    <asp:Panel ID="QueuePanel" runat="server" CssClass="panel">
        <h2>Booking queue</h2>
        <div class="filters">
            <div><asp:Label runat="server" AssociatedControlID="Query" Text="Search by requester or facility" /><asp:TextBox ID="Query" runat="server" MaxLength="80" /></div>
            <div><asp:Label runat="server" AssociatedControlID="QueueStatus" Text="Status" /><asp:DropDownList ID="QueueStatus" runat="server" /></div>
            <asp:Button runat="server" Text="Apply filters" CssClass="secondary" OnClick="QueueFilter_Click" />
        </div>
        <asp:ListView ID="Queue" runat="server" OnItemCommand="Queue_Command">
            <EmptyDataTemplate><p class="empty">No requests match the current filter.</p></EmptyDataTemplate>
            <LayoutTemplate><div class="scroll"><table><caption class="sr-only">Booking requests</caption><thead><tr><th scope="col">Request</th><th scope="col">Facility and purpose</th><th scope="col">Campus time</th><th scope="col">Status</th><th scope="col">Decision</th></tr></thead><tbody><tr id="itemPlaceholder" runat="server"></tr></tbody></table></div></LayoutTemplate>
            <ItemTemplate><tr>
                <td>#<%#: Eval("BookingId") %><br /><%#: Eval("DisplayName") %></td>
                <td><strong><%#: Eval("Facility") %></strong><br /><span class="muted"><%#: Eval("Purpose") %></span></td>
                <td><%#: Eval("BookingDate", "{0:dd MMM yyyy}") %><br /><%#: Campus.Rules.Slot(Eval("StartAt"), Eval("EndAt")) %></td>
                <td><span class='<%# "status " + Campus.Rules.States[(byte)Eval("Status")].ToLowerInvariant() %>'><%#: Campus.Rules.States[(byte)Eval("Status")] %></span></td>
                <td><asp:PlaceHolder runat="server" Visible='<%# Reviewable((byte)Eval("Status"), (DateTime)Eval("BookingDate"), (TimeSpan)Eval("StartAt")) %>'>
                    <asp:Button runat="server" Text="Approve" CssClass="primary small" CommandName="ApproveRequest" CommandArgument='<%# Eval("BookingId") %>' />
                    <asp:Button runat="server" Text="Reject" CssClass="secondary small" CommandName="RejectRequest" CommandArgument='<%# Eval("BookingId") %>' />
                </asp:PlaceHolder></td>
            </tr></ItemTemplate>
        </asp:ListView>
    </asp:Panel>
    <asp:Panel ID="RoomsPanel" runat="server" CssClass="booking-layout">
        <section class="panel">
            <h2>Facility inventory</h2>
            <asp:ListView ID="Rooms" runat="server" OnItemCommand="Rooms_Command">
                <EmptyDataTemplate><p class="empty">There are no facilities.</p></EmptyDataTemplate>
                <LayoutTemplate><div class="scroll"><table><caption class="sr-only">Facility inventory</caption><thead><tr><th scope="col">Facility</th><th scope="col">Seats</th><th scope="col">State</th><th scope="col">Actions</th></tr></thead><tbody><tr id="itemPlaceholder" runat="server"></tr></tbody></table></div></LayoutTemplate>
                <ItemTemplate><tr>
                    <td><strong><%#: Eval("Name") %></strong><br /><span class="muted"><%#: Eval("Category") %> &middot; <%#: Eval("Location") %></span></td>
                    <td><%#: Eval("Capacity") %></td>
                    <td><%# (bool)Eval("IsActive") ? "Active" : "Inactive" %></td>
                    <td><asp:Button runat="server" Text="Edit" CssClass="secondary small" CommandName="LoadFacility" CommandArgument='<%# Eval("FacilityId") %>' />
                    <asp:Button runat="server" Text="Deactivate" CssClass="secondary small" CommandName="CloseFacility" CommandArgument='<%# Eval("FacilityId") %>' Visible='<%# Eval("IsActive") %>' /></td>
                </tr></ItemTemplate>
            </asp:ListView>
        </section>
        <section class="panel stack">
            <h2><asp:Literal ID="EditorTitle" runat="server" Text="Add facility" /></h2>
            <div><asp:Label runat="server" AssociatedControlID="RoomName" Text="Facility name" /><asp:TextBox ID="RoomName" runat="server" MaxLength="80" /></div>
            <div><asp:Label runat="server" AssociatedControlID="RoomType" Text="Facility type" /><asp:DropDownList ID="RoomType" runat="server" /></div>
            <div><asp:Label runat="server" AssociatedControlID="RoomLocation" Text="Location" /><asp:TextBox ID="RoomLocation" runat="server" MaxLength="80" /></div>
            <div><asp:Label runat="server" AssociatedControlID="Capacity" Text="Seats" /><asp:TextBox ID="Capacity" runat="server" TextMode="Number" min="1" max="500" /></div>
            <div class="actions"><asp:Button runat="server" Text="Save facility" CssClass="primary" OnClick="Save_Click" />
                <asp:HyperLink ID="ResetEditor" runat="server" NavigateUrl="~/Admin.aspx?view=facilities" Visible="false" CssClass="button secondary">Discard changes</asp:HyperLink></div>
        </section>
    </asp:Panel>
    <asp:Panel ID="ReportPanel" runat="server" CssClass="panel">
        <h2>Facility usage</h2>
        <p class="note">Approved time shows reserved hours, including future bookings in the selected period.</p>
        <div class="filters">
            <div><asp:Label runat="server" AssociatedControlID="ReportFrom" Text="From date" /><asp:TextBox ID="ReportFrom" runat="server" TextMode="Date" /></div>
            <div><asp:Label runat="server" AssociatedControlID="ReportThrough" Text="Through date" /><asp:TextBox ID="ReportThrough" runat="server" TextMode="Date" /></div>
            <asp:Button runat="server" Text="Generate report" CssClass="primary" OnClick="Generate_Click" />
        </div>
        <asp:ListView ID="Usage" runat="server">
            <EmptyDataTemplate><p class="empty">No facilities are available to report on.</p></EmptyDataTemplate>
            <LayoutTemplate><div class="scroll"><table><caption class="sr-only">Facility usage by status</caption><thead><tr><th scope="col">Facility</th><th scope="col">Requests</th><th scope="col">Pending</th><th scope="col">Approved</th><th scope="col">Rejected</th><th scope="col">Cancelled</th><th scope="col">Approved hours</th></tr></thead><tbody><tr id="itemPlaceholder" runat="server"></tr></tbody></table></div></LayoutTemplate>
            <ItemTemplate><tr>
                <td><strong><%#: Eval("Facility") %></strong><br /><span class="muted"><%# (bool)Eval("IsActive") ? "Active" : "Inactive" %></span></td>
                <td><%#: Eval("Total") %></td><td><%#: Eval("Pending") %></td><td><%#: Eval("Approved") %></td>
                <td><%#: Eval("Rejected") %></td><td><%#: Eval("Cancelled") %></td><td><%#: (int)Eval("ApprovedMinutes") / 60 %></td>
            </tr></ItemTemplate>
        </asp:ListView>
    </asp:Panel>
</asp:Content>
