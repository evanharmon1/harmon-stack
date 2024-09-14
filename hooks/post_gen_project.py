import os
import shutil

def remove_folder_if_not_needed(root_path, folder_name, condition):
    """
    Remove the specified folder if the condition is met.
    
    :param root_path: The root path of the generated project.
    :param folder_name: The name of the folder to remove (relative to the root path).
    :param condition: The condition that must be met to remove the folder.
    """
    folder_path = os.path.join(root_path, folder_name)  # Construct the full path

    if condition == 'no':
        # Check if the folder exists before trying to remove it
        if os.path.isdir(folder_path):
            shutil.rmtree(folder_path, ignore_errors=True)
            print(f"Removed folder: {folder_path}")
        else:
            print(f"Folder {folder_path} does not exist, skipping.")

def main():
    # Get the root directory of the generated project (where the script is running)
    root_path = os.getcwd()
    print(f"root_path: {root_path}")

    # The cookiecutter context
    devcontainer_condition = '{{ cookiecutter.include_devcontainer }}'
    code_templates_condition = '{{ cookiecutter.include_code_templates }}'
    design_files_condition = '{{ cookiecutter.include_design_files }}'
    github_workflows_condition = '{{ cookiecutter.include_github_workflows }}'
    github_issue_templates_condition = '{{ cookiecutter.include_github_issue_templates }}'

    # Use the reusable function for different folders
    remove_folder_if_not_needed(root_path, '.devcontainer', devcontainer_condition)
    remove_folder_if_not_needed(root_path, 'codeTemplates', code_templates_condition)
    remove_folder_if_not_needed(root_path, 'design', design_files_condition)
    remove_folder_if_not_needed(root_path, '.github/workflows', github_workflows_condition)
    remove_folder_if_not_needed(root_path, '.github/ISSUE_TEMPLATE', github_issue_templates_condition) 

if __name__ == "__main__":
    main()
