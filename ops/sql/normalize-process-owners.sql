-- Kramerius admin client expects process owners to be JSON strings.
-- Processes created by local/manual calls can leave owner NULL or empty,
-- which can surface as: JSONObject["owner"] not a string.
UPDATE pcp_process
SET owner = 'system'
WHERE owner IS NULL OR btrim(owner) = '';

ALTER TABLE pcp_process
ALTER COLUMN owner SET DEFAULT 'system';
