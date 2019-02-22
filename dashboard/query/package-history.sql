DECLARE @folderNamePattern NVARCHAR(100) = ?;
DECLARE @projectNamePattern NVARCHAR(100) = ?;
DECLARE @packageNamePattern NVARCHAR(100) = ?;

;with cte_executions
  as
  (
  select  TOP (50)
	execution_id = a.instance_id,
	project_name = c.name,
	package_name = jb.name,
	environment_name = '',
	project_lsn = 0,
	status = run_status,
	package_path = 'Job\'+a.step_name, 
	execution_path = a.server+'\'+jb.name +'\'+a.step_name,
	executable_name = a.step_name,
	start_time = CAST(STUFF(STUFF(STUFF(cast(run_date as varchar(8))+RIGHT('00000'+cast(run_time as varchar(6)),6),13,0,':'),11,0,':'),9,0,' ') as datetime),
	end_time = DATEADD(s,(((a.run_duration/1000000)*86400) + (((a.run_duration-((a.run_duration/1000000)*1000000))/10000)*3600) + (((a.run_duration-((a.run_duration/10000)*10000))/100)*60) + (a.run_duration-(a.run_duration/100)*100))
,CAST(STUFF(STUFF(STUFF(cast(run_date as varchar(8))+RIGHT('00000'+cast(run_time as varchar(6)),6),13,0,':'),11,0,':'),9,0,' ') as datetime)),
	elapsed_time_min = (((a.run_duration/1000000)*86400) + (((a.run_duration-((a.run_duration/1000000)*1000000))/10000)*3600) + (((a.run_duration-((a.run_duration/10000)*10000))/100)*60) + (a.run_duration-(a.run_duration/100)*100))
/60,
	avg_elapsed_time_min = avg( (((a.run_duration/1000000)*86400) + (((a.run_duration-((a.run_duration/1000000)*1000000))/10000)*3600) + (((a.run_duration-((a.run_duration/10000)*10000))/100)*60) + (a.run_duration-(a.run_duration/100)*100))
/ 60) 
		OVER (ORDER BY CAST(STUFF(STUFF(STUFF(cast(run_date as varchar(8))+RIGHT('00000'+cast(run_time as varchar(6)),6),13,0,':'),11,0,':'),9,0,' ') as datetime)
		 ROWS BETWEEN 5 PRECEDING AND CURRENT ROW)
  from msdb.dbo.sysjobhistory a (nolock)
  inner join msdb.dbo.sysjobs jb (nolock)
  on a.job_id = jb.job_id
  inner join msdb.dbo.syscategories c (nolock)
  on jb.category_id = c.category_id
  WHERE 
	a.step_id = 0 
  and
		a.run_status IN (1)
	AND
		a.server LIKE @folderNamePattern
	AND
		jb.name like @packageNamePattern
	AND
		c.category_id LIKE @projectNamePattern
	ORDER BY 
		a.instance_id DESC
		)
SELECT
	execution_id, 
	project_name,
	package_name,
	environment_name,
	project_lsn,
	[status],
	start_time = format(start_time, 'yyyy-MM-dd HH:mm:ss'),
	end_time = format(CASE WHEN end_time IS NULL THEN dateadd(minute, cast(CEILING(avg_elapsed_time_min) AS int), start_time) ELSE end_time end, 'yyyy-MM-dd HH:mm:ss'),
	elapsed_time_min = format(CASE WHEN end_time IS NULL THEN avg_elapsed_time_min ELSE elapsed_time_min end, '#,0.00'),
	avg_elapsed_time_min = format(avg_elapsed_time_min, '#,0.00'),
	percent_complete = format(CASE WHEN end_time IS NOT NULL then 100 else 100 * (DATEDIFF(ss, start_time, SYSDATETIMEOFFSET()) / 60.) / avg_elapsed_time_min end, '#,0.00'),
	has_expected_values = CASE WHEN end_time IS NULL THEN 1 ELSE 0 END
FROM
	cte_executions
ORDER BY
	execution_id DESC
