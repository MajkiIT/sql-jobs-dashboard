DECLARE @executionId BIGINT = ?;

;with cte
  AS
  (
  select ROW_NUMBER() over (Partition by Job_id order by instance_id) rn, job_id,instance_id  
  from msdb.dbo.sysjobhistory jh (nolock)
  where step_id = 0
  ), cte_jobs
  as
  (
	select
	instance_id,
	start_time = CAST(STUFF(STUFF(STUFF(cast(run_date as varchar(8))+RIGHT('00000'+cast(run_time as varchar(6)),6),13,0,':'),11,0,':'),9,0,' ') as datetime),
	run_duration = ((run_duration/1000000)*86400) + (((run_duration-((run_duration/1000000)*1000000))/10000)*3600) + (((run_duration-((run_duration/10000)*10000))/100)*60) + (run_duration-(run_duration/100)*100),
	run_status,
	[server],
	step_name,
	job_id,
	message
from msdb.dbo.sysjobhistory (nolock)
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
	CAST(DATEADD(s,run_duration,start_time) AS VARCHAR(100)) as message_time,
	a.[message],
	package_name = jb.name,
	package_path = 'Job\'+a.step_name,
	subcomponent_name = '',
	execution_path = a.server+'\'+jb.name +'\'+a.step_name
  from cte_jobs a
  left join cte_join b
  on a.instance_id > isnull(lb_instance_id,0) and a.instance_id <= b.instance_id
  and a.job_id = b.job_id
  inner join msdb.dbo.sysjobs jb (nolock)
  on a.job_id = jb.job_id
  inner join msdb.dbo.syscategories c (nolock)
  on jb.category_id = c.category_id
  WHERE 
	a.instance_id <> b.instance_id 
	AND
		a.run_status IN (4)
	AND
		 b.instance_id  = @executionId
