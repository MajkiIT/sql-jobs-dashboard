DECLARE @hourspan INT = ?;
DECLARE @asOfDate DATETIME2 = NULLIF(?, 'NOW');
DECLARE @folderNamePattern NVARCHAR(100) = ?;
DECLARE @projectNamePattern NVARCHAR(100) = ?;
DECLARE @statusFilter INT = ?;

SET @asOfDate = ISNULL(@asOfDate, SYSDATETIME());

with numbers as 
(
	select
		n = row_number() over (order by a.object_id)
	from
		sys.all_columns a cross join sys.all_columns b
), calendar as
(
	select distinct 
		cast(dateadd(hour, n * -1, @asOfDate) as date) as calendar_date
	from
		numbers
	where 
		n <= @hourspan
), executions as 
(
	select
		[created_date] = CAST(STUFF(STUFF(STUFF(cast(run_date as varchar(8))+RIGHT('00000'+cast(run_time as varchar(6)),6),13,0,':'),11,0,':'),9,0,' ') as date),
		[start_time] = (CAST(STUFF(STUFF(STUFF(cast(run_date as varchar(8))+RIGHT('00000'+cast(run_time as varchar(6)),6),13,0,':'),11,0,':'),9,0,' ') as datetime)),
		[status] = run_status,
		[execution_id] = instance_id
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
		(jh.[run_status] = @statusFilter or @statusFilter = 5)
	and
		jh.step_id = 0
)
select
	c.[calendar_date],
	created_packages = count(e.execution_id),
	executed_packages = sum(case when e.start_time is not null then 1 else 0 end),
	succeeded_packages = sum(case when e.[status] = 1 then 1 else 0 end),
	failed_packages = sum(case when e.[status] = 0 then 1 else 0 end)
from
	calendar c 
left join
	executions e on e.created_date = c.calendar_date
group by
	c.[calendar_date]
