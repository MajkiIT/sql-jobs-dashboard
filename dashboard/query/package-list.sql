DECLARE @hourspan INT = ?;
DECLARE @asOfDate DATETIME2 = NULLIF(?, 'NOW');
DECLARE @folderNamePattern NVARCHAR(100) = ?;
DECLARE @projectNamePattern NVARCHAR(100) = ?;
DECLARE @statusFilter INT = ?;
DECLARE @executionCount INT = ?;

SET @asOfDate = ISNULL(@asOfDate, SYSDATETIME());

;with cte_jobs_a
  as
  (
	select
	instance_id,
	start_time = CAST(STUFF(STUFF(STUFF(cast(run_date as varchar(8))+RIGHT('00000'+cast(run_time as varchar(6)),6),13,0,':'),11,0,':'),9,0,' ') as datetime),
	run_duration = ((run_duration/1000000)*86400) + (((run_duration-((run_duration/1000000)*1000000))/10000)*3600) + (((run_duration-((run_duration/10000)*10000))/100)*60) + (run_duration-(run_duration/100)*100),
	run_status,
	[server],
	step_name,
	job_id 
from msdb.dbo.sysjobhistory (nolock)
)
  ,
  cte_executions
  AS
  (
select 
	statistics_id = t.instance_id,
	execution_id = t2.instance_id,
	folder_name = [server],
	project_name = c.name,
	package_name = jb.name,
	executable_name = t.step_name,
	start_time,
	end_time = DATEADD(s,run_duration,start_time),
	elapsed_time_min = t.run_duration/60,
	status = run_status
from cte_jobs_a t
 cross apply 
 (select top 1 instance_id from  msdb.dbo.sysjobhistory (nolock) where step_id = 0 and instance_id>=t.instance_id
 and job_id = t.job_id order by instance_id) as t2
  inner join msdb.dbo.sysjobs jb (nolock)
  on t.job_id = jb.job_id
  inner join msdb.dbo.syscategories c (nolock)
  on jb.category_id = c.category_id
 ),
  cteWE as
(
	select 
		operation_id = execution_id, event_name=status, event_count = count(*)
	from 
		cte_executions 
	where
		status in (0, 2) and execution_id <> statistics_id 
	group by
		execution_id, status
),
cteKPI as
(
	select
		operation_id,
		[errors] = [0],
		warnings = [2]
	from
		cteWE
	pivot
		(
			sum(event_count) for event_name in ([0], [2])
		) p
)
select top (@executionCount) *
from
(
select 
	execution_id = 2147483647-ROW_NUMBER() over (order by start_execution_date desc), 
	project_name = c.name,
	package_name = jb.name,
	project_lsn = 0,
	environment = '',
	status = 4, 
	start_time = format(t.start_execution_date, 'yyyy-MM-dd HH:mm:ss'),
	end_time = null,
	elapsed_time_min = format(datediff(mi,t.start_execution_date,getdate()), '#,0.00'),
	warnings = null,
	errors = null,
	logging_level = 100
from [msdb].[dbo].[sysjobactivity] t
  inner join msdb.dbo.sysjobs jb (nolock)
  on t.job_id = jb.job_id
  inner join msdb.dbo.syscategories c (nolock)
  on jb.category_id = c.category_id
--  inner join msdb.dbo.sysjobsteps s (nolock)
--  on t.job_id = s.job_id and isnull(t.last_executed_step_id,0)+1 = s.step_id
  inner join msdb.sys.servers srv
  on jb.originating_server_id = srv.server_id
where start_execution_date is not null and job_history_id is null
and srv.name like @folderNamePattern
union all
select 
	e.execution_id, 
	e.project_name,
	e.package_name,
	project_lsn = 0,
	environment = '',--isnull(e.environment_folder_name, '') + isnull('\' + e.environment_name,  ''), 
	e.status, 
	start_time = format(e.start_time, 'yyyy-MM-dd HH:mm:ss'),
	end_time = format(e.end_time, 'yyyy-MM-dd HH:mm:ss'),
	elapsed_time_min = format(datediff(ss, e.start_time, e.end_time) / 60., '#,0.00'),
	k.warnings,
	k.errors,
	logging_level = 100
from 
	cte_executions e 
left outer join
	cteKPI k on e.execution_id = k.operation_id
where e.execution_id = statistics_id and e.folder_name like @folderNamePattern
) e

where 
	e.project_name like @projectNamePattern
and
	e.start_time >= dateadd(hour, -@hourspan, @asOfDate)
and
	(e.[status] = @statusFilter or @statusFilter = 5)
order by 
	e.execution_id desc
option
	(recompile);
