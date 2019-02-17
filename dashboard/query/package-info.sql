DECLARE @executionId BIGINT = ?;

	select
		folder_name = [server],
		project_name = c.name,
		package_name = jb.name,
		project_lsn = 0
	from
		msdb.dbo.sysjobhistory jh
		inner join msdb.dbo.sysjobs jb
		on jh.job_id = jb.job_id
		inner join msdb.dbo.syscategories c
		on jb.category_id = c.category_id
	where
		jh.step_id = 0
	and
		instance_id = @executionId
