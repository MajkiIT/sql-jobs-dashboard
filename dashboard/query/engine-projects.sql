;with folders
as
(
	SELECT TOP 1 
	folder_id = 1, 
	[name] = f.Server, 
	[description] = 'Server'
FROM 
	msdb.dbo.sysjobhistory f
)
select f.*, 
c.category_id,
c.name,
description = 'Job Category' 
from folders f
cross join msdb.dbo.syscategories c
