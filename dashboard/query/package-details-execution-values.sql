declare @executionId bigint = ?;

declare @executionId bigint = ?;

select 
	0 object_type,
	object_type_desc = 'Job',
	parameter_data_type = 'String',
	parameter_name = '',
	parameter_value = 'SQLAGENT',
	sensitive = 0,
	[required] = 0, 
	value_set = 0,
	runtime_override=0
