## The baked tides series from the operator's BlueOS module (TABOO 0.029)
## keeps the module's honest physics inside the APK.
extends RefCounted


func run(t: Object) -> void:
	var d := TidesCore.load_data()
	t._check(d.get("sites", {}).size() == 7,
		"seven sites are baked: %d" % d.get("sites", {}).size())
	t._check(TidesCore.peak(d, "issyk_kul_cholpon_ata", "astro") < 0.01,
		"Issyk-Kul astronomical tide stays under a centimetre")
	for r in ["karakol_river", "jergalan_river", "tup_river",
			"chon_kyzyl_suu_river", "chu_boom"]:
		t._check(TidesCore.peak(d, r, "astro") == 0.0,
			"%s has no tide; its rhythm is melt" % r)
		t._check(TidesCore.peak(d, r, "melt") > 0.0,
			"%s carries a melt cycle" % r)
	t._check(TidesCore.peak(d, "caspian_north_volga_delta", "astro") < 0.2,
		"Caspian astronomical tide is centimetres")
	var noon := TidesCore.at(d, "karakol_river", 15.0)
	var dawn := TidesCore.at(d, "karakol_river", 5.0)
	t._check(float(noon.get("melt", 0)) > float(dawn.get("melt", 0)),
		"Karakol melt is higher in the afternoon than at dawn (UTC)")
	t._check(str(d.get("source", "")).contains("Leonidy431/tides"),
		"the data names its module and commit")
