declare @executionIdFilter bigint = ?;

;with cte
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
  )

  select  
	statistics_id = a.instance_id,
	execution_id = b.instance_id,
	package_name = jb.name,
	package_path = 'Job\'+a.step_name, 
	execution_path = a.server+'\'+jb.name +'\'+a.step_name,
	executable_name = a.step_name,
	start_time = format(CAST(STUFF(STUFF(STUFF(cast(run_date as varchar(8))+RIGHT('00000'+cast(run_time as varchar(6)),6),13,0,':'),11,0,':'),9,0,' ') as datetime), 'yyyy-MM-dd HH:mm:ss'),
	end_time = format(DATEADD(s,run_duration,CAST(STUFF(STUFF(STUFF(cast(run_date as varchar(8))+RIGHT('00000'+cast(run_time as varchar(6)),6),13,0,':'),11,0,':'),9,0,' ') as datetime)), 'yyyy-MM-dd HH:mm:ss'),
	execution_duration_min = a.run_duration/60,
	execution_duration_sec = a.run_duration
  from cte_jobs a
  left join cte_join b
  on a.instance_id > isnull(lb_instance_id,0) and a.instance_id <= b.instance_id
  and a.job_id = b.job_id
  inner join msdb.dbo.sysjobs jb
  on a.job_id = jb.job_id
  WHERE 
	b.instance_id <> a.instance_id AND b.instance_id = @executionIdFilter
order by
	start_time
