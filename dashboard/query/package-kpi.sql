DECLARE @hourspan INT = ?;
DECLARE @asOfDate DATETIME2 = NULLIF(?, 'NOW');
DECLARE @folderNamePattern NVARCHAR(100) = ?;
DECLARE @projectNamePattern NVARCHAR(100) = ?;
DECLARE @executionId BIGINT = ?;

SET @asOfDate = ISNULL(@asOfDate, SYSDATETIME());

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
  ),
  cteEID
  AS
  (
    select  
	execution_id = b.instance_id,
	status = run_status
  from cte_jobs a
  left join cte_join b
  on a.instance_id > isnull(lb_instance_id,0) and a.instance_id <= b.instance_id
  and a.job_id = b.job_id
  inner join msdb.dbo.sysjobs jb (nolock)
  on a.job_id = jb.job_id
  inner join msdb.dbo.syscategories c (nolock)
  on jb.category_id = c.category_id
  WHERE 
	b.instance_id <> a.instance_id AND
	a.server LIKE @folderNamePattern AND
	c.name LIKE  @projectNamePattern AND
	(@executionId = -1 AND 
	start_time >= DATEADD(HOUR, -@hourspan, @asOfDate)) OR (b.instance_id = @executionId)
  ),
cteA AS
(
	SELECT [events] = COUNT(*)  FROM cteEID
),
cteE AS
(
	SELECT errors = COUNT(*) FROM cteEID where status = 0
),
cteW AS
(
	SELECT warnings = COUNT(*) FROM cteEID where status = 2 
),
cteDW AS
(
	SELECT duplicate_warnings =  COUNT(*) FROM cteEID where status = 3
),
cteMW AS
(
	SELECT memory_warnings =  COUNT(*) FROM cteEID where status = 4
)
SELECT
	*
FROM
	cteA, cteE, cteW, cteDW, cteMW
OPTION
	(RECOMPILE)
