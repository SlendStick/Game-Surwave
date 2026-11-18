extends Node
## Мета-прогрессия, задания и формулы новых систем. Работает полностью локально.

var cfg: Dictionary = {}

func _ready() -> void:
	var f := FileAccess.open("res://data/progression.json", FileAccess.READ)
	if f:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			cfg = parsed
	_ensure_data()
	_refresh_quests()

func _ensure_data() -> void:
	var d := SaveManager.data
	if not d.has("crystals"): d["crystals"] = 0
	if not d.has("skill_rating"): d["skill_rating"] = 300.0
	if not d.has("rated_runs"): d["rated_runs"] = 0
	if not d.has("meta_tree"): d["meta_tree"] = {"power":0,"fortitude":0,"speed":0,"luck":0,"mastery":0}
	if not d.has("quests"): d["quests"] = {"daily_stamp":"","weekly_stamp":"","daily":[],"weekly":[]}
	if not d.has("quest_totals"): d["quest_totals"] = {"kills":0,"runs":0,"wins":0,"boss":0,"combo20":0}
	if not d.has("challenge_records"): d["challenge_records"] = []
	if not d.has("leaderboard"): d["leaderboard"] = []
	if not d.has("season") or int(Time.get_unix_time_from_system())-int(d.get("season",{}).get("start",0))>90*86400: d["season"] = {"id":"awakening_darkness","start":int(Time.get_unix_time_from_system()),"tasks":[]}
	if (d["season"].get("tasks",[]) as Array).is_empty():
		for task in cfg.get("season",{}).get("tasks",[]):
			var t: Dictionary = task.duplicate(true); t["progress"]=0; t["claimed"]=false; d["season"]["tasks"].append(t)
	var settings: Dictionary = d.get("settings", {})
	for pair in [["boss_fx",true],["slowmo",true],["qte",true],["post_fx",true],["photo_ui",true]]:
		if not settings.has(pair[0]): settings[pair[0]] = pair[1]
	d["settings"] = settings

func _day_stamp() -> String:
	var x := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [x.year,x.month,x.day]

func _week_stamp() -> String:
	var unix := int(Time.get_unix_time_from_system())
	return str(int(unix / 604800))

func _pick(pool: Array, count: int, seed_text: String) -> Array:
	var copy := pool.duplicate(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_text)
	var out: Array = []
	while out.size() < count and not copy.is_empty():
		var i := rng.randi_range(0, copy.size()-1)
		var q: Dictionary = copy.pop_at(i)
		q["progress"] = 0
		q["claimed"] = false
		out.append(q)
	return out

func _refresh_quests() -> void:
	var q: Dictionary = SaveManager.data["quests"]
	if String(q.get("daily_stamp","")) != _day_stamp():
		q["daily_stamp"] = _day_stamp()
		q["daily"] = _pick(cfg.get("daily_pool",[]), 3, _day_stamp())
	if String(q.get("weekly_stamp","")) != _week_stamp():
		q["weekly_stamp"] = _week_stamp()
		q["weekly"] = _pick(cfg.get("weekly_pool",[]), 1, _week_stamp())
	SaveManager.data["quests"] = q

func add_progress(kind: String, amount: int) -> void:
	if GameManager.cheat_used:
		return
	_refresh_quests()
	for task in SaveManager.data.get("season",{}).get("tasks",[]):
		if String(task.get("type","")) == kind and not bool(task.get("claimed",false)):
			task["progress"] = mini(int(task.get("goal",1)),int(task.get("progress",0))+amount)
	for group in ["daily","weekly"]:
		var arr: Array = SaveManager.data["quests"][group]
		for q in arr:
			if String(q.get("type","")) == kind and not bool(q.get("claimed",false)):
				q["progress"] = mini(int(q.get("goal",1)), int(q.get("progress",0)) + amount)
	var totals: Dictionary = SaveManager.data["quest_totals"]
	totals[kind] = int(totals.get(kind,0)) + amount

func record_combo(value: int) -> void:
	if GameManager.cheat_used:
		return
	for group in ["daily","weekly"]:
		for q in SaveManager.data.get("quests",{}).get(group,[]):
			if String(q.get("type","")) == "combo" and not bool(q.get("claimed",false)):
				q["progress"] = mini(int(q.get("goal",1)), maxi(int(q.get("progress",0)),value))

func claim(group: String, index: int) -> bool:
	var arr: Array = SaveManager.data.get("quests",{}).get(group,[])
	if index < 0 or index >= arr.size(): return false
	var q: Dictionary = arr[index]
	if bool(q.get("claimed",false)) or int(q.get("progress",0)) < int(q.get("goal",1)): return false
	q["claimed"] = true
	SaveManager.data["souls"] = int(SaveManager.data.get("souls",0)) + int(q.get("souls",0))
	SaveManager.data["crystals"] = int(SaveManager.data.get("crystals",0)) + int(q.get("crystals",0))
	SaveManager.save_game()
	return true

func claim_season(index: int) -> bool:
	var arr: Array = SaveManager.data.get("season",{}).get("tasks",[])
	if index<0 or index>=arr.size(): return false
	var q: Dictionary=arr[index]
	if bool(q.get("claimed",false)) or int(q.get("progress",0))<int(q.get("goal",1)): return false
	q["claimed"]=true; SaveManager.data["souls"]=int(SaveManager.data.get("souls",0))+int(q.get("souls",0)); SaveManager.data["crystals"]=int(SaveManager.data.get("crystals",0))+int(q.get("crystals",0)); SaveManager.save_game(); return true

func record_score(results: Dictionary, trials: Array, character: String, map_id: String) -> void:
	var row := {"date":Time.get_datetime_string_from_system(),"score":int(results.get("kills",0))*10+int(results.get("time",0)),"kills":int(results.get("kills",0)),"time":int(results.get("time",0)),"combo":int(results.get("combo_peak",0)),"trials":trials.duplicate(),"character":character,"map":map_id}
	var board: Array=SaveManager.data.get("leaderboard",[]); board.append(row); board.sort_custom(func(a,b): return int(a.score)>int(b.score)); if board.size()>50: board.resize(50); SaveManager.data["leaderboard"]=board

func tree_level(branch: String) -> int:
	return int(SaveManager.data.get("meta_tree",{}).get(branch,0))

func tree_cost(branch: String) -> int:
	var node: Dictionary = cfg.get("tree",{}).get(branch,{})
	var level := tree_level(branch)
	var costs: Array = node.get("costs",[])
	return int(costs[level]) if level < costs.size() else -1

func buy_tree(branch: String) -> bool:
	var cost := tree_cost(branch)
	if cost < 0 or int(SaveManager.data.get("souls",0)) < cost: return false
	SaveManager.data["souls"] = int(SaveManager.data["souls"]) - cost
	SaveManager.data["meta_tree"][branch] = tree_level(branch) + 1
	_apply_mastery_unlocks()
	SaveManager.save_game()
	return true

func _apply_mastery_unlocks() -> void:
	var lv := tree_level("mastery")
	var unlocks := {1:["char","ten"],2:["map","rift"],4:["char","voltra"],5:["map","bloodmoon"],6:["map","chaos"],8:["char","rain"],9:["map","temple"],11:["char","ignis"]}
	for req in unlocks:
		if lv < int(req): continue
		var item: Array = unlocks[req]
		var key := "unlocked_chars" if item[0] == "char" else "unlocked_maps"
		var arr: Array = SaveManager.data.get(key,[])
		if not arr.has(item[1]): arr.append(item[1])
		SaveManager.data[key] = arr
	if lv >= 12: SaveManager.data["endless_unlocked"] = true

func run_mods() -> Dictionary:
	var t: Dictionary = SaveManager.data.get("meta_tree",{})
	var power := int(t.get("power",0)); var fort := int(t.get("fortitude",0)); var speed := int(t.get("speed",0)); var luck := int(t.get("luck",0))
	var heal_steps := [0.05,0.05,0.10,0.0,0.0,0.10,0.0,0.0,0.10,0.0]
	var heal := 0.0
	for i in mini(fort, heal_steps.size()): heal += float(heal_steps[i])
	return {"dmg":power*0.03,"xp":power*0.04,"crit": (1 if power>=5 else 0)+(1 if power>=9 else 0)+(2 if power>=10 else 0),
		"max_hp":(1 if fort>=4 else 0)+(1 if fort>=8 else 0)+(1 if fort>=10 else 0),"heal":heal,
		"defense":(0.05 if fort>=5 else 0.0)+(0.05 if fort>=7 else 0.0)+(0.10 if fort>=9 else 0.0),"slow_immune":fort>=10,
		"move":speed*0.025,"attack":minf(0.15, speed*0.015),"gold":luck*0.03,"rare":luck*0.035,"event":luck*0.02}

func update_rating(results: Dictionary, victory: bool) -> void:
	var old := float(SaveManager.data.get("skill_rating",300.0)); var runs := int(SaveManager.data.get("rated_runs",0))
	var score := (0.3 if victory else 0.0) + 0.2*clampf(float(results.get("kills",0))/2000.0,0,1) + 0.2*(1.0-clampf(float(results.get("damage_taken",0))/50.0,0,1)) + 0.1*clampf(float(results.get("combo_peak",0))/10.0,0,1) + 0.1*clampf(float(results.get("time",0))/1800.0,0,1)
	var k := 32.0 if runs < 20 else 16.0
	SaveManager.data["skill_rating"] = clampf(old + k*(score-old/1000.0),0,1000)
	SaveManager.data["rated_runs"] = runs+1

func challenge_multiplier(ids: Array) -> float:
	if ids.is_empty(): return 1.0
	var total := 0.0
	for id in ids: total += float(cfg.get("challenges",{}).get(String(id),{}).get("reward",1.0))
	return total
