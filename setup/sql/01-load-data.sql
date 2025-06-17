use AirBnB_DiskANN
go

/*
    Load listings
*/
print 'Loading listings.json' 
go

drop table if exists #t;

-- Get JSON from GitHub
declare @response nvarchar(max);
exec sp_invoke_external_rest_endpoint 
    @url = 'https://raw.githubusercontent.com/Azure-Samples/azure-sql-diskann/refs/heads/main/setup/data/listings.json',
    @method = 'GET',
    @headers = '{"accept": "text/*"}',
    @response = @response output;

select   
    cast(replace(jr.value, '\\', '\') as json) as j
into
    #t
from
    openjson(@response) o
cross apply
    string_split(o.[value], char(10), 1) jr
where
    o.[key] = 'result'
and
    len(jr.value)> 1;

insert into 
    dbo.listings
select
    d.id,
    d.[name],
    d.[street],
    d.[city],
    d.[state],
    d.[country],
    d.[zipcode],
    geography::Point(d.[latitude], d.[longitude], 4326),
    [bathrooms],
    [bedrooms],
    [summary],
    [description],
    [host_id],
    [host_url],
    [listing_url],
    [room_type],
    [amenities],
    [host_verifications],
    j as [data]
from
    #t
cross apply
    openjson(j) with (
        [id] int,
        [name] varchar(50),
        [street] varchar(50),
        [city] varchar(50), 
        [state] varchar(50),
        [country] varchar(50),
        [zipcode] varchar(50),
        [bathrooms] int,
        [bedrooms] int,
        [latitude] decimal(10,5),
        [longitude] decimal(10,5),
        [description] nvarchar(max),
        [summary] nvarchar(max),
        [host_id] varchar(2000),
        [host_url] varchar(2000),
        [listing_url] varchar(2000),
        [room_type] varchar(2000),
        [amenities] nvarchar(max) as json,
        [host_verifications] nvarchar(max) as json
    ) d
go

/*
    Load reviews
*/
print 'Loading reviews.json' 
go

drop table if exists #t;

declare @response nvarchar(max);
exec sp_invoke_external_rest_endpoint 
    @url = 'https://raw.githubusercontent.com/Azure-Samples/azure-sql-diskann/refs/heads/main/setup/data/reviews.json',
    @method = 'GET',
    @headers = '{"accept": "text/*"}',
    @response = @response output;

select   
    cast(replace(jr.value, '\\', '\') as json) as j
into
    #t
from
    openjson(@response) o
cross apply
    string_split(o.[value], char(10), 1) jr
where
    o.[key] = 'result'
and
    len(jr.value)> 1;

insert into 
    dbo.reviews
select
   d.*
from
    #t
cross apply
    openjson(j) with (
        id int,
        listing_id int,
        reviewer_id int,
        reviewer_name varchar(50),
        [date] date,
        comments nvarchar(max)
    ) d
go


/*
    Load calendar
*/
print 'Loading calendar.json' 
go

drop table if exists #t;

declare @response nvarchar(max);
exec sp_invoke_external_rest_endpoint 
    @url = 'https://raw.githubusercontent.com/Azure-Samples/azure-sql-diskann/refs/heads/main/setup/data/calendar.json',
    @method = 'GET',
    @headers = '{"accept": "text/*"}',
    @response = @response output;

print 'Loading json rows into table' 

select   
    cast(replace(jr.value, '\\', '\') as json) as j
into
    #t
from
    openjson(@response) o
cross apply
    string_split(o.[value], char(10), 1) jr
where
    o.[key] = 'result'
and
    len(jr.value)> 1;

-- Load data in batched to avoid memory pressure on small installations
declare @load int = 1;
while (@load != 0)
begin
    drop table if exists #b ;
    create table #b (j json);
    insert into #b select * from (delete top (10000) #t output deleted.* from #t) b

    insert into
        dbo.calendar
    select
        d.*
    from
        #b as b
    cross apply
        openjson(j) with (
            listing_id int,
            [date] date,
            price decimal(10,2),
            available varchar(50)
        ) d

    set @load = @@rowcount
end
go
