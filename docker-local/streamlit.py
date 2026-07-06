import streamlit as st
from PIL import Image
from dynamodb_connection import DynamoDBConnection,DynamoDBTableEditor
from streamlit import session_state as ss
import boto3
# from streamlit_msal import Msal 


icon=Image.open("assets/assistant_logo.png")
sess=boto3.session.Session(profile_name="default")

# Streamlit configuration
st.set_page_config(
    page_title="Streamlit",
    page_icon=icon
    )
st.title("DynamoDB TableEditor with ECS Fargate")

# app registration details
client_id = "a4a6e5c8-68ca-4f49-b2e6-17caf4394909"
tenant_id = "98f39334-2088-4812-a9ed-6e6ab993eedf"

# # Initialize MSAL
# auth_data = Msal.initialize(
#     client_id=f"{client_id}",
#     # authority=f"https://arysdev.ciamlogin.com/",
#     authority=f"https://login.microsoftonline.com/{tenant_id}",
#     scopes=["User.Read"],
# )

# if st.button("Sign in"):
#     Msal.sign_in()

# if st.button("Sign out"):
#     Msal.sign_out()

# if st.button("Refresh Token"):
#     Msal.revalidate()

# if not auth_data:
#     st.write("You are not signed in")
# else:
#     # Getting usefull information
#     access_token = auth_data["accessToken"]

#     account = auth_data["account"]
#     name = account["name"]
#     username = account["username"]
#     account_id = account["localAccountId"]

#     # Display information
#     st.write(f"Hello {name}!")
#     st.write(f"Your username is: {username}")

# Create a column with two rows
col1, col2 = st.columns([0.2, 0.8])
with col1:
    st.image("assets/assistant_logo.png", width=150)
with col2:
    # st.text("You have successfully accessed a Streamlit serverless app on ECS")
    st.html("<p><span style='text'>You have successfully accessed a Streamlit serverless app on ECS.</span></p>")
    
    bucket_list = sess.client("s3").list_buckets()
    bucket_names = [bucket["Name"] for bucket in bucket_list["Buckets"]]
    st.write(f"Available S3 Buckets: {bucket_names}")

    # # Create a connection:
    # conn = st.connection(
    #     "my_dynamodb_connection", type=DynamoDBConnection, api_type="pandas"
    # )

    # # Launch the table editor:
    # table_editor = DynamoDBTableEditor(conn)
    # table_editor.edit()

    # # Get all items in the table:
    # st.write(conn.items())

    # # Get a single item by key:
    # item = conn.get_item("first_item")
    # st.write(item)

    # # Put an item in the table:
    # conn.put_item(
    #     "new_item",
    #     {
    #         "text": "This item was put from streamlit!",
    #         "metadata": {"source": "mrtj"},
    #     }
    # )

    # # Modify an existing item:
    # conn.modify_item(
    #     "new_item",
    #     {
    #         "text": "This item was put and modified from streamlit!",
    #         "metadata": None,
    #         "new_field": "This is a newly added field"
    #     }
    # )

    # # Delete an item from the table:
    # conn.del_item("new_item")




