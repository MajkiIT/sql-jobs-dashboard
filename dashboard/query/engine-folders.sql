SELECT TOP 1 
	folder_id = 1, 
	[name] = f.Server, 
	[description] = ''
FROM 
	msdb.dbo.sysjobhistory f
