# import os
# import datetime
# import json

# # OPEN AI False solution - use jinja extensions instead

# # Function to update the context in the cookiecutter configuration
# def update_cookiecutter_context(context_file, context_updates):
#     with open(context_file, 'r') as f:
#         context = json.load(f)

#     # Update context with the new variables
#     context.update(context_updates)

#     with open(context_file, 'w') as f:
#         json.dump(context, f, indent=4)

# def main():
#     # Get current time, date, and directory
#     current_time = datetime.datetime.now().strftime("%H:%M:%S")
#     current_date = datetime.datetime.now().strftime("%Y-%m-%d")
#     current_directory = os.getcwd()

#     # Path to the cookiecutter context file
#     context_file = 'cookiecutter.json'

#     # Dictionary of new context variables
#     context_updates = {
#         "current_time": current_time,
#         "current_date": current_date,
#         "current_directory": current_directory
#     }

#     # Update the cookiecutter.json context
#     update_cookiecutter_context(context_file, context_updates)

# if __name__ == "__main__":
#     main()
