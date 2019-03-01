DECLARE @hourspan INT = ?;
DECLARE @asOfDate DATETIME2 = NULLIF(?, 'NOW');
DECLARE @folderNamePattern NVARCHAR(100) = ?;
DECLARE @projectNamePattern NVARCHAR(100) = ?;

SET @asOfDate = ISNULL(@asOfDate, SYSDATETIME());

;with cte
as
(		
	select 
		run_status = 4 
	from 
		msdb.dbo.sysjobactivity t
		inner join msdb.dbo.sysjobs jb (nolock)
		on t.job_id = jb.job_id
		inner join msdb.dbo.syscategories c (nolock)
		on jb.category_id = c.category_id
		inner join msdb.sys.servers srv
		on jb.originating_server_id = srv.server_id
	where 
		start_execution_date is not null 
	and 
		job_history_id is null 
	and
		srv.name like @folderNamePattern
	and
		c.name like @projectNamePattern
	and
		start_execution_date >= DATEADD(HOUR, -@hourspan, @asOfDate)
	union all
	select 
		run_status 
	from
		msdb.dbo.sysjobhistory jh (nolock)
		inner join msdb.dbo.sysjobs jb (nolock)
		on jh.job_id = jb.job_id
		inner join msdb.dbo.syscategories c (nolock)
		on jb.category_id = c.category_id
	where
		jh.[server] like @folderNamePattern
	and
		c.name like @projectNamePattern
	and
		jh.step_id = 0
	and
		cast(STUFF(STUFF(STUFF(cast(run_date as varchar(8))+RIGHT('00000'+cast(run_time as varchar(6)),6),13,0,':'),11,0,':'),9,0,' ') as datetime) >= DATEADD(HOUR, -@hourspan, @asOfDate)
)

	select
		[status_code] = ISNULL(run_status, 5),
		status_count = COUNT(*)		
	from
		cte
	GROUP BY 
		run_status
	WITH
		ROLLUP
