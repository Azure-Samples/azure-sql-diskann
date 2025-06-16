create database AirBnB_DiskANN
go

use AirBnB_DiskANN
go

drop table if exists dbo.listings;
drop table if exists dbo.reviews;
drop table if exists dbo.calendar;
go

create table dbo.listings (
    listing_id int,
    [name] varchar(50),
    street varchar(50),
    city varchar(50),
    [state] varchar(50),
    country varchar(50),
    zipcode varchar(50),
    listing_location geography,
    bathrooms int,
    bedrooms int,
    summary nvarchar(max),
    [description] nvarchar(max),
    [host_id] varchar(2000),
    host_url varchar(2000),
    listing_url varchar(2000),
    room_type varchar(2000),
    amenities json,
    host_verifications json,
    [data] json
   );
go

create table dbo.reviews (
    id int,
    listing_id int,
    reviewer_id int,
    reviewer_name varchar(50),
    [date] date,
    comments nvarchar(max)
);
go

create table dbo.calendar (
    listing_id int,
    [date] date,
    price decimal(10,2),
    available varchar(50)
);
go
