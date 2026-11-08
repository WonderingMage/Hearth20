extends Window
class_name Hearth20PartyGuide
## Vector illustrations stay sharp at every window size without extra loading.
const HOST=[
	["Open your table", "Choose Host a new game, or open a campaign and choose Host a game. Hearth20 connects Steam, fills your name and opens your private table automatically."],
	["Invite your friends", "The next screen shows your Steam friends. Select someone and press Invite selected friend. Keep Hearth20 open on both PCs. Your friend accepts and joins automatically."],
	["Bring the party in", "Players choose a name and PNG portrait. Open Tokens to place their pawns from your inventory and grant movement. Save the campaign to keep the party."]
]
const JOIN=[
	["Prepare your seat", "Open Steam and Hearth20 on your own PC. Choose Join a table. Each PC uses its own signed-in Steam account."],
	["Accept the invitation", "Accept the DM’s Steam invitation while Hearth20 is open. The game fills in the lobby and joins for you. A copied invitation also works with Paste & join after the DM has invited you."],
	["Create your adventurer", "Choose your character name and PNG. Your pawn goes to the DM’s inventory. Once placed and assigned, you can move it. Click the papyrus for your private D&D Beyond sheet."]
]
const DIRECT=[
	["The DM opens a table", "In Gather your party, choose Direct IP and Host by Direct IP. The game generates the invite code and lists local addresses and the UDP port."],
	["Share connection details", "Use Copy local connection details. For the same Wi-Fi, use the DM’s local IPv4 address. For another window on this PC, use 127.0.0.1."],
	["Players connect", "Enter the DM’s address, port and invite code, then Join by Direct IP. Internet Direct IP requires UDP forwarding on the DM’s router. Steam handles the usual internet connection setup."]
]
var role_tabs: TabContainer
static func open(owner: Node,role="host") -> Hearth20PartyGuide:
	var existing=owner.get_tree().root.get_node_or_null("PartyFieldGuide")
	if existing!=null:
		existing.role_tabs.current_tab=1 if role=="join" else 2 if role=="direct" else 0
		existing.popup_centered();return existing
	var guide=Hearth20PartyGuide.new();owner.get_tree().root.add_child(guide);guide.setup(role);return guide
func setup(role: String) -> void:
	name="PartyFieldGuide";title="Hearth20 · Your party’s field guide";theme=Hearth20Design.theme();size=Vector2i(880,640);min_size=Vector2i(740,560);transient=true;close_requested.connect(queue_free)
	var panel=PanelContainer.new();panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);panel.add_theme_stylebox_override("panel",Hearth20Design.panel(Hearth20Regal.swatch(Hearth20Regal.BG),3,24,Hearth20Regal.swatch(Hearth20Regal.GOLD)));add_child(panel)
	var column=VBoxContainer.new();column.add_theme_constant_override("separation",14);panel.add_child(column)
	var heading=Label.new();heading.text="THE ART OF GATHERING";heading.add_theme_font_override("font",Hearth20Design.font(true));heading.add_theme_font_size_override("font_size",28);heading.add_theme_color_override("font_color",Hearth20Regal.swatch(Hearth20Regal.GOLD));column.add_child(heading)
	var sub=Label.new();sub.text="A field guide for the keeper of the table and every adventurer.";sub.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(sub)
	role_tabs=TabContainer.new();role_tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(role_tabs)
	for entry in [["Host with Steam","host",HOST],["Join with Steam","join",JOIN],["Direct IP","direct",DIRECT]]:
		var scroll=ScrollContainer.new();scroll.name=entry[0];scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;role_tabs.add_child(scroll)
		var body=VBoxContainer.new();body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",14);scroll.add_child(body)
		var diagram=RouteDiagram.new();diagram.role=entry[1];body.add_child(diagram)
		var cards=HBoxContainer.new();cards.add_theme_constant_override("separation",12);body.add_child(cards)
		for index in 3:
			var card=PanelContainer.new();card.size_flags_horizontal=Control.SIZE_EXPAND_FILL;card.add_theme_stylebox_override("panel",Hearth20Design.panel(Hearth20Regal.swatch(Hearth20Regal.SURFACE),8,14,Hearth20Regal.swatch(Hearth20Regal.GOLD).darkened(.45)));cards.add_child(card)
			var copy=VBoxContainer.new();copy.add_theme_constant_override("separation",10);card.add_child(copy)
			var seal=Label.new();seal.text=["I","II","III"][index];seal.add_theme_font_override("font",Hearth20Design.font(true));seal.add_theme_font_size_override("font_size",25);seal.add_theme_color_override("font_color",Hearth20Regal.swatch(Hearth20Regal.GOLD));copy.add_child(seal)
			var label=Label.new();label.text=entry[2][index][0];label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.add_theme_font_size_override("font_size",19);copy.add_child(label)
			var detail=Label.new();detail.text=entry[2][index][1];detail.add_theme_font_size_override("font_size",15);detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;copy.add_child(detail)
	role_tabs.current_tab=1 if role=="join" else 2 if role=="direct" else 0
	var footer=HBoxContainer.new();column.add_child(footer)
	var note=Label.new();note.text="Steam test mode uses Spacewar · Each PC needs a different account";note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;note.size_flags_horizontal=Control.SIZE_EXPAND_FILL;note.add_theme_font_size_override("font_size",12);footer.add_child(note)
	var close=Button.new();close.text="Back to the adventure";close.custom_minimum_size.y=40;close.pressed.connect(queue_free);footer.add_child(close)
	Hearth20Regal.sync(self);popup_centered()
class RouteDiagram extends Control:
	var role="host"
	var current_step=0
	var compact=false
	func _ready() -> void:
		custom_minimum_size=Vector2(580,88 if compact else 126);size_flags_horizontal=Control.SIZE_EXPAND_FILL;mouse_filter=Control.MOUSE_FILTER_IGNORE;resized.connect(queue_redraw)
	func _draw() -> void:
		var gold=Hearth20Regal.swatch(Hearth20Regal.GOLD);var ink=Hearth20Regal.swatch(Hearth20Regal.INK);var step_width=size.x/3.
		var factor=.68 if compact else 1.
		var captions=["YOUR TABLE","INVITE FRIENDS","PLACE THE PARTY"] if role=="host" else ["YOUR PC + STEAM","ACCEPT INVITE","NAME + PORTRAIT"] if role=="join" else ["HOST + PORT","SHARE DETAILS","JOIN THE TABLE"]
		for index in 3:
			draw_set_transform(Vector2(step_width*index,0),0,Vector2.ONE*factor)
			var center=Vector2(step_width*.5/factor,48)
			draw_circle(center,36,gold*Color(1,1,1,.07));draw_arc(center,36,0,TAU,64,gold,1.2,true)
			if current_step==index:draw_arc(center,40,-PI*.85,-PI*.15,32,gold,2.4,true)
			if index==0:
				draw_rect(Rect2(center-Vector2(23,17),Vector2(46,31)),gold,false,2);draw_line(center+Vector2(0,15),center+Vector2(0,23),gold,2);draw_line(center+Vector2(-13,23),center+Vector2(13,23),gold,2)
				for line in 3:draw_line(center+Vector2(-17,-10+line*8),center+Vector2(17,-10+line*8),gold.darkened(.4),1)
			elif index==1:
				draw_rect(Rect2(center-Vector2(23,16),Vector2(46,32)),gold,false,2);draw_polyline(PackedVector2Array([center+Vector2(-23,-16),center+Vector2(0,3),center+Vector2(23,-16)]),gold,2,true);draw_circle(center+Vector2(0,7),5,gold)
			else:
				draw_arc(center,22,0,TAU,48,gold,2,true);draw_circle(center+Vector2(0,-7),7,gold);draw_arc(center+Vector2(0,15),13,PI,TAU,24,gold,3,true)
			if index<2:
				var start=center+Vector2(47,0);var end=center+Vector2(step_width/factor-48,0);draw_line(start,end,gold.darkened(.3),1.5,true);draw_polyline(PackedVector2Array([end+Vector2(-6,-4),end,end+Vector2(-6,4)]),gold,1.5,true)
			draw_set_transform(Vector2.ZERO)
			var font=Hearth20Design.font(false);var width=font.get_string_size(captions[index],HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
			draw_string(font,Vector2(step_width*(float(index)+.5)-width*.5,84 if compact else 108),captions[index],HORIZONTAL_ALIGNMENT_LEFT,-1,12,ink)
