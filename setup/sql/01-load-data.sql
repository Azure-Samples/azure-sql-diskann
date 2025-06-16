use AirBnB_DiskANN
go

with cte as
(
    select   
       cast(replace(j.value,'\\', '\') as json) as jl
    from
        openrowset(bulk 'C:\Work\git\azure-sql-diskann\setup\data\listings.json', single_clob) t
    cross apply
        string_split(t.BulkColumn, char(10), 1) j
    where
        len(j.value)> 1
)
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
    cte.jl
from
    cte
cross apply
    openjson(jl) with (
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

with cte as
(
    select   
       cast(replace(j.value,'\\', '\') as json) as jl
    from
        openrowset(bulk 'C:\Work\git\azure-sql-diskann\setup\data\reviews.json', single_clob) t
    cross apply
        string_split(t.BulkColumn, char(10), 1) j
    where
        len(j.value)> 1
)
insert into 
    dbo.reviews
select
   d.*
from
    cte
cross apply
    openjson(jl) with (
        id int,
        listing_id int,
        reviewer_id int,
        reviewer_name varchar(50),
        [date] date,
        comments nvarchar(max)
    ) d
go

with cte as
(
    select   
       cast(replace(j.value,'\\', '\') as json) as jl
    from
        openrowset(bulk 'C:\Work\git\azure-sql-diskann\setup\data\calendar.json', single_clob) t
    cross apply
        string_split(t.BulkColumn, char(10), 1) j
    where
        len(j.value)> 1
)
insert into
    dbo.calendar
select
   d.*
from
    cte
cross apply
    openjson(jl) with (
        listing_id int,
        [date] date,
        price decimal(10,2),
        available varchar(50)
    ) d
go
