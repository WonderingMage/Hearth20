using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using System.Web.Script.Serialization;
using System.Windows.Forms;
using Microsoft.Web.WebView2.Core;


// Local child-window host only. No DOM, sheet, cookie, credential or script bridge.
internal sealed class BeyondBrowserHost : Form {
    [DllImport("user32.dll")] static extern IntPtr SetParent(IntPtr child, IntPtr parent);
    [DllImport("user32.dll")] static extern int GetWindowLong(IntPtr window, int index);
    [DllImport("user32.dll")] static extern int SetWindowLong(IntPtr window, int index, int value);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr window, out uint pid);
    [DllImport("user32.dll")] static extern bool IsWindow(IntPtr window);
    [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr window, IntPtr after, int x, int y, int w, int h, uint flags);
    [DllImport("user32.dll")] static extern bool SetProcessDpiAwarenessContext(IntPtr context);
    readonly IntPtr owner;
    readonly int ownerPid;
    readonly string nonce, folder;
    readonly JavaScriptSerializer json = new JavaScriptSerializer { MaxJsonLength = 16384, RecursionLimit = 8 };
    readonly Timer poll = new Timer { Interval = 100 };
    CoreWebView2 web;
    CoreWebView2Controller controller;
    long lastCommand;
    long sequence = -1;
    string currentUrl = "", state = "Starting embedded browser…";
    bool ready, suspended, frozen, working, requestedVisible;
    string suspendError = "";
    int failures;
    static string Str(Dictionary<string, object> d, string key, string fallback = "") { return d.ContainsKey(key) ? Convert.ToString(d[key]) : fallback; }
    static int Number(Dictionary<string, object> d, string key) { return d.ContainsKey(key) ? Convert.ToInt32(d[key]) : 0; }
    static bool Https(string value) { Uri u; return value.Length <= 2048 && Uri.TryCreate(value, UriKind.Absolute, out u) && u.Scheme == "https" && String.IsNullOrEmpty(u.UserInfo); }
    [STAThread] static void Main(string[] args) {
        if (args.Length != 4) return;
        long handle; int pid;
        if (!Int64.TryParse(args[0], out handle) || !Int32.TryParse(args[1], out pid) || args[2].Length != 48) return;
        try {
            SetProcessDpiAwarenessContext(new IntPtr(-4));
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new BeyondBrowserHost(new IntPtr(handle), pid, args[2], Path.GetFullPath(args[3])));
        } catch { /* Reported through status when a host window could be created. */ }
    }
    BeyondBrowserHost(IntPtr parent, int pid, string secret, string path) {
        uint actual; GetWindowThreadProcessId(parent, out actual);
        if (!IsWindow(parent) || actual != pid) throw new ArgumentException("Invalid owner");
        owner = parent; ownerPid = pid; nonce = secret; folder = path;
        Directory.CreateDirectory(folder);
        FormBorderStyle = FormBorderStyle.None; ShowInTaskbar = false; BackColor = Color.FromArgb(24, 18, 12);
        StartPosition = FormStartPosition.Manual; Bounds = new Rectangle(-32000, -32000, 1, 1);
        Load += async delegate {
            SetParent(Handle, owner);
            SetWindowLong(Handle, -16, (GetWindowLong(Handle, -16) & ~unchecked((int)0x80000000)) | 0x40000000 | 0x04000000 | 0x02000000);
            Hide(); poll.Tick += async delegate { await TickHost(); }; poll.Start();
            await InitializeBrowser();
        };
        FormClosed += delegate { poll.Stop(); if (controller != null) controller.Close(); };
    }
    async Task InitializeBrowser() {
        try {
            var env = await CoreWebView2Environment.CreateAsync(null, Path.Combine(Directory.GetParent(folder).FullName, "website-profile"));
            controller = await env.CreateCoreWebView2ControllerAsync(Handle);
            controller.Bounds = ClientRectangle; controller.IsVisible = false; controller.DefaultBackgroundColor = BackColor;
            web = controller.CoreWebView2;
            SizeChanged += delegate { if (controller != null) controller.Bounds = ClientRectangle; };
            web.Settings.IsWebMessageEnabled = false;
            web.Settings.AreHostObjectsAllowed = false;
            web.Settings.AreDevToolsEnabled = false;
            web.Settings.IsStatusBarEnabled = false;
            web.NavigationStarting += delegate(object sender, CoreWebView2NavigationStartingEventArgs e) { if (!Https(e.Uri)) e.Cancel = true; };
            web.NewWindowRequested += delegate(object sender, CoreWebView2NewWindowRequestedEventArgs e) { e.Handled = true; if (Https(e.Uri)) web.Navigate(e.Uri); };
            web.NavigationCompleted += delegate(object sender, CoreWebView2NavigationCompletedEventArgs e) { state = e.IsSuccess ? "D&D Beyond · sign in on the website" : "The page could not load. You can open it in your browser."; WriteStatus(); };
            web.SourceChanged += delegate { Uri parsed; currentUrl = Uri.TryCreate(web.Source, UriKind.Absolute, out parsed) ? parsed.GetLeftPart(UriPartial.Path) : ""; WriteStatus(); };
            ready = true; state = "Ready · choose My characters or search D&D Beyond";
        } catch { state = "Embedded browser unavailable. Open D&D Beyond in your browser, or install Microsoft Edge WebView2 Runtime."; }
        WriteStatus();
    }
    async Task TickHost() {
        if (working) return;
        working = true;
        try {
            if (!IsWindow(owner) || Process.GetProcessById(ownerPid).HasExited) { Close(); return; }
            string path = Path.Combine(folder, "control.json");
            if (!File.Exists(path)) { if (++failures > 150) Close(); return; }
            if ((DateTime.UtcNow - File.GetLastWriteTimeUtc(path)).TotalSeconds > 10) { Close(); return; }
            var d = json.Deserialize<Dictionary<string, object>>(File.ReadAllText(path));
            if (Str(d, "nonce") != nonce) return;
            long next = Convert.ToInt64(d["sequence"]);
            if (next == sequence) return;
            sequence = next; failures = 0;
            if (Str(d, "action") == "exit") { Close(); return; }
            requestedVisible = d.ContainsKey("visible") && Convert.ToBoolean(d["visible"]);
            int width = Math.Max(1, Math.Min(16000, Number(d, "width"))), height = Math.Max(1, Math.Min(16000, Number(d, "height")));
            // Repeated native bounds/visibility writes can wake a suspended renderer.
            // A hidden sheet needs no layout updates; apply the latest rectangle on return.
            if (requestedVisible) {
                var desired = new Rectangle(Number(d, "x"), Number(d, "y"), width, height);
                if (Bounds != desired) SetWindowPos(Handle, IntPtr.Zero, desired.X, desired.Y, desired.Width, desired.Height, 0x0010 | 0x0004);
                if (controller != null && controller.Bounds != ClientRectangle) controller.Bounds = ClientRectangle;
            }
            long commandId = d.ContainsKey("command_id") ? Convert.ToInt64(d["command_id"]) : 0;
            if (ready && commandId > lastCommand) {
                if (suspended) await ResumePage();
                string action = Str(d, "action"), url = Str(d, "url");
                if (action == "navigate" && Https(url)) { await ResumePage(); web.Navigate(url); }
                else if (action == "back" && web.CanGoBack) web.GoBack();
                else if (action == "forward" && web.CanGoForward) web.GoForward();
                else if (action == "reload") web.Reload();
                else if (action == "capture" && d.ContainsKey("qa") && Convert.ToBoolean(d["qa"])) {
                    using (var stream = File.Create(Path.Combine(folder, "guest-preview.png"))) await web.CapturePreviewAsync(CoreWebView2CapturePreviewImageFormat.Png, stream);
                }
                else if (action == "capture_sheet") {
                    string final = Path.Combine(folder, "sheet-preview.png"), temp = final + ".pending";
                    using (var stream = new MemoryStream()) {
                        await web.CapturePreviewAsync(CoreWebView2CapturePreviewImageFormat.Png, stream);
                        File.WriteAllBytes(temp, stream.ToArray());
                    }
                    if (File.Exists(final)) File.Replace(temp, final, null); else File.Move(temp, final);
                }
                lastCommand = commandId;
            }
            if (requestedVisible) {
                if (suspended && ready) await ResumePage();
                if (controller != null && !controller.IsVisible) controller.IsVisible = true;
                if (!Visible) Show();
            } else {
                if (controller != null && controller.IsVisible) controller.IsVisible = false;
                if (Visible) Hide();
                if (ready && !frozen) {
                    // Freeze timers/animation explicitly, then let Edge reclaim renderer memory.
                    // Sleeping-tab eligibility alone can change while a live site finishes loading.
                    try { await web.CallDevToolsProtocolMethodAsync("Page.setWebLifecycleState", "{\"state\":\"frozen\"}"); frozen = true; suspendError = ""; }
                    catch (Exception e) { suspendError = e.GetType().Name; }
                    if (!web.IsSuspended) { try { await web.TrySuspendAsync(); } catch (Exception e) { suspendError = e.GetType().Name; } }
                }
                suspended = ready && (frozen || web.IsSuspended);
            }
            WriteStatus();
        } catch { /* A partially replaced control file is retried on the next tick. */ }
        finally { WriteStatus(); working = false; }
    }
    async Task ResumePage() {
        if (!ready) return;
        if (web.IsSuspended) web.Resume();
        if (frozen) { await web.CallDevToolsProtocolMethodAsync("Page.setWebLifecycleState", "{\"state\":\"active\"}"); frozen = false; }
        suspended = false;
    }
    void WriteStatus() {
        try {
            string path = Path.Combine(folder, "status.json"), temp = path + ".writing";
            File.WriteAllText(temp, json.Serialize(new { nonce = nonce, ready = ready, message = state, url = currentUrl, visible = Visible, suspended = suspended, frozen = frozen, suspend_error = suspendError, last_command_id = lastCommand }));
            if (File.Exists(path)) File.Replace(temp, path, null); else File.Move(temp, path);
        } catch { /* Keep the previous complete status; retry next tick. */ }
    }
}
