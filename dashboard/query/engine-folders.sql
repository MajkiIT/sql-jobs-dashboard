 SELECT TOP 1 
	folder_id = 1, 
	[name] = f.Server, 
	[description] = 'Server'
FROM 
	msdb.dbo.sysjobhistory f (nolock)
