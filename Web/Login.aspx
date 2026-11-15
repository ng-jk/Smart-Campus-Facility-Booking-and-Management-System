<%@ Page Language="C#" MasterPageFile="~/Site.master" CodeFile="Login.aspx.cs" Inherits="CampusLogin" Title="Sign in | Campus Booking" %>
<asp:Content ContentPlaceHolderID="Main" runat="server">
    <div class="login-layout">
        <section class="intro">
            <h1>Book a campus facility</h1>
            <p>Find a discussion room, computer lab, meeting room or multimedia room. Sign in to make a request and follow its status.</p>
        </section>
        <section class="panel login-panel" aria-labelledby="sign-in-heading">
            <h2 id="sign-in-heading">Sign in</h2>
            <asp:Label ID="Feedback" runat="server" Visible="false" aria-live="polite" />
            <asp:Panel runat="server" DefaultButton="Enter" CssClass="stack">
                <div><asp:Label runat="server" AssociatedControlID="UserName" Text="Username" /><asp:TextBox ID="UserName" runat="server" MaxLength="50" autocomplete="username" required="required" /></div>
                <div><asp:Label runat="server" AssociatedControlID="Password" Text="Password" /><asp:TextBox ID="Password" runat="server" TextMode="Password" MaxLength="128" autocomplete="current-password" required="required" /></div>
                <asp:Button ID="Enter" runat="server" Text="Sign in" CssClass="primary" OnClick="Enter_Click" />
            </asp:Panel>
        </section>
    </div>
</asp:Content>
