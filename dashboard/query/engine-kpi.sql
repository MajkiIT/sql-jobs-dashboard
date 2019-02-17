DECLARE @hourspan INT = ?;
DECLARE @asOfDate DATETIME2 = NULLIF(?, 'NOW');
DECLARE @folderNamePattern NVARCHAR(100) = ?;
DECLARE @projectNamePattern NVARCHAR(100) = ?;

SET @asOfDate = ISNULL(@asOfDate, SYSDATETIME());

	select
		[status_code] = run_status,
		status_count = COUNT(*)		
	from
		msdb.dbo.sysjobhistory jh
		inner join msdb.dbo.sysjobs jb
		on jh.job_id = jb.job_id
		inner join msdb.dbo.syscategories c
		on jb.category_id = c.category_id
	where
		jh.[server] like @folderNamePattern
	and
		c.name like @projectNamePattern
	and
		jh.step_id = 0
	AND
	CAST(STUFF(STUFF(STUFF(cast(run_date as varchar(8))+RIGHT('00000'+cast(run_time as varchar(6)),6),13,0,':'),11,0,':'),9,0,' ') as datetime) >= DATEADD(HOUR, -@hourspan, @asOfDate)
	GROUP BY 
		run_status
	WITH
		ROLLUP
