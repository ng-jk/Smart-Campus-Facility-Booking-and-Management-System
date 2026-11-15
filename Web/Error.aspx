<%@ Page Language="C#" %>
<!doctype html>
<html lang="en">
<head><meta charset="utf-8" /><meta name="viewport" content="width=device-width,initial-scale=1" /><title>Campus Booking</title><link rel="stylesheet" href="<%= ResolveUrl("~/Campus.css") %>" /></head>
<body><main class="wrap"><section class="panel">
<% if (Response.StatusCode == 403) { %>
<h1>Access denied</h1><p>Your account does not have permission to open this page.</p>
<% } else if (Response.StatusCode == 400) { %>
<h1>Form expired</h1><p>Reopen the page before trying again.</p>
<% } else { %>
<h1>Something went wrong</h1><p>Return to the application and try again.</p>
<% } %>
<a class="button primary" href="<%= ResolveUrl("~/Login.aspx") %>">Return to Campus Booking</a>
</section></main></body></html>
