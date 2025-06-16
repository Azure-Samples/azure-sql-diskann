use AirBnB_DiskANN
go

-- Generate embedding using Azure OpenAI and run vector search
declare @qv vector(1536) = ai_generate_embeddings('homes near downtown near restaurants and shops in a kid friendly neighboroud' use model TextEmbedding3Small);
with cte as 
(
	select
		l.listing_id,
		min(s.distance) as similarity_distance
	from
		vector_search(
			table = [dbo].[listings_embeddings] as le,
			column = [embedding],
			similar_to = @qv,
			metric = 'cosine',
			top_n = 50
		) s
	inner join
		[dbo].[listings] l on le.listing_id = l.listing_id
	group by
		l.listing_id
)
select
	l.*
from
	cte c 
inner join
	dbo.listings l on c.listing_id = l.listing_id
order by
	similarity_distance desc

