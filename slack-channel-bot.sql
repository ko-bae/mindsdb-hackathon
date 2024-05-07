-- create slack connection
DROP DATABASE IF EXISTS mindsdb_slack;
CREATE DATABASE mindsdb_slack
WITH
  ENGINE = 'slack',
  PARAMETERS = {
      "token": "...",
      "app_token": "..."
    };

SELECT * FROM mindsdb_slack.channel_lists LIMIT 50;

-- delete the model if it exists
DROP MODEL IF EXISTS mindsdb.llama3_model_slack;

-- create ollama engine
CREATE ML_ENGINE ollama_engine
FROM ollama;

-- create an ollama model for the chatbot
CREATE MODEL mindsdb.llama3_model_slack
PREDICT response
USING
    engine = 'ollama_engine',
    model_name = 'llama3',
    ollama_serve_url = 'http://host.docker.internal:11434',
    prompt_template = 'From input message: {{text}}, write a short response to the user in the following format: Hi, I am the AI God. <Imagine you are an alien anthropologist studying human culture and customs. Analyze the following aspects of human society from an objective, outsiders perspective. Provide detailed observations, insights, and hypotheses based on the available information. Constrain your answer in 100 tokens.';

-- check the status of the model
DESCRIBE llama3_model_slack;

-- test the ollama model
SELECT
  text, response
FROM mindsdb.llama3_model_slack
WHERE text = 'Hi, can you please explain me more about nextflow?';

-- test slack channel connections, excluding messages from the bot
SELECT *
FROM mindsdb_slack.channels
WHERE channel="ai-god-1";


-- create job
CREATE JOB mindsdb.llama3_slack_job AS (
    INSERT INTO mindsdb_slack.channels(channel, text)
    SELECT
        m.channel as channel,
        m.text as input_text,
        r.response as text
    FROM
        (SELECT * 
        FROM
            (SELECT *
            FROM mindsdb_slack.channels as t
            WHERE t.channel = "ai-god-1"
            AND t.user != "U071ENUKQTH"
            AND t.created_at > LAST)
        LIMIT 1) as m
    JOIN mindsdb.llama3_model_slack as r;
) EVERY minute;

SELECT * FROM log.jobs_history WHERE project = 'mindsdb' AND name = 'llama3_slack_job';

DROP JOB llama3_slack_job;

