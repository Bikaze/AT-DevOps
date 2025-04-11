import requests
import os
import shutil
from datetime import datetime

if os.path.exists("john_doe"):
    try:
        shutil.rmtree("john_doe")
        print(f"Directory '{'john_doe'}' has been removed successfully.")
    except Exception as e:
        print(f"Error: {e}")

download_folder = "john_doe"

if not os.path.exists(download_folder):
    os.makedirs(download_folder)
    print(f"Directory '{download_folder}' created.")

local_file_path = os.path.join(download_folder, "john_doe.txt")

url = "https://raw.githubusercontent.com/sdg000/pydevops_intro_lab/main/change_me.txt"

response = requests.get(url)

if response.status_code == 200:
    print("File downloaded successfully.")
    with open(local_file_path, "wb") as file:
        file.write(response.content)
    print(f"File saved successfully: {local_file_path}")
else:
    print(f"Failed to download file. Status code: {response.status_code}")

with open(local_file_path, "r") as file:
    print("\nDownloaded file content:")
    print(file.read())

user_input = input("Describe what you have learnt so far in one sentence: ")
now = datetime.now()
current_time = now.strftime("%Y-%m-%d %H:%M:%S")

with open(local_file_path, "w") as file:
    file.write(f"{user_input}\n")
    file.write(f"Last modified on: {current_time}\n")
    print(f"File updated successfully: {local_file_path}")

with open(local_file_path, "r") as file:
    print("\nYou Entered: ", end=' ')
    print(file.read())
