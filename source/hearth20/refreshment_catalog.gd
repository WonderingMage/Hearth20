extends RefCounted
class_name Hearth20RefreshmentCatalog
const FOODS={
	"sausage_big":{"name":"Large sausage","sound":"chewy","plate":true},
	"sausage_small":{"name":"Small sausage","sound":"chewy","plate":true},
	"yakiniku":{"name":"Yakiniku","sound":"chewy","plate":true},
	"icecream_cone":{"name":"Ice cream cone","sound":"cone","plate":false},
	"waffle":{"name":"Waffle","sound":"crisp","plate":true},
	"icecream_jar":{"name":"Ice cream jar","sound":"lick","plate":false},
	"donut":{"name":"Donut","sound":"pastry","plate":true},
	"chips":{"name":"Big bag of chips","sound":"chips","plate":false},
	"cake":{"name":"Slice of cake","sound":"pastry","plate":true},
	"hamburger":{"name":"Hamburger","sound":"chewy","plate":true},
	"ham_egg":{"name":"Ham & egg","sound":"wet","plate":true},
	"burger":{"name":"Burger","sound":"chewy","plate":true},
	"pizza":{"name":"Pizza slice","sound":"chewy","plate":true},
	"chilli":{"name":"Chilli dish","sound":"wet","plate":false},
	"fries":{"name":"Bag of fries","sound":"chips","plate":false}}
const DRINKS={
	"beer":{"name":"Frosty beer","pack":"beer","node":"","height":.26},
	"coke":{"name":"Coke","pack":"sodas","node":"Can002","height":.23},
	"mtn_dew":{"name":"Mountain Dew","pack":"sodas","node":"Can003","height":.23},
	"sprite":{"name":"Sprite","pack":"sodas","node":"Can001","height":.23},
	"pepsi":{"name":"Pepsi","pack":"sodas","node":"Can","height":.23},
	"water":{"name":"Water","pack":"water","node":"","height":.29}}
const BASE="res://hearth20/refreshments/"
static func sound(food: String,bite: int) -> String:
	var kind=str(FOODS.get(food,{}).get("sound","chewy"))
	return "lick" if kind=="cone" and bite==0 else "crisp" if kind=="cone" else kind
static func model_path(id: String) -> String:
	if FOODS.has(id):return BASE+"imports/foods/"+id+".gltf"
	return BASE+"imports/"+str(DRINKS.get(id,{}).get("pack","beer"))+"/scene.gltf"

