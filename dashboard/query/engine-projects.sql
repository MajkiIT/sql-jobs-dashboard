  SELECT DISTINCT 
	[Server] = originating_server, 
	[category]
  FROM [monitorDB].[jobsapp].[V_JobsInfo]
  ORDER BY
	[Server],
	[category]
