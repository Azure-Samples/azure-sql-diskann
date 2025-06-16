use AirBnB_DiskANN
go

-- Create a table to store embeddings
-- See: https://devblogs.microsoft.com/azure-sql/efficiently-and-elegantly-modeling-embeddings-in-azure-sql-and-sql-server/
drop table if exists [dbo].[listings_embeddings];
with cte as (
    select
        listing_id, 
        name || ' - ' || description || ' - ' || summary as text_to_chunk
    from
        [dbo].[listings]
)
select 
    id = identity(int, 1, 1),
    listing_id,
    chunk,
    chunk_order,
    cast(null as vector(1536)) as embedding
into
    [dbo].[listings_embeddings]
from 
    cte 
cross apply
    ai_generate_chunks(source = text_to_chunk, chunk_type = fixed, chunk_size = 1000) c
go

-- Set primary key
alter table [dbo].[listings_embeddings]
add constraint pk primary key (id)
go

-- Check Data
select * from [dbo].[listings_embeddings] where listing_id = 37234
go

-- Generate embeddings (depending on the SKU level you have for Azure OpenAI it can take up to 10 minutes)
update [dbo].[listings_embeddings]
set embedding = ai_generate_embeddings(chunk use model TextEmbedding3Small)
where embedding is null
go

-- Make sure all embeddings have been generated
select count(*) from  [dbo].[listings_embeddings]
where embedding is null
go

-- Check Data
select * from [dbo].[listings_embeddings] where listing_id = 37234
go

-- Enable DiskANN (as it is in Preview)
dbcc traceon(466, 474, 13981, -1)
go

-- Create Vector Index
create vector index vix on [dbo].[listings_embeddings] (embedding)
with (type='diskann', metric='cosine' )
go
