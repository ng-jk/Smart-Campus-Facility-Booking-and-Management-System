<%@ Page Language="C#" MasterPageFile="~/Site.master" CodeFile="History.aspx.cs" Inherits="BookingHistory" Title="My bookings | Campus Booking" %>
<asp:Content ContentPlaceHolderID="Main" runat="server">
    <div class="heading"><h1>My bookings</h1><p>Review your requests and cancel a pending or approved booking before its start.</p></div>
    <section class="panel">
        <asp:Label ID="Feedback" runat="server" Visible="false" aria-live="polite" />
        <div class="filters">
            <div><asp:Label runat="server" AssociatedControlID="Status" Text="Booking status" /><asp:DropDownList ID="Status" runat="server" /></div>
            <asp:Button runat="server" Text="Apply filter" CssClass="secondary" OnClick="Filter_Click" />
        </div>
        <asp:ListView ID="History" runat="server" OnItemCommand="History_Command">
            <EmptyDataTemplate><p class="empty">No bookings match the current filter.</p></EmptyDataTemplate>
            <LayoutTemplate><div class="scroll"><table><caption class="sr-only">Your bookings</caption><thead><tr><th scope="col">Booking</th><th scope="col">Facility and purpose</th><th scope="col">Campus time</th><th scope="col">Status</th><th scope="col">Action</th></tr></thead><tbody><tr id="itemPlaceholder" runat="server"></tr></tbody></table></div></LayoutTemplate>
            <ItemTemplate><tr>
                <td>#<%#: Eval("BookingId") %></td>
                <td><strong><%#: Eval("Facility") %></strong><br /><span class="muted"><%#: Eval("Purpose") %></span></td>
                <td><%#: Eval("BookingDate", "{0:dd MMM yyyy}") %><br /><%#: Campus.Rules.Slot(Eval("StartAt"), Eval("EndAt")) %></td>
                <td><span class='<%# "status " + Campus.Rules.States[(byte)Eval("Status")].ToLowerInvariant() %>'><%#: Campus.Rules.States[(byte)Eval("Status")] %></span></td>
                <td><asp:Button runat="server" Text="Cancel booking" CssClass="secondary small" CommandName="Release" CommandArgument='<%# Eval("BookingId") %>' Visible='<%# Eligible((int)Eval("UserId"), (byte)Eval("Status"), (DateTime)Eval("BookingDate"), (TimeSpan)Eval("StartAt")) %>' /></td>
            </tr></ItemTemplate>
        </asp:ListView>
    </section>
</asp:Content>
