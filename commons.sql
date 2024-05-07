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
DROP MODEL IF EXISTS mindsdb.llama2_model_slack;
DROP MODEL IF EXISTS mindsdb.llama3_model_slack;

-- create an ollama model for the chatbot
CREATE MODEL mindsdb.llama3_model_slack
PREDICT response
USING
    engine = 'ollama_engine',
    max_tokens = 300,
    model_name = 'llama3',
    ollama_serve_url = 'http://host.docker.internal:11434',
    prompt_template = 'From input message: {{text}}, write a short response to the user in the following format: Hi, I am the AI God. <Imagine you are an alien anthropologist studying human culture and customs. Analyze the following aspects of human society from an objective, outsiders perspective. Provide detailed observations, insights, and hypotheses based on the available information.';

-- check the status of the model
DESCRIBE llama3_model_slack;

-- test the ollama model
SELECT
  text, response
FROM mindsdb.llama2_model_slack
WHERE text = 'Hi, can you please explain me more about nextflow?';

-- create knowledge base of nextflow_docs_kb
CREATE KNOWLEDGE BASE nextflow_docs_kb;

-- inserts new data rows and generates id for each row if id is not provided
INSERT INTO nextflow_docs_kb
    SELECT text_content AS content FROM files.nextflow_doc;

-- view content of a knowledge base (for example, to look up the generated id values)
SELECT * FROM nextflow_docs_kb;

DROP KNOWLEDGE BASE nextflow_docs_kb;

-- create skill
CREATE SKILL nextflow_docs_kb_skill
USING
    type = 'knowledge_base',
    source = 'nextflow_docs_kb',
    description = 'Nextflow documentation'; 

DROP SKILL nextflow_docs_kb_skill;

SHOW KNOWLEDGE_BASES;

SHOW SKILLS;

-- create langchain model

USING
    anyscale_api_key = '...';

CREATE MODEL langchain_model
PREDICT answer
USING
    engine = 'langchain_engine',
    provider = 'anyscale',
    model_name = 'meta-llama/Meta-Llama-3-8B-Instruct',
    mode = 'conversational',
    user_column = 'question' ,
    assistant_column = 'answer',
    base_url = 'https://api.endpoints.anyscale.com/v1',
    max_tokens=300,
    temperature=0.5,
    verbose=True,
    prompt_template='Answer the user input in a helpful way';

DESCRIBE langchain_model;

-- create agent
DROP AGENT IF EXISTS nextflow_chatbot;

CREATE AGENT nextflow_chatbot
USING
   model = 'langchain_model', 
   skills = ['nextflow_docs_kb_skill']; 

SELECT * FROM agents;

-- test the agent
SELECT *
FROM nextflow_chatbot
WHERE questions = "what is your data?";

-- create chatbot
CREATE CHATBOT slack_nextflow_chatbot
USING
    database = 'mindsdb_slack',
    agent = 'nextflow_chatbot',
    included_channels = ['test-channel'],
    excluded_channels = [],
    enable_dms = true,
    is_running = true;

SHOW CHATBOTS;

DROP CHATBOT slack_nextflow_chatbot;


-- test slack channel connections, not the bot itself
SELECT *
FROM mindsdb_slack.channels
WHERE channel="test-channel"
AND user != "U06V5Q55C67";

-- generate the response to messages
SELECT
    t.channel as channel,
    t.text as input_text, 
    r.response as text
FROM mindsdb_slack.channels as t
JOIN mindsdb.llama3_model_slack as r
WHERE t.channel = "test-channel"
AND t.user != "U06V5Q55C67";

-- post messages to slack
INSERT INTO mindsdb_slack.channels(channel, text)
  SELECT
    t.channel as channel,
    r.response as text
  FROM mindsdb_slack.channels as t
  JOIN mindsdb.llama2_model_slack as r
  WHERE t.channel = "test-channel"
  LIMIT 1;

-- create job
CREATE JOB mindsdb.gpt4_slack_job AS (

   -- insert into channels the output of joining model and new responses
  INSERT INTO mindsdb_slack.channels(channel, text)
    SELECT
      t.channel as channel,
      r.response as text
    FROM mindsdb_slack.channels as t
    JOIN mindsdb.llama2_model_slack as r
    WHERE t.channel = "test-channel"
    AND t.created_at > LAST

)
EVERY minute;

SELECT * FROM log.jobs_history WHERE project = 'mindsdb' AND name = 'gpt4_slack_job';

DROP JOB gpt4_slack_job;



