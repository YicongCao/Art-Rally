extends "res://tests/test_suite.gd"
func _run() -> void:
 var app:=load("res://scenes/game/game.tscn").instantiate() as RallyGameApp
 app.profile.path="user://garage-flow-%d/profile.json"%Time.get_ticks_usec()
 root.add_child(app)
 app.prefs.values.reduced_motion=true
 app.garage_vehicle="R200"
 app.show_garage()
 app.garage_draft.tune.height=30
 app.garage_draft.tune.spring=1.25
 app.garage_draft.parts.tires="sand"
 var expected:=RallyGarageCatalog.resolve(RallyContentCatalog.vehicle("R200"),app.garage_draft).physics_config()
 app.modified_mode=true
 app.garage_test=true
 app.chosen_vehicle="R200"
 app.profile.data.settings=app.prefs.values.duplicate(true)
 var settings: Dictionary=app.profile.data.settings.duplicate(true)
 await app.start_race()
 check(app.race.generator.route.length>590 and app.race.generator.route.length<610,"Garage loads fixed 600m test stage")
 check(is_equal_approx(app.race.vehicle.config.suspension_rest,expected.suspension_rest),"Trial applies resolved ride height")
 check(app.race.vehicle.config.spring_multiplier==1.25,"Trial applies spring slider independently")
 check(app.race.vehicle.tire.compound=="sand","Trial applies chosen tire compound")
 check(not app.race.controls.allow_mechanical_shortcuts,"Pause shortcuts cannot overwrite garage setup")
 app.race._apply_preferences()
 check(app.race.vehicle.config.static_compression==expected.static_compression,"Settings refresh keeps garage mechanical baseline")
 app.race._set_autopilot_mode_name("vgamepad")
 for i: int in range(120*100):
  await physics_frame
  if app.race.session.phase==RallyStageSession.Phase.FINISHED: break
 check(app.race.session.phase==RallyStageSession.Phase.FINISHED,"Garage trial completes under actual physics")
 check(app.profile.data.challenges.is_empty() and app.garage_store.data.tests.is_empty(),"Automated trial cannot write fixed or garage records")
 check(app.profile.data.settings==settings,"Trial keeps saved driving settings")
 await app.leave_race("garage")
 check(app.screen=="garage","Trial returns directly to garage")
 app.queue_free()
 await process_frame
 finish()
