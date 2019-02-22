DECLARE @executionIdFilter BIGINT = ?;

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
	start_time = CAST(STUFF(STUFF(STUFF(cast(run_date as varchar(8))+RIGHT('00000'+cast(run_time as varchar(6)),6),13,0,':'),11,0,':'),9,0,' ') as datetime),
	run_duration = ((run_duration/1000000)*86400) + (((run_duration-((run_duration/1000000)*1000000))/10000)*3600) + (((run_duration-((run_duration/10000)*10000))/100)*60) + (run_duration-(run_duration/100)*100),
	run_status,
	[server],
	step_name,
	job_id 
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
SELECT
	event_message_id = a.instance_id,
	message_source_type = 0,
	package_name = jb.name,
	package_path = 'Job\'+a.step_name, 
	execution_path = a.server+'\'+jb.name +'\'+a.step_name,
	message_source_name = 'SQL AGENT',
	pre_message_time = format(start_time, 'yyyy-MM-dd HH:mm:ss'),
	post_message_time = format(dateadd(ss,run_duration,start_time), 'yyyy-MM-dd HH:mm:ss'),
	elapsed_time_min = run_duration/60
   from cte_jobs a
  left join cte_join b
  on a.instance_id > isnull(lb_instance_id,0) and a.instance_id <= b.instance_id
  and a.job_id = b.job_id
  inner join msdb.dbo.sysjobs jb
  on a.job_id = jb.job_id
  inner join msdb.dbo.syscategories c
  on jb.category_id = c.category_id
  WHERE 
	b.instance_id <> a.instance_id AND
	b.instance_id = @executionIdFilter
	ORDER BY 
		a.instance_id DESC
