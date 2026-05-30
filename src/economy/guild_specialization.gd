extends Resource
class_name GuildSpecialization

@export var thing: Thing
@export var max_workers: int = 30
@export var worker_job: EconomyTypes.JobType = EconomyTypes.JobType.CRAFTSMAN
@export var wage_per_worker: float = 1.0
@export var recruitment_rate: int = 2
