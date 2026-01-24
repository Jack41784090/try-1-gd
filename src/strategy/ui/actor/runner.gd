class_name ActivityRunner extends Node

var is_executing_activity = false
var data: ActivityExecuteManager;

func setup(_loaded_scenario, context = {}):
	data = ActivityExecuteManager.new()
	data.setup(_loaded_scenario, context)


func exec_x_activity(activity: Activity, _when: StrategyTypes.TriggerWhen):
	var res: Array[GenericResult] = data.execute_triggerables(
		activity,
		_when
	);
	return res

func exec_before(activity: Activity):
	return exec_x_activity(activity, StrategyTypes.TriggerWhen.BEFORE_ACTIVITY)

func exec_activity(activity: Activity):
	var activity_results = activity.execute(data._build_context(activity))
	print("[GameScenario] Activity result: %s" % activity_results)
	var all_activity_result: Array[GenericResult] = []
	for result in activity_results:
		all_activity_result.append(result)
		data._apply_result(result)
	return all_activity_result

func exec_after(activity: Activity):
	return exec_x_activity(activity, StrategyTypes.TriggerWhen.AFTER_ACTIVITY)
