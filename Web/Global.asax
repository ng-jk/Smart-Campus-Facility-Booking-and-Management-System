<%@ Application Language="C#" %>
<script runat="server">
    void Application_Error(object sender, EventArgs e)
    {
        var failure = Server.GetLastError();
        var httpError = failure as System.Web.HttpException;
        int code = httpError == null ? 500 : httpError.GetHttpCode();
        if (code != 400 && code != 403) return;
        Server.ClearError();
        Response.Clear();
        Response.StatusCode = code;
        Response.TrySkipIisCustomErrors = true;
        Server.Transfer("~/Error.aspx?code=" + code, false);
    }
</script>
