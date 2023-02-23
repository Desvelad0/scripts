# Author: PixelDu5t
# Made with the help of OpenAI's ChatGPT and Azure SDK for Python documentation (https://learn.microsoft.com/en-us/azure/developer/python/sdk/azure-sdk-overview)
# 
# Description: This script uses the Azure SDK for Python in order to delete any resource group associated with the current environment variable
# AZURE_SUBSCRIPTION_ID by utilizing the Inquirer library to list all the resource groups under the subscription, after which one can choose
# to delete one of the resource groups after a confirmation.
#
# Dependancies for this script are azure-core, azure-identity, azure-mgmt-resource and inquirer. 
# Additionally, in order to use the script you have to have installed the PowerShell module Az and be connected to a priviliged user in the tenant of the 
# subscription of which you want to be managing resources of. After installing the module, you can authenticate using Connect-AzAccount.

import os
import inquirer

from azure.identity import DefaultAzureCredential
from azure.mgmt.resource import ResourceManagementClient

credential = DefaultAzureCredential()

subscription_id = os.environ["AZURE_SUBSCRIPTION_ID"]

resource_client = ResourceManagementClient(credential, subscription_id)

def get_resource_groups():
    resource_groups = resource_client.resource_groups.list()
    separator = "-------"
    return [rg.name for rg in resource_groups] + [separator, "Exit"]

separator = "-------"

while True:
    questions = [
        inquirer.List('group',
                      message="Which resource group would you like to remove?",
                      choices=get_resource_groups(),
        ),
    ]

    answers = inquirer.prompt(questions)

    selected_group = answers['group']

    if selected_group == "Exit":
        break

    if selected_group == separator:
        continue

    confirm_questions = [
        inquirer.Confirm('confirm',
                         message=f"Are you sure you want to delete resource group {selected_group}?",
                         default=False,
        ),
    ]

    confirm_answers = inquirer.prompt(confirm_questions)

    if confirm_answers['confirm']:
        # Remove chosen resource group
        resource_client.resource_groups.begin_delete(resource_group_name=selected_group)
        print(f"Resource group {selected_group} has been removed.")
    else:
        print(f"Resource group {selected_group} was not removed.\n")

print("Exiting...") 
