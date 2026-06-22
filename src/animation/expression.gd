@tool
class_name iExpression extends Resource

## A facial expression as a set of per-feature overlay textures. Any feature left
## null keeps whatever is currently shown (so an expression can change just the
## brows, for example). Textures are full-canvas feature SVGs exported by
## tools/export_face_features.py and applied by WarriorRig.set_expression().
@export var expression_id: String = ""
## Per-eye overlays (left = near, right = far) so an expression can wink one eye.
@export var eye_l_texture: Texture2D
@export var eye_r_texture: Texture2D
@export var mouth_texture: Texture2D
@export var brows_texture: Texture2D
