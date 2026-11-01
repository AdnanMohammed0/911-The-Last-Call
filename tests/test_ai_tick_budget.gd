extends GutTest


func test_budget_clock_begins_with_first_eligible_job() -> void:
	var matching: Node = null
	var skipped: Node = null
	var cohort: int = Engine.get_physics_frames() % AITickBudget.COHORTS
	for i: int in 8:
		var job: Node = Node.new()
		add_child_autofree(job)
		if int(job.get_instance_id() % AITickBudget.COHORTS) == cohort:
			matching = job
		else:
			skipped = job
		if matching != null and skipped != null:
			break
	assert_not_null(matching)
	assert_not_null(skipped)
	AITickBudget._frame = -1
	AITickBudget._frame_started_usec = 0
	assert_false(AITickBudget.try_consume(skipped))
	assert_eq(AITickBudget._frame_started_usec, 0)
	assert_true(AITickBudget.try_consume(matching))
	assert_gt(AITickBudget._frame_started_usec, 0)
