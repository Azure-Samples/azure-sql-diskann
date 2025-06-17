import streamlit as st
from openai import AzureOpenAI
import os
import numpy as np
import json
from datetime import datetime
import pandas as pd
import pyodbc, struct
from azure.identity import DefaultAzureCredential

#do this to load the env variables
from dotenv import load_dotenv
load_dotenv()

import time

st.set_page_config(
    page_title="Seattle AirBNB Rentals Search with DiskANN",
    page_icon="🏠",
    layout="wide",
    initial_sidebar_state="expanded",
)

# UI text strings
page_title = "Seattle Airbnb Rentals Listing"
page_helper = "Search SEA Rentals! The Streamlit app uses vector search to match your query with Airbnb listings and find matching properties in our database"
empty_search_helper = "👈 Enter a search query and filters to get started."
semantic_search_header = "What are you looking for?"
semantic_search_placeholder = "House with a beach view, pet-friendly, near downtown"
search_label = "Search for listings"
venue_list_header = "Listing details"
indices = ['Exact Search', 'Approximate Search (DiskANN)']

@st.cache_resource
def get_db_connection():
    
    connection_string = os.getenv("MSSQL_CONNECTION_STRING")
    attrs_before={}
    if (".database.windows.net" in connection_string):
        credential = DefaultAzureCredential(exclude_interactive_browser_credential=False)
        token_bytes = credential.get_token("https://database.windows.net/.default").token.encode("UTF-16-LE")
        token_struct = struct.pack(f'<I{len(token_bytes)}s', len(token_bytes), token_bytes)
        SQL_COPT_SS_ACCESS_TOKEN = 1256  # This connection option is defined by microsoft in msodbcsql.h
        attrs_before={SQL_COPT_SS_ACCESS_TOKEN: token_struct}        

    # Make sure strings are sent as NVARCHAR(MAX) 
    if "longasmax" not in connection_string:
        connection_string += ";LongAsMax=yes"

    conn = pyodbc.connect(connection_string, attrs_before=attrs_before)

    return conn

# Handler functions
def embedding_query(text_input):
    client = AzureOpenAI(
        api_key=os.getenv("AZURE_OPENAI_API_KEY"),
        api_version="2024-02-01",
        azure_endpoint=os.getenv("AZURE_OPENAI_ENDPOINT")
    )

	# Generate embedding for each text input
    response = client.embeddings.create(
		input=text_input,
		model="text-embedding-3-small"  # Use the appropriate model
	)
    # Parse the JSON string
    json_response = response.model_dump_json(indent=2)
    parsed_response = json.loads(json_response)

	# Extract the embedding key
    embedding = parsed_response['data'][0]['embedding']
    return embedding

def handler_search_listings(indices, date, price, ask):
    # Define the SQL query
    sql_query_no_index = """
    SET NOCOUNT ON;
	DECLARE  
        @d DATE = ?,
        @p DECIMAL(10,2) = ?,
        @q VECTOR(1536) = ?;

    WITH listing_cte AS
    (
        SELECT 
            l.listing_id, name, price, date, summary, description, le.chunk_order, le.embedding
        FROM 
            listings l
        INNER JOIN 
            listings_embeddings le on l.listing_id = le.listing_id
        INNER JOIN 
            calendar c ON l.listing_id = c.listing_id
        WHERE 
            c.date = @d AND c.available = 't' AND c.price < @p
    )
    SELECT TOP(10)
        l.listing_id, name, price, date, summary, description
    FROM 
        listing_cte l
    ORDER BY
        VECTOR_DISTANCE('cosine', embedding, @q)    
    """       

    sql_query_diskann_index = """
    SET NOCOUNT ON;
	DECLARE 
        @d DATE = ?,
        @p DECIMAL(10,2) = ?,
        @q VECTOR(1536) = ?;

    SELECT TOP(10)
	    l.listing_id, name, price, date, summary, description     	
    FROM
        VECTOR_SEARCH(
            TABLE = [dbo].[listings_embeddings] as le,
            COLUMN = [embedding],
            SIMILAR_TO = @q,
            METRIC = 'cosine',
            TOP_N = 100
        ) s
    INNER JOIN
        [dbo].[listings] l on le.listing_id = l.listing_id
    INNER JOIN 
        calendar c ON l.listing_id = c.listing_id
    WHERE 
        c.date = @d AND c.available = 't' AND c.price < @p
    ORDER BY
        s.distance
    """

    if indices == "Exact Search":
        query = sql_query_no_index
    elif indices == "Approximate Search (DiskANN)":
        query = sql_query_diskann_index

    # Connect to the MSSQL database
    conn = get_db_connection()

    with conn.cursor() as cur:
        # Get the embedding for the user query
        emb = embedding_query(ask)

        # Execute the SQL query 
        start_time = time.time()
        cur.execute(query, (date, price, json.dumps(emb)))
        results = cur.fetchall()
        end_time = time.time()

        # Store results in session state
        st.session_state.query_time = end_time - start_time            
        st.session_state.suggested_listings = pd.DataFrame.from_records(results, columns=["Listing ID", "Name", "Price", "Date", "Summary", "Description"])

    conn.close()            

# UI elements
def render_cta_link(url, label, font_awesome_icon):
    st.markdown('<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.7.0/css/font-awesome.min.css">', unsafe_allow_html=True)
    button_code = f'''<a href="{url}" target=_blank><i class="fa {font_awesome_icon}"></i> {label}</a>'''
    return st.markdown(button_code, unsafe_allow_html=True)

def render_search():
    """
    Render the search form in the sidebar.
    """
    search_disabled = True
    get_db_connection.clear()
    with st.sidebar:

        st.header("Search Listings")

        st.selectbox(label="Index", options=indices, index=0, key="index_selection")

        st.slider(label="Price Range", min_value=0, max_value=100, value=(0, 70), step=10, key="price_range")

        st.date_input(label="Check-in Date", key="checkin_date", value=datetime(2017, 1, 2))

        st.text_input(label=semantic_search_header, placeholder=semantic_search_placeholder, key="user_category_query")

        if "user_category_query" in st.session_state and st.session_state.user_category_query != "":
            search_disabled = False

        st.button(label=search_label, key="location_search", disabled=search_disabled,
                 on_click=handler_search_listings, args=(st.session_state.index_selection, st.session_state.checkin_date, st.session_state.price_range[1], st.session_state.user_category_query))

        st.write("---")

        render_cta_link(url="https://learn.microsoft.com/en-us/sql/sql-server/what-s-new-in-sql-server-2025?view=sql-server-ver17&preserve-view=true#ctp-21", label="Docs", font_awesome_icon="fa-book")
        render_cta_link(url="https://devblogs.microsoft.com/azure-sql/sql-server-2025-ctp-2-1-diskann-improvements/", label="Blog", font_awesome_icon="fa-windows")
        render_cta_link(url="https://github.com/Azure-Samples/azure-sql-db-vector-search", label="GitHub", font_awesome_icon="fa-github")

def render_search_result():
    """
    Render the search results on the main content area.
    """
    st.subheader(f"Found {len(st.session_state.suggested_listings)} listings.")
    st.subheader(f"Query time: {st.session_state.query_time:.2f} seconds")

    st.dataframe(st.session_state.suggested_listings)

render_search()

st.title(page_title)
st.write(page_helper)

if st.session_state.index_selection == "DiskANN Index":
    st.subheader("Why use DiskANN Vector Index?")
    st.markdown("""
    * **Scalability**: DiskANN is optimized for large datasets, making it ideal for handling millions of vectors.
    * **Accuracy**: DiskANN uses Iterative post filtering to enhance the accuracy of filtered vector search results without compromising on speed or precision.
    * **Low Latency**: The DiskANN graph index construction makes it very efficient during search, minimizing the number of SSD reads to achieve high throughput and low latency.
    * **Integration**: Seamlessly integrates with Azure Database for PostgreSQL, leveraging the power and flexibility of PostgreSQL.

    """)

st.write("---")

if "suggested_listings" not in st.session_state:
    st.subheader(empty_search_helper)
    st.write("Example query:")
    st.code(semantic_search_placeholder)
else:
    render_search_result()