extends SceneTree
var checks=0
var errors=[]
func _initialize() -> void:call_deferred("run")
func expect(value: bool,note: String) -> void:
	checks+=1
	if not value:errors.append(note);push_error(note)
func run() -> void:
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://hearth20/browser/bundle.json"))
	expect(manifest is Dictionary and manifest.get("files") is Dictionary,"embedded browser has a readable bundle manifest")
	if manifest is Dictionary and manifest.get("files") is Dictionary:
		for name_value in ["BeyondBrowserHost.exe","Microsoft.Web.WebView2.Core.dll","Microsoft.Web.WebView2.WinForms.dll","WebView2Loader.dll","SDK-LICENSE.txt","SDK-NOTICE.txt"]:
			var bytes=FileAccess.get_file_as_bytes("res://hearth20/browser/"+name_value)
			expect(not bytes.is_empty() and Hearth20Contracts.sha256(bytes)==manifest.files.get(name_value,""),"packaged browser component matches manifest: "+name_value)
		var binary=FileAccess.get_file_as_bytes("res://hearth20/browser/BeyondBrowserHost.exe")
		expect(binary.size()>2048 and binary.slice(0,2).get_string_from_ascii()=="MZ","embedded keyboard fix is a Windows executable")
		expect(str(manifest.get("version","")).ends_with(str(manifest.files.get("BeyondBrowserHost.exe","")).left(12)),"browser cache key changes with the helper binary")
	var sheet=Hearth20BeyondSheet.new()
	expect(sheet.valid_url("https://www.dndbeyond.com/my-characters") and not sheet.valid_url("http://www.dndbeyond.com/my-characters"),"sheet navigation retains secure website boundaries")
	sheet.free()
	print("Browser bundle: %d checks, %d failures"%[checks,errors.size()]);quit(0 if errors.is_empty() else 1)
