DECLARE @hourspan INT = ?;
DECLARE @asOfDate DATETIME2 = NULLIF(?, 'NOW');
DECLARE @folderNamePattern NVARCHAR(100) = ?;
DECLARE @projectNamePattern NVARCHAR(100) = ?;
DECLARE @statusFilter INT = ?;
DECLARE @executionCount INT = ?;

SET @asOfDate = ISNULL(@asOfDate, SYSDATETIME());

with cte
  AS
  (
  select ROW_NUMBER() over (Partition by Job_id order by instance_id) rn, job_id,instance_id  
  from msdb.dbo.sysjobhistory jh
  where step_id = 0
  ), cte_jobs
  as
  (
	select
	instance_id,
	run_date,
	run_time,
	run_duration,
	run_status,
	[server],
	step_name,
	job_id 
from msdb.dbo.sysjobhistory
  ),cte_join
  AS
  (
  select 
  a.job_id, 
  b.instance_id lb_instance_id,
  a.instance_id 
  from cte a
  left join cte b
  on a.rn = b.rn+1 and a.job_id = b.job_id
  ),
  cte_executions
  AS
  (
    select  
	statistics_id = a.instance_id,
	execution_id = b.instance_id,
	folder_name = [server],
	project_name = c.name,
	package_name = jb.name,
	executable_name = a.step_name,
	start_time = CAST(STUFF(STUFF(STUFF(cast(run_date as varchar(8))+RIGHT('00000'+cast(run_time as varchar(6)),6),13,0,':'),11,0,':'),9,0,' ') as datetime),
	end_time = DATEADD(s,run_duration,CAST(STUFF(STUFF(STUFF(cast(run_date as varchar(8))+RIGHT('00000'+cast(run_time as varchar(6)),6),13,0,':'),11,0,':'),9,0,' ') as datetime)),
	elapsed_time_min = a.run_duration/60,
	status = run_status
  from cte_jobs a
  left join cte_join b
  on a.instance_id > isnull(lb_instance_id,0) and a.instance_id <= b.instance_id
  and a.job_id = b.job_id
  inner join msdb.dbo.sysjobs jb
  on a.job_id = jb.job_id
  inner join msdb.dbo.syscategories c
  on jb.category_id = c.category_id
 -- WHERE 
	--b.instance_id <> a.instance_id 
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

select top (@executionCount)
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
	logging_level = ''
from 
	cte_executions e 

left outer join
	cteKPI k on e.execution_id = k.operation_id
--left outer join
--	cteLoglevel l on e.execution_id = l.execution_id
where 
	e.folder_name like @folderNamePattern
and
	e.project_name like @projectNamePattern
and
	e.start_time >= dateadd(hour, -@hourspan, @asOfDate)
and
	(e.[status] = @statusFilter or @statusFilter = 0)
and
e.execution_id = statistics_id
order by 
	e.execution_id desc
option
	(recompile);
