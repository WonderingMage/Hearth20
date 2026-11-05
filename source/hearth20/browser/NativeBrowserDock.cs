using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Web.Script.Serialization;
using System.Windows.Forms;

// Dock an actual browser window. Never open a browser profile, cookie/password
// database, debugging port, or page scripting connection. Windows owns input.
internal sealed class NativeBrowserDock : Form {
    delegate bool EnumWindow(IntPtr window, IntPtr data);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumWindow callback, IntPtr data);
    [DllImport("user32.dll")] static extern bool IsWindow(IntPtr window);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr window);
    [DllImport("user32.dll")] static extern IntPtr GetParent(IntPtr window);
    [DllImport("user32.dll", SetLastError=true)] static extern IntPtr SetParent(IntPtr child, IntPtr parent);
    [DllImport("user32.dll")] static extern int GetWindowLong(IntPtr window, int index);
    [DllImport("user32.dll")] static extern int SetWindowLong(IntPtr window, int index, int value);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetWindowText(IntPtr window, StringBuilder text, int maximum);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr window, out uint pid);
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr window, out RECT rect);
    [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr window, IntPtr after, int x, int y, int width, int height, uint flags);
    [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr window, int action);
    [DllImport("user32.dll")] static extern bool GetWindowPlacement(IntPtr window, ref PLACEMENT placement);
    [DllImport("user32.dll")] static extern bool SetWindowPlacement(IntPtr window, ref PLACEMENT placement);
    [DllImport("user32.dll")] static extern IntPtr SetFocus(IntPtr window);
    [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
    [DllImport("kernel32.dll", EntryPoint="SetLastError")] static extern void ClearError(uint value);
    [DllImport("user32.dll")] static extern bool AttachThreadInput(uint first, uint second, bool attach);
    [DllImport("shlwapi.dll", CharSet=CharSet.Unicode)] static extern uint AssocQueryString(uint flags, uint name, string association, string extra, StringBuilder output, ref uint length);
    [DllImport("user32.dll")] static extern IntPtr SendMessageTimeout(IntPtr window, uint message, IntPtr wparam, IntPtr lparam, uint flags, uint timeout, out IntPtr result);
    [StructLayout(LayoutKind.Sequential)] struct RECT { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] struct POINT { public int X,Y; }
    [StructLayout(LayoutKind.Sequential)] struct PLACEMENT { public int Length,Flags,Show; public POINT Minimum,Maximum; public RECT Normal; }
    sealed class BrowserWindow {
        public IntPtr Handle; public uint Pid; public string Executable, Title;
        public override string ToString() { return Path.GetFileNameWithoutExtension(Executable) + "  ·  " + Title; }
    }
    static readonly HashSet<string> Browsers = new HashSet<string>(StringComparer.OrdinalIgnoreCase) { "chrome.exe", "msedge.exe", "firefox.exe", "brave.exe", "opera.exe", "vivaldi.exe", "zen.exe", "waterfox.exe", "floorp.exe", "librewolf.exe", "browser.exe" };
    readonly IntPtr owner;
    readonly uint ownerPid, ownerThread;
    readonly string folder, nonce;
    readonly Timer timer = new Timer { Interval=100 };
    readonly JavaScriptSerializer json = new JavaScriptSerializer { MaxJsonLength=16384, RecursionLimit=8 };
    readonly ComboBox windows = new ComboBox { DropDownStyle=ComboBoxStyle.DropDownList, Width=550 };
    readonly Label hint = new Label { AutoSize=true, MaximumSize=new Size(650,0), ForeColor=Color.Bisque };
    IntPtr browser;
    uint browserPid, browserThread;
    IntPtr previousParent;
    int previousStyle, previousExtendedStyle;
    RECT previousBounds;
    PLACEMENT previousPlacement;
    Rectangle layoutBounds;
    IntPtr layoutTarget;
    bool helperInput, browserInput, requestedVisible, closing;
    long sequence=-1, lastCommand;
    string requested="https://www.dndbeyond.com/my-characters", message="Open D&D Beyond in your Windows browser, or choose its existing window.";
    string launchExecutable="";
    HashSet<IntPtr> windowsBeforeLaunch;
    DateTime launchDeadline;
    public NativeBrowserDock(IntPtr parent, int pid, string secret, string channel) {
        uint actual; ownerThread=GetWindowThreadProcessId(parent,out actual);
        if (!IsWindow(parent) || actual!=(uint)pid) throw new ArgumentException("Invalid game window");
        owner=parent;ownerPid=(uint)pid;nonce=secret;folder=channel;
        FormBorderStyle=FormBorderStyle.None;ShowInTaskbar=false;BackColor=Color.FromArgb(24,18,12);ForeColor=Color.Goldenrod;
        StartPosition=FormStartPosition.Manual;Bounds=new Rectangle(-32000,-32000,1,1);
        var layout=new FlowLayoutPanel { Dock=DockStyle.Fill, FlowDirection=FlowDirection.TopDown, WrapContents=false, Padding=new Padding(28), AutoScroll=true };
        Controls.Add(layout);
        layout.Controls.Add(new Label { Text="YOUR BROWSER · YOUR CHARACTER", Font=new Font("Georgia",18,FontStyle.Bold), AutoSize=true, ForeColor=Color.Goldenrod });
        layout.Controls.Add(new Label { Text="Use a dedicated D&D Beyond window. Your browser keeps its usual sign-in and saved passwords.", AutoSize=true, MaximumSize=new Size(650,0), ForeColor=Color.Bisque, Margin=new Padding(3,16,3,18) });
        AddButton(layout,"Open my Windows browser",OpenRequested);
        layout.Controls.Add(windows);AddButton(layout,"Refresh browser windows",RefreshWindows);
        AddButton(layout,"Place selected window on my sheet",delegate { var choice=windows.SelectedItem as BrowserWindow;if(choice!=null) DockWindow(choice.Handle,choice.Pid); });
        layout.Controls.Add(hint);
        Load+=delegate {
            helperInput=ownerThread!=GetCurrentThreadId() && AttachThreadInput(GetCurrentThreadId(),ownerThread,true);
            SetWindowLong(Handle,-16,(GetWindowLong(Handle,-16)&~unchecked((int)0x80000000))|0x40000000|0x04000000|0x02000000);
            SetParent(Handle,owner);Hide();RefreshWindows();timer.Tick+=delegate { TickDock(); };timer.Start();
        };
        FormClosing+=delegate {
            closing=true;timer.Stop();
            if(helperInput) {AttachThreadInput(GetCurrentThreadId(),ownerThread,false);helperInput=false;}
            RestoreBrowser();
        };
    }
    void AddButton(Control parent,string text,Action action) {
        var button=new Button { Text=text, AutoSize=true, Height=42, FlatStyle=FlatStyle.Flat, BackColor=Color.FromArgb(42,32,18), ForeColor=Color.Gold, Padding=new Padding(12,6,12,6) };
        button.Click+=delegate { action(); };parent.Controls.Add(button);
    }
    static bool AllowedUrl(string text) {
        Uri url;return text.Length<=2048 && Uri.TryCreate(text,UriKind.Absolute,out url) && url.Scheme=="https" && String.IsNullOrEmpty(url.UserInfo) && (url.Host.Equals("dndbeyond.com",StringComparison.OrdinalIgnoreCase)||url.Host.Equals("www.dndbeyond.com",StringComparison.OrdinalIgnoreCase));
    }
    static string DefaultBrowser() {
        uint length=0;AssocQueryString(0,2,"https","open",null,ref length);
        if(length==0||length>32768)return "";
        var result=new StringBuilder((int)length);
        return AssocQueryString(0,2,"https","open",result,ref length)==0?result.ToString():"";
    }
    static bool OperaLauncher(string executable) {
        if(!Path.GetFileName(executable).Equals("launcher.exe",StringComparison.OrdinalIgnoreCase))return false;
        try {return (FileVersionInfo.GetVersionInfo(executable).ProductName??"").IndexOf("Opera",StringComparison.OrdinalIgnoreCase)>=0;} catch {return false;}
    }
    List<BrowserWindow> AvailableWindows() {
        var result=new List<BrowserWindow>();
        EnumWindows(delegate(IntPtr window,IntPtr unused) {
            if(window==owner||window==Handle||!IsWindowVisible(window)||GetParent(window)!=IntPtr.Zero)return true;
            uint pid;GetWindowThreadProcessId(window,out pid);
            try {
                string exe=Process.GetProcessById((int)pid).MainModule.FileName;
                if(!Browsers.Contains(Path.GetFileName(exe)))return true;
                var title=new StringBuilder(1024);GetWindowText(window,title,title.Capacity);
                if(title.Length>0)result.Add(new BrowserWindow { Handle=window,Pid=pid,Executable=exe,Title=title.ToString() });
            } catch { }
            return true;
        },IntPtr.Zero);return result;
    }
    void RefreshWindows() {
        windows.Items.Clear();foreach(var candidate in AvailableWindows()) windows.Items.Add(candidate);
        if(windows.Items.Count>0)windows.SelectedIndex=0;
        hint.Text=message;
    }
    void OpenRequested() {
        if(!AllowedUrl(requested))return;
        RestoreBrowser();launchExecutable=DefaultBrowser();windowsBeforeLaunch=new HashSet<IntPtr>();
        foreach(var window in AvailableWindows())windowsBeforeLaunch.Add(window.Handle);
        try {
            string name=Path.GetFileName(launchExecutable);
            string url=new Uri(requested).AbsoluteUri;
            if(!String.IsNullOrEmpty(launchExecutable)&&File.Exists(launchExecutable)&&(Browsers.Contains(name)||OperaLauncher(launchExecutable))) {
                string arguments=(name.Equals("firefox.exe",StringComparison.OrdinalIgnoreCase)||name.Equals("zen.exe",StringComparison.OrdinalIgnoreCase)||name.Equals("waterfox.exe",StringComparison.OrdinalIgnoreCase)||name.Equals("floorp.exe",StringComparison.OrdinalIgnoreCase)||name.Equals("librewolf.exe",StringComparison.OrdinalIgnoreCase)?"-new-window ":"--new-window ")+"\""+url+"\"";
                Process.Start(new ProcessStartInfo(launchExecutable,arguments) { UseShellExecute=true });
                launchDeadline=DateTime.UtcNow.AddSeconds(12);
                message="Opening your browser. Its new D&D Beyond window will be placed on the sheet.";
            } else {
                Process.Start(new ProcessStartInfo(url) { UseShellExecute=true });windowsBeforeLaunch=null;
                message="Choose your D&D Beyond browser window above, then place it on the sheet.";
            }
        } catch { windowsBeforeLaunch=null;message="Your browser could not open. Open D&D Beyond yourself and choose its window here."; }
        hint.Text=message;WriteStatus();
    }
    internal bool DockWindow(IntPtr target,uint expectedPid) {
        if(target==owner||target==Handle||!IsWindow(target)||GetParent(target)!=IntPtr.Zero)return false;
        uint pid;uint thread=GetWindowThreadProcessId(target,out pid);
        if(pid!=expectedPid)return false;
        try { if(!Browsers.Contains(Path.GetFileName(Process.GetProcessById((int)pid).MainModule.FileName)))return false; } catch {return false;}
        RestoreBrowser();previousParent=GetParent(target);previousStyle=GetWindowLong(target,-16);previousExtendedStyle=GetWindowLong(target,-20);GetWindowRect(target,out previousBounds);
        previousPlacement=new PLACEMENT { Length=Marshal.SizeOf(typeof(PLACEMENT)) };GetWindowPlacement(target,ref previousPlacement);
        browser=target;browserPid=pid;browserThread=thread;
        browserInput=thread!=ownerThread && AttachThreadInput(thread,ownerThread,true);
        ShowWindow(target,9);
        SetWindowLong(target,-16,(previousStyle&~unchecked((int)0xa1000000))|0x40000000);
        ClearError(0);SetParent(target,owner);int error=Marshal.GetLastWin32Error();
        if(GetParent(target)!=owner) {RestoreBrowser();message="This browser cannot be placed inside Hearth20 (Windows "+error+"). It remains available as a normal window.";hint.Text=message;WriteStatus();return false;}
        windowsBeforeLaunch=null;Hide();message="Your Windows browser is on the sheet. Sign-in and passwords stay with that browser.";WriteStatus();return true;
    }
    internal void RestoreBrowser() {
        if(browser==IntPtr.Zero)return;
        // Disconnect explicit input sharing before the restored browser is
        // activated and before this helper thread exits. The browser may own
        // many unrelated windows on that same thread.
        if(browserInput) {AttachThreadInput(browserThread,ownerThread,false);browserInput=false;}
        uint pid;GetWindowThreadProcessId(browser,out pid);
        if(IsWindow(browser)&&pid==browserPid) {
            ShowWindow(browser,0);SetParent(browser,previousParent);SetWindowLong(browser,-16,previousStyle);SetWindowLong(browser,-20,previousExtendedStyle);
            SetWindowPos(browser,IntPtr.Zero,previousBounds.Left,previousBounds.Top,Math.Max(100,previousBounds.Right-previousBounds.Left),Math.Max(100,previousBounds.Bottom-previousBounds.Top),0x0010|0x0004|0x0020);
            SetWindowPlacement(browser,ref previousPlacement);ShowWindow(browser,previousPlacement.Show);
        }
        browser=IntPtr.Zero;browserInput=false;layoutTarget=IntPtr.Zero;
    }
    void BrowserCommand(int command) { if(browser!=IntPtr.Zero) {IntPtr ignored;SendMessageTimeout(browser,0x0319,browser,new IntPtr(command<<16),2,1000,out ignored);} }
    void TickDock() {
        if(closing)return;
        try {
            if(!IsWindow(owner)||Process.GetProcessById((int)ownerPid).HasExited){Close();return;}
            string path=Path.Combine(folder,"control.json");
            if(!File.Exists(path))return;
            if((DateTime.UtcNow-File.GetLastWriteTimeUtc(path)).TotalSeconds>10){Close();return;}
            var data=json.Deserialize<Dictionary<string,object>>(File.ReadAllText(path));
            if(!data.ContainsKey("nonce")||Convert.ToString(data["nonce"])!=nonce)return;
            long next=Convert.ToInt64(data["sequence"]);if(next==sequence)return;sequence=next;
            string action=data.ContainsKey("action")?Convert.ToString(data["action"]):"";
            if(action=="exit"){Close();return;}
            requestedVisible=data.ContainsKey("visible")&&Convert.ToBoolean(data["visible"]);
            long command=data.ContainsKey("command_id")?Convert.ToInt64(data["command_id"]):0;
            if(command>lastCommand) {
                if(action=="navigate"&&data.ContainsKey("url")&&AllowedUrl(Convert.ToString(data["url"]))) {requested=Convert.ToString(data["url"]);if(browser!=IntPtr.Zero)OpenRequested();}
                if(action=="choose_browser") {RestoreBrowser();RefreshWindows();}
                if(action=="release_browser") {RestoreBrowser();message="Your browser is back on the desktop. Select its window when you want it on the sheet again.";RefreshWindows();}
                if(action=="open_browser")OpenRequested();
                if(action=="back")BrowserCommand(1);if(action=="forward")BrowserCommand(2);if(action=="reload")BrowserCommand(3);
                lastCommand=command;
            }
            if(windowsBeforeLaunch!=null) {
                bool opera=Path.GetFileName(launchExecutable).Equals("opera.exe",StringComparison.OrdinalIgnoreCase)||OperaLauncher(launchExecutable);
                var added=AvailableWindows().FindAll(w=>!windowsBeforeLaunch.Contains(w.Handle)&&(String.Equals(w.Executable,launchExecutable,StringComparison.OrdinalIgnoreCase)||(opera&&Path.GetFileName(w.Executable).Equals("opera.exe",StringComparison.OrdinalIgnoreCase))));
                if(added.Count==1)DockWindow(added[0].Handle,added[0].Pid);
                else if(DateTime.UtcNow>launchDeadline) {windowsBeforeLaunch=null;message="Select the D&D Beyond window to place on your sheet.";RefreshWindows();}
            }
            if(browser!=IntPtr.Zero&&!IsWindow(browser)) {browser=IntPtr.Zero;if(browserInput)AttachThreadInput(browserThread,ownerThread,false);browserInput=false;message="Browser window closed. Open it again or choose another window.";RefreshWindows();}
            IntPtr target=browser!=IntPtr.Zero?browser:Handle;
            if(requestedVisible) {
                int x=Convert.ToInt32(data["x"]),y=Convert.ToInt32(data["y"]),width=Math.Max(100,Math.Min(16000,Convert.ToInt32(data["width"]))),height=Math.Max(100,Math.Min(16000,Convert.ToInt32(data["height"])));
                var bounds=new Rectangle(x,y,width,height);
                if(layoutTarget!=target||layoutBounds!=bounds) {SetWindowPos(target,IntPtr.Zero,x,y,width,height,0x0010|0x0004|0x0020);layoutTarget=target;layoutBounds=bounds;}
                if(target==Handle) {if(!Visible)Show();}
                else {if(Visible)Hide();if(!IsWindowVisible(target))ShowWindow(target,4);}
            } else {if(target==Handle) {if(Visible)Hide();} else ShowWindow(target,0);}
            hint.Text=message;WriteStatus();
        } catch { }
    }
    void WriteStatus() {
        try {
            string path=Path.Combine(folder,"status.json"),temp=path+".writing";
            File.WriteAllText(temp,json.Serialize(new {nonce=nonce,ready=true,message=message,mode="native",docked=browser!=IntPtr.Zero,visible=requestedVisible,last_command_id=lastCommand}));
            if(File.Exists(path))File.Replace(temp,path,null);else File.Move(temp,path);
        } catch { }
    }
}
