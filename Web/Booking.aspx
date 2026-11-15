<%@ Page Language="C#" MasterPageFile="~/Site.master" CodeFile="Booking.aspx.cs" Inherits="FacilityBooking" Title="Facilities | Campus Booking" %>
<asp:Content ContentPlaceHolderID="Main" runat="server">
    <div class="heading"><h1>Find a facility</h1><p>Browse rooms and labs, then request a one-hour booking.</p></div>
    <div class="booking-layout">
        <section aria-labelledby="catalog">
            <h2 id="catalog">Facility directory</h2>
            <div class="filters">
                <div><asp:Label runat="server" AssociatedControlID="Search" Text="Search by name or location" /><asp:TextBox ID="Search" runat="server" MaxLength="80" /></div>
                <div><asp:Label runat="server" AssociatedControlID="Category" Text="Facility type" /><asp:DropDownList ID="Category" runat="server" /></div>
                <asp:Button ID="Apply" runat="server" Text="Search" CssClass="secondary" OnClick="Apply_Click" />
            </div>
            <asp:Label ID="CatalogueEmpty" runat="server" CssClass="empty" Text="No active facilities match your search." Visible="false" />
            <div class="cards">
                <asp:Repeater ID="Facilities" runat="server" OnItemCommand="Facilities_Command">
                    <ItemTemplate>
                        <article class="panel room">
                            <span class="eyebrow"><%#: Eval("Category") %></span>
                            <h3><%#: Eval("Name") %></h3>
                            <p><%#: Eval("Location") %></p>
                            <div class="room-foot">
                                <span><%#: Eval("Capacity") %> seats</span>
                                <asp:Button runat="server" Text="Select" CssClass="secondary small" CommandName="Pick" CommandArgument='<%# Eval("FacilityId") %>' aria-label='<%# "Select " + Eval("Name") %>' />
                            </div>
                        </article>
                    </ItemTemplate>
                </asp:Repeater>
            </div>
        </section>
        <section class="panel booking-panel" aria-labelledby="request-title">
            <h2 id="request-title">Request a booking</h2>
            <p class="note">Choose a date up to 30 days ahead. All times are Malaysia time (UTC+8).</p>
            <asp:Label ID="Feedback" runat="server" Visible="false" aria-live="polite" />
            <div class="stack">
                <div><asp:Label runat="server" AssociatedControlID="Facility" Text="Facility" /><asp:DropDownList ID="Facility" runat="server" /></div>
                <div><asp:Label runat="server" AssociatedControlID="Day" Text="Booking date" /><asp:TextBox ID="Day" runat="server" TextMode="Date" /><asp:Button runat="server" Text="Check availability" CssClass="secondary inline" OnClick="Availability_Click" /></div>
                <div><asp:Label runat="server" AssociatedControlID="Slot" Text="Time slot" /><asp:DropDownList ID="Slot" runat="server" /></div>
                <div><asp:Label runat="server" AssociatedControlID="Purpose" Text="Purpose" /><asp:TextBox ID="Purpose" runat="server" TextMode="MultiLine" Rows="3" maxlength="200" /></div>
                <asp:Button ID="SubmitRequest" runat="server" Text="Submit request" CssClass="primary" OnClick="Submit_Click" />
            </div>
        </section>
    </div>
</asp:Content>
