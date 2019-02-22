declare @executionId bigint = ?;


select top (0)
	property_path = name,
	property_value = description
from 
	msdb.dbo.sysjobs (nolock)
