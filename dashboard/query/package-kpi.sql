DECLARE @hourspan INT = ?;
DECLARE @asOfDate DATETIME2 = NULLIF(?, 'NOW');
DECLARE @folderNamePattern NVARCHAR(100) = ?;
DECLARE @projectNamePattern NVARCHAR(100) = ?;
DECLARE @executionId BIGINT = ?;

SET @asOfDate = ISNULL(@asOfDate, SYSDATETIME());

WITH cteEID as
(
	SELECT execution_id FROM [catalog].executions e WHERE 
	e.folder_name LIKE @folderNamePattern AND
	e.project_name LIKE @projectNamePattern AND
	(@executionId = -1 AND e.start_time >= DATEADD(HOUR, -@hourspan, @asOfDate)) OR (e.execution_id = @executionId)
),
cteA AS
(
	SELECT [events] = COUNT(*) FROM [catalog].event_messages em WHERE em.operation_id IN (SELECT c.execution_id FROM cteEID c)
),
cteE AS
(
	SELECT errors = COUNT(*) FROM [catalog].event_messages em WHERE em.operation_id IN (SELECT c.execution_id FROM cteEID c)  AND em.event_name = 'OnError'
),
cteW AS
(
	SELECT warnings = COUNT(*) FROM [catalog].event_messages em WHERE em.operation_id IN (SELECT c.execution_id FROM cteEID c) AND em.event_name = 'OnWarning' 
),
cteDW AS
(
	SELECT duplicate_warnings = COUNT(*) FROM [catalog].event_messages em WHERE em.operation_id IN (SELECT c.execution_id FROM cteEID c) AND em.event_name = 'OnWarning' AND [message] LIKE '%duplicate%' 
),
cteMW AS
(
	SELECT memory_warnings = COUNT(*) FROM [catalog].event_messages em WHERE em.operation_id IN (SELECT c.execution_id FROM cteEID c) AND em.event_name = 'OnInformation' AND [message] LIKE '%memory allocation%' 
)
SELECT
	*
FROM
	cteA, cteE, cteW, cteDW, cteMW
OPTION
	(RECOMPILE)