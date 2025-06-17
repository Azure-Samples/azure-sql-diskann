# DiskANN Vector Index in SQL Server 2025

> [!NOTE]  
> DiskANN is a preview feature. Current limitations will be removed in future releases. For more information, see [DiskANN vector index in SQL Server 2025](https://learn.microsoft.com/en-us/sql/relational-databases/vectors/vectors-sql-server?view=sql-server-ver17#vector-search).

This sample shows how to use the DiskANN vector index in SQL Server 2025 along with other features introduced in SQL Server 2025 like:

- External Models
- Azure AI integration
- Invoking REST endpoints
- JSON Data Type

This sample has been inspired by the [DiskANN Postgres](https://github.com/Azure-Samples/DiskANN-demo) sample.

DiskANN is a leading vector indexing algorithm developed by [Microsoft Research](https://www.microsoft.com/en-us/research/project/project-akupara-approximate-nearest-neighbor-search-for-large-scale-semantic-search/) and used extensively at Microsoft in global services such as Bing and Microsoft 365. DiskANN enables developers to build highly accurate, performant and scalable Generative AI applications with low search latency and high accuracy.

# Getting started

Make sure you have SQL Server 2025 on your machine. The easiest way to install SQL Server 2025 is using a container image and the new SQLCMD tool.

- [Azure OpenAI chat model](https://learn.microsoft.com/en-us/azure/ai-services/openai/overview#get-started-with-azure-openai) (sample was tested with GTP-4o model)
- [Docker](https://www.docker.com/)
- [go-sqlcmd](https://learn.microsoft.com/en-us/sql/tools/sqlcmd/sqlcmd-utility?view=sql-server-ver17&tabs=go%2Cwindows%2Cwindows-support&pivots=cs1-bash#download-and-install-sqlcmd)
- [VS Code](https://code.visualstudio.com/) with [MSSQL extension](https://marketplace.visualstudio.com/items?itemName=ms-mssql.mssql)

## Install SQL Server 2025

Using SQLCMD installing SQL Server 2025 is easy. Just run the following command in your terminal:

```bash
sqlcmd create mssql --accept-eula --tag 2025-latest 
```

Once the container is running, get the connection string for ADO.NET

```bash
sqlcmd config connection-strings
```

make sure to copy and paste the connection string *without* the ADO.NET prefix. The connection string looks like the following:

```text
Server=tcp:127.0.0.1,1433;Initial Catalog=master;Persist Security Info=False;User ID=<user>;Password=<password>;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=True;Connection Timeout=30;
```

you can use the connection string [using VS Code to connect to the SQL Server instance](https://learn.microsoft.com/en-us/sql/tools/visual-studio-code-extensions/mssql/mssql-extension-visual-studio-code?view=sql-server-ver17).


## Setup Seattle AirBnb Data 

Create and populate the database using the script in the `setup/sql/` folder:

### Create Database and Tables

`00-create-objects.sql` creates the `AirBnB_DiskANN` database a the necessary tables.

### Load Data

`01-load-data.sql` loads the Seattle AirBnb data into the database, downloading it from this GitHub repository using `sp_invoke_external_rest_endpoint` and the new JSON data type in SQL Server 2025. If your SQL Server cannot connect to internet, you can load the data manually by cloning this repository and running the script against the local copy of the data.

```sql
select   
    cast(replace(j.value,'\\', '\') as json) as j
into
    #t
from
    openrowset(bulk 'C:\Work\git\azure-sql-diskann\setup\data\<file>.json', single_clob) t
cross apply
    string_split(t.BulkColumn, char(10), 1) j
where
    len(j.value)> 1
```

The string split is needed as the JSON is really a ["JSON Lines"](https://jsonlines.org/examples/) file, where each line is a separate JSON object. 

### Setup embedding model

Make sure you have deployed an Azure OpenAI embedding model, such as `text-embedding-3-small`, and have the endpoint and API key available. Run the script `02-setup-embedding-model.sql` to set up the embedding model reference in SQL Server. Make sure to replace the placeholders 

- `<api_endpoint>`: The endpoint for your Azure OpenAI instance, e.g., `https://your-openai-instance.openai.azure.com/`
- `<api_key>`: Your Azure OpenAI API key.

with your actual Azure OpenAI values.

The sample uses the `text-embedding-3-small` model, with a deployment name of `text-embedding-3-small`, but you can use any other embedding model that you have deployed in Azure OpenAI. Make sure to update the model name in the script if you are using a different model.

### Generate embeddings

Use the script `03-generate-embeddings.sql` to generate embeddings for the AirBnb data. This script uses the the new `AI_GENERATE_EMBEDDINGS` function to invoke the Azure OpenAI embedding model and store the embeddings in the database.

Embeddings are stored in a dedicated embedding table as explained in the [Efficiently and Elegantly Modeling Embeddings in Azure SQL and SQL Server](https://devblogs.microsoft.com/azure-sql/efficiently-and-elegantly-modeling-embeddings-in-azure-sql-and-sql-server/) article. Please note that the script, depending on the SKU level you have for Azure OpenAI, can take up to 10 minutes to run.

At the end of the process the [DiskANN index](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-vector-index-transact-sql?view=sql-server-ver17) will be created too.

### Run a sample search

Use script `04-search.sql` to run a sample search against the AirBnb data. The script uses the `AI_GENERATE_EMBEDDINGS` function to generate an embedding for the search query and then uses the [VECTOR_SEARCH](https://learn.microsoft.com/en-us/sql/t-sql/functions/vector-search-transact-sql?view=sql-server-ver17) function to search for similar items in the database.

## Streamlit Application

### Setting up the environment file

1. Copy `.env.sample` into a `.env` file.
2. Update the values of `AZURE_OPENAI_ENDPOINT` and `AZURE_OPENAI_API_KEY` based on the deployed values.
3. Fill in the connection string `MSSQL_CONNECTION_STRING`. 

If you are using the SQLCMD tool to run SQL Server, you can get the connection string by running:

```bash
sqlcmd config cs -d AirBnB_DiskANN
```

use the ODBC connection string to fill the `MSSQL_CONNECTION_STRING` value in the `.env` file. 

### Install dependencies

Create a virtual environment and activate it:

```bash
python -m venv .venv
.\.venv\Scripts\activate # On Windows   
# source .venv/bin/activate # On Linux or macOS
```

then install required Python packages and streamlit application:

```bash
pip install -r requirements.txt
```

### Running the application

From root directory

```bash
cd src/app
streamlit run app.py
```

When run locally run looking for website at http://localhost:8501/

