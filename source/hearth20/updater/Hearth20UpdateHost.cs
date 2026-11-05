using System;
using System.IO;
using System.Text;
using System.Diagnostics;
using System.Threading;
using System.Security.Cryptography;
using System.Collections.Generic;
using System.Web.Script.Serialization;
using System.Windows.Forms;
internal static class Hearth20UpdateHost {
    static readonly JavaScriptSerializer Json = new JavaScriptSerializer { MaxJsonLength = 16384 };
    static string PlanPath;
    static Dictionary<string,object> Plan;
    static string Text(string key) { return Convert.ToString(Plan[key]); }
    static string Hash(string path) { using(var file=File.OpenRead(path)) using(var sha=SHA256.Create()) return BitConverter.ToString(sha.ComputeHash(file)).Replace("-", "").ToLowerInvariant(); }
    static string Quote(string value) { return "\"" + value.Replace("\"", "\\\"") + "\""; }
    static void Write(string path,object value) { string temp=path+".writing";File.WriteAllText(temp,Json.Serialize(value),new UTF8Encoding(false));if(File.Exists(path))File.Replace(temp,path,null);else File.Move(temp,path); }
    static Process Launch(string target,string arguments) { return Process.Start(new ProcessStartInfo(target,arguments) { UseShellExecute=false,WorkingDirectory=Path.GetDirectoryName(target) }); }
    [STAThread] static int Main(string[] args) {
        if(args.Length!=1)return 2;
        string target="",backup="",prepared="";bool replaced=false;
        try {
            PlanPath=Path.GetFullPath(args[0]);
            if(new FileInfo(PlanPath).Length>16384)throw new Exception("Invalid update plan.");
            Plan=Json.Deserialize<Dictionary<string,object>>(File.ReadAllText(PlanPath));
            if(Text("edition")!="hearth20-seated")throw new Exception("Wrong application edition.");
            target=Path.GetFullPath(Text("target"));string staged=Path.GetFullPath(Text("staged"));string expected=Text("sha256");
            if(!target.EndsWith(".exe",StringComparison.OrdinalIgnoreCase)||target==staged||expected.Length!=64||!File.Exists(target)||!File.Exists(staged))throw new Exception("The portable or staged update is missing.");
            var parent=Process.GetProcessById(Convert.ToInt32(Plan["pid"]));
            if(!String.Equals(Path.GetFullPath(parent.MainModule.FileName),target,StringComparison.OrdinalIgnoreCase))throw new Exception("The running portable did not match the update plan.");
            if(Hash(staged)!=expected)throw new Exception("The staged update failed its checksum.");
            using(var file=File.OpenRead(staged))if(file.ReadByte()!='M'||file.ReadByte()!='Z')throw new Exception("The update is not a Windows executable.");
            backup=target+".previous";prepared=target+".installing";
            // Prepare and verify beside the destination before asking the app to quit.
            File.Copy(staged,prepared,true);if(Hash(prepared)!=expected)throw new Exception("The prepared update failed its checksum.");
            string oldHash=Hash(target);
            Write(PlanPath+".ready",new { ready=true });
            if(!parent.WaitForExit(120000))throw new Exception("Hearth20 did not close. The existing portable is unchanged.");
            string marker=PlanPath+".confirmed";if(File.Exists(marker))File.Delete(marker);
            File.Replace(prepared,target,backup);replaced=true;
            var child=Launch(target,"-- --hearth20-update-confirm "+Quote(PlanPath));bool confirmed=false;
            var deadline=DateTime.UtcNow.AddSeconds(120);
            while(DateTime.UtcNow<deadline) {
                if(File.Exists(marker)) {
                    try {
                        var record=Json.Deserialize<Dictionary<string,object>>(File.ReadAllText(marker));
                        if(Convert.ToString(record["version"])==Text("version")&&Convert.ToInt32(record["pid"])==child.Id){confirmed=true;break;}
                    } catch { /* The app may still be finishing the small confirmation file. */ }
                }
                if(child.HasExited)break;Thread.Sleep(150);
            }
            if(!confirmed) {
                if(!child.HasExited){child.Kill();child.WaitForExit(10000);}
                string failed=target+".failed";File.Replace(backup,target,failed);replaced=false;
                int restoredPid=Launch(target,"").Id;Write(PlanPath+".result",new { ok=false,rolled_back=true,restored_pid=restoredPid,message="The new version did not finish starting. Your previous portable was restored." });return 1;
            }
            Write(PlanPath+".result",new { ok=true,version=Text("version"),previous_sha256=oldHash,backup=backup });File.Delete(staged);return 0;
        } catch(Exception error) {
            try {
                if(replaced&&File.Exists(backup)){File.Copy(backup,target,true);Launch(target,"");}
                if(prepared!=""&&File.Exists(prepared))File.Delete(prepared);
                if(PlanPath!=null)Write(PlanPath+".result",new { ok=false,message=error.Message });
            }catch { }
            return 1;
        }
    }
}
