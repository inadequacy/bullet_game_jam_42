class_name CardView
extends Button

## One card in the level-up hand: badge, pool tag, name and description.
##
## Purely a view. It never decides what to show - `card_screen.gd` hands it a
## card dictionary from `card_database.gd` and it draws whatever is in there.
##
## The colour comes from CardDatabase.card_color(), which is the same colour
## baked into the badge, so the frame, the title and the picture always agree.

## The card body. Hover and pressed lean this toward the accent rather than
## going translucent, so the dimmed game never shows through a card.
const BODY_COLOR := Color(0.09, 0.09, 0.12)
const HOVER_TINT := 0.20
const PRESSED_TINT := 0.34

const FRAME_ALPHA := 0.85
const TAG_ALPHA := 0.75

@onready var _icon: TextureRect = $Margin/VBox/IconBox/Icon
@onready var _tag: Label = $Margin/VBox/Tag
@onready var _title: Label = $Margin/VBox/Title
@onready var _desc: Label = $Margin/VBox/Desc

var _accent: Color = Color.WHITE


## Draws a card dictionary. Safe to call again to re-use the same view.
func show_card(card: Dictionary) -> void:
	_accent = CardDatabase.card_color(card)

	_tag.text = str(card.get("group", ""))
	_title.text = str(card.get("name", "?"))
	_desc.text = str(card.get("desc", ""))

	_title.add_theme_color_override("font_color", _accent)
	_tag.add_theme_color_override("font_color", _accent * Color(1, 1, 1, TAG_ALPHA))

	_icon.texture = _load_icon(CardDatabase.icon_path(card))
	_paint_frame()


## A missing badge must not take the run down with it - the card still reads
## fine from its name and description, so warn and carry on.
func _load_icon(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		push_warning("Card icon missing: %s - reimport assets/images/cards/." % path)
		return null
	return load(path) as Texture2D


## Rebuilds the four button styleboxes in the accent colour. Done in code rather
## than in the scene because the colour changes with every hand dealt.
func _paint_frame() -> void:
	add_theme_stylebox_override("normal", _frame(BODY_COLOR, 3))
	add_theme_stylebox_override("hover", _frame(BODY_COLOR.lerp(_accent, HOVER_TINT), 4))
	add_theme_stylebox_override("pressed", _frame(BODY_COLOR.lerp(_accent, PRESSED_TINT), 4))
	# Identical to normal. A card is disabled only for the brief moment a fresh
	# hand is being dealt - see card_screen.arm_delay - and that wait is already
	# said by the deal-in fade. The theme's grey default would say it twice, and
	# louder than the thing it is describing.
	add_theme_stylebox_override("disabled", _frame(BODY_COLOR, 3))
	# Focus draws over normal, so it contributes the thicker border and nothing else.
	add_theme_stylebox_override("focus", _frame(Color(0, 0, 0, 0), 4))


func _frame(fill: Color, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_border_width_all(width)
	box.border_color = _accent * Color(1, 1, 1, FRAME_ALPHA)
	box.set_corner_radius_all(10)
	box.set_content_margin_all(0)
	return box
