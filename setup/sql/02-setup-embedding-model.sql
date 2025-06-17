use AirBnB_DiskANN
go

-- Create database credentials to store API key
if not exists(select * from sys.symmetric_keys where [name] = '##MS_DatabaseMasterKey##')
begin
	create master key encryption by password = 'Pa$$_w0rd!ThatIS_L0Ng'
end
go
if exists(select * from sys.[database_scoped_credentials] where name = 'https://<api_endpoint>.openai.azure.com/') -- use your Azure OpenAI endpoint
begin
	drop database scoped credential [https://<api_endpoint>.openai.azure.com/];
end
create database scoped credential [https://<api_endpoint>.openai.azure.com/]
with identity = 'HTTPEndpointHeaders', secret = '{"api-key": "<api_key>"}'; -- Add your Azure OpenAI Key
go

-- Create reference to OpenAI model
--drop external model TextEmbedding3Small
--go
create external model TextEmbedding3Small
with ( 
      location = 'https://<api_endpoint>.openai.azure.com/openai/deployments/text-embedding-3-small/embeddings?api-version=2024-08-01-preview',
      credential = [https://<api_endpoint>.openai.azure.com/],
      api_format = 'Azure OpenAI',
      model_type = embeddings,
      model = 'embeddings'
);
go
