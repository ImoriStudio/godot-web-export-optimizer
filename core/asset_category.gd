## Macro-categorie usate per raggruppare gli asset dell'export Web.
class_name AssetCategory
extends RefCounted

enum Category { TEXTURE, AUDIO, SCRIPT, SCENE, FONT, MODEL, OTHER }

const EXTENSION_MAP := {
	"png": Category.TEXTURE, "jpg": Category.TEXTURE, "jpeg": Category.TEXTURE,
	"webp": Category.TEXTURE, "svg": Category.TEXTURE, "bmp": Category.TEXTURE,
	"tga": Category.TEXTURE, "dds": Category.TEXTURE, "ktx": Category.TEXTURE,
	"basis": Category.TEXTURE, "hdr": Category.TEXTURE, "exr": Category.TEXTURE,
	"wav": Category.AUDIO, "ogg": Category.AUDIO, "mp3": Category.AUDIO,
	"gd": Category.SCRIPT, "gdshader": Category.SCRIPT, "cs": Category.SCRIPT,
	"tscn": Category.SCENE, "scn": Category.SCENE,
	"ttf": Category.FONT, "otf": Category.FONT, "woff": Category.FONT,
	"woff2": Category.FONT, "fnt": Category.FONT,
	"glb": Category.MODEL, "gltf": Category.MODEL, "obj": Category.MODEL,
}

## .res/.tres sono formati nativi generici (mesh, materiali, ma anche Theme,
## Environment, ecc.): l'estensione da sola non basta, serve la classe reale
## che _export_file() riporta. Solo classi 3D inequivocabili finiscono qui —
## una ShaderMaterial generica resta in "Altro" perché è ambigua (2D o 3D).
const TYPE_MAP := {
	"ArrayMesh": Category.MODEL, "PrimitiveMesh": Category.MODEL,
	"BoxMesh": Category.MODEL, "SphereMesh": Category.MODEL, "CapsuleMesh": Category.MODEL,
	"CylinderMesh": Category.MODEL, "TorusMesh": Category.MODEL, "PlaneMesh": Category.MODEL,
	"QuadMesh": Category.MODEL, "PrismMesh": Category.MODEL, "RibbonTrailMesh": Category.MODEL,
	"StandardMaterial3D": Category.MODEL, "ORMMaterial3D": Category.MODEL,
}

const LABEL_KEYS := {
	Category.TEXTURE: "category_texture", Category.AUDIO: "category_audio",
	Category.SCRIPT: "category_script", Category.SCENE: "category_scene",
	Category.FONT: "category_font", Category.MODEL: "category_model",
	Category.OTHER: "category_other",
}

static func classify(path: String, type: String = "") -> Category:
	var ext := path.get_extension().to_lower()
	if EXTENSION_MAP.has(ext):
		return EXTENSION_MAP[ext]
	return TYPE_MAP.get(type, Category.OTHER)

static func label(category: Category) -> String:
	return WebOptLocalization.t(LABEL_KEYS.get(category, "category_other"))
