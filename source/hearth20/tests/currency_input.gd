extends SceneTree
class AppFixture extends Hearth20App:
	func _ready() -> void:
		campaign=Hearth20Identity.new_campaign("Currency input fixture")
		session=Hearth20Session.new();add_child(session);session.configure(campaign)
class PortalFixture extends Hearth20CasinoPortal:
	var sent=[]
	func _send(action: String,extras: Dictionary={}) -> void:sent.append({"action":action,"values":extras.duplicate(true)})
var checks=0
var errors=[]
func _initialize() -> void:call_deferred("run")
func expect(value: bool,note: String) -> void:
	checks+=1
	if not value:errors.append(note);push_error(note)
func action(campaign: Dictionary,kind: String,fields: Dictionary={},player="dm-local") -> Dictionary:
	var game=campaign.get("tavern_game",{})
	var command={"action":kind,"game_id":game.get("id",""),"revision":game.get("revision",0)}
	command.merge(fields)
	return Hearth20TavernGames.apply(campaign,player,command,RandomNumberGenerator.new())
func run() -> void:
	for text in ["0100","000100"," 0100 ","100","0,100"]:
		var parsed=Hearth20CasinoWallet.parse_declaration({"gp":text,"sp":"0","cp":"0"})
		expect(parsed.ok and parsed.gp==100 and parsed.total_cp==10000,"decimal gold "+text)
	var parsed=Hearth20CasinoWallet.parse_declaration({"gp":"1,234","sp":"005","cp":"0009"})
	expect(parsed.ok and parsed.total_cp==123459,"grouped gold and zero-padded silver/copper retain exact value")
	expect(Hearth20CasinoWallet.parse_declaration({}).total_cp==0,"blank coin fields mean zero")
	expect(Hearth20CasinoWallet.parse_declaration({"gp":"1000000000"}).ok,"exact maximum balance accepted")
	for raw in ["1000000001","1e8","1.5","-1","+100","1+2","0x10","1,00","12,34,567","NaN","inf","∞","١٠٠","9".repeat(128),"0".repeat(129),null,42,INF,{},[]]:
		expect(not Hearth20CasinoWallet.parse_declaration({"gp":raw}).ok,"reject malformed or excessive coins "+str(raw).left(20))
	expect(not Hearth20CasinoWallet.parse_declaration({"gp":"1000000000","cp":"1"}).ok,"combined denominations cannot exceed the limit")
	expect(not Hearth20CasinoWallet.parse_declaration({"gp":"0".repeat(10000)}).ok,"very large pasted entries fail before conversion")
	for amount in 300:
		var text="0".repeat(amount%8)+str(amount)
		var result=Hearth20CasinoWallet.parse_declaration({"gp":text,"sp":text,"cp":text})
		expect(result.ok and result.total_cp==amount*111,"zero-padded decimal roundtrip "+str(amount))
	var app=AppFixture.new();root.add_child(app)
	var portal=PortalFixture.new();root.add_child(portal);portal.app=app
	portal.actions=VBoxContainer.new();root.add_child(portal.actions);portal.game={"id":"currency-round-one"}
	portal._wallet({"actor_id":"house-token","mine":true,"name":"Guest"})
	var field=portal.actions.find_child("DeclaredGP",true,false)
	field.text="0100";field.text_changed.emit(field.text)
	var submit=portal.actions.find_children("*","Button",true,false)[0]
	expect(not submit.disabled,"zero-padded balance can be declared")
	submit.pressed.emit()
	expect(portal.sent.size()==1 and portal.sent[0].values.gp==100,"normal declaration button sends 0100 as numeric 100")
	field.text="1e999";field.text_changed.emit(field.text)
	expect(submit.disabled,"invalid entry disables declaration")
	submit.pressed.emit();expect(portal.sent.size()==1,"invalid entry never sends a stale or zero balance")
	field.text="0100";field.text_changed.emit(field.text)
	portal._clear(portal.actions);portal._wallet({"actor_id":"house-token","mine":true,"name":"Guest"})
	expect(portal.actions.find_child("DeclaredGP",true,false).text=="0100","other lobby updates preserve a balance being typed")
	portal.game={"id":"currency-round-two"};portal._clear(portal.actions);portal._wallet({"actor_id":"house-token","mine":true,"name":"Guest","declared_cp":2500})
	expect(portal.actions.find_child("DeclaredGP",true,false).text=="25" and portal.balance_drafts.size()==1,"a new casino game starts with its own bounded draft")
	var campaign=Hearth20Identity.new_campaign("Decimal wallet roundtrip")
	var actor=Hearth20TokenInventory.new_actor("Guest",true,campaign.scenes[0],Vector2(.5,.5));actor.id="currency-hero";actor.owner_player_id="player-currency";actor.coins={};campaign.actors.append(actor)
	expect(action(campaign,"open",{"game":"three_dragon_ante","chip_cp":10,"buyin":100,"minimum":1}).ok,"host opens a real casino table")
	expect(action(campaign,"join",{"actor_id":actor.id},actor.owner_player_id).ok,"player takes their own seat")
	var amount=Hearth20CasinoWallet.parse_declaration({"gp":"0100","sp":"02","cp":"003"})
	expect(action(campaign,"declare_balance",{"actor_id":actor.id,"gp":amount.gp,"sp":amount.sp,"cp":amount.cp},actor.owner_player_id).ok and Hearth20TavernGames.purse(actor)==10023,"authoritative wallet receives the exact decimal declaration")
	var before=var_to_bytes(campaign)
	expect(not action(campaign,"declare_balance",{"actor_id":actor.id,"gp":"0100","sp":0,"cp":0},actor.owner_player_id).ok and before==var_to_bytes(campaign),"raw or malformed network declarations are rejected atomically")
	var roundtrip=Hearth20Identity._decode_variant(Hearth20Identity._encode_variant(campaign))
	expect(Hearth20TavernGames.purse(roundtrip.actors[0])==10023,"declared balance survives campaign serialization")
	portal.actions.queue_free();portal.queue_free();app.queue_free();await process_frame;await process_frame
	print("Currency input: %d checks, %d failures"%[checks,errors.size()]);quit(0 if errors.is_empty() else 1)
