  SELECT DISTINCT 
	[Server] = originating_server
  FROM [monitorDB].[jobsapp].[V_JobsInfo]
  ORDER BY
	[Server]
