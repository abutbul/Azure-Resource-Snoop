# Azure Resource Snoop (Mapping and Topology Tool)

This application is designed to help users gather all resources under their Azure account, map them in a relational manner, and generate dynamic reports. It provides a comprehensive workflow for generating CSV files, processing resource data, and exporting detailed JSON files for visualization and reporting.

## File Descriptions

- **AzureLogin.ps1**: Handles authentication with Azure, ensuring the user is logged in and has the necessary permissions to access Azure resources.
- **CheckDependencies.ps1**: Checks for any dependencies required by the application, ensuring all necessary modules and tools are installed before running the main scripts.
- **GenerateCSVs.ps1**: Generates CSV files from Azure resources, collecting data from various Azure services and formatting it for further processing.
- **get-usage.ps1**: Retrieves usage data from Azure resources, helping to understand the utilization of different services and resources.
- **MainMenu.ps1**: Serves as the main entry point for the application, providing a menu-driven interface for users to navigate through different functionalities.
- **ProcessResources.ps1**: Processes Azure resources, merges Resource Graph data with the service map, and exports detailed JSON files for each resource.
- **PseudoCostCalculations.ps1**: Contains functions to estimate the pseudo cost of running data collection operations.
- **ExportFunctions.ps1**: Includes functions to export data to JSON files.
- **LoggingFunctions.ps1**: Provides logging functionalities to record messages and errors during script execution.

## Installation Instructions

1. Ensure you have PowerShell installed on your system (tested with PowerShell 5 through 7).
2. Clone the repository to your local machine.
3. Navigate to the project directory.
4. Run `MainMenu.ps1` to start the application and install any required dependencies.

## How and what

1. **Authentication**: Run `AzureLogin.ps1` to authenticate with Azure.
2. **Check Dependencies**: Execute `CheckDependencies.ps1` to ensure all required dependencies are installed.
3. **Generate CSVs**: Use `GenerateCSVs.ps1` to generate CSV files from Azure resources.
4. **Retrieve Usage Data**: Run `get-usage.ps1` to get usage data from Azure resources.
5. **Process Resources**: Execute `ProcessResources.ps1` to process and prepare Azure resources for CSV generation, merge Resource Graph data, and export detailed JSON files.
6. **Main Menu**: Use `MainMenew.ps1` to navigate through the application's functionalities.

## Features

### Menu-Driven Interface

The application leverages a menu-driven approach using PowerShell, specifically utilizing the [PSMenu](https://www.powershellgallery.com/packages/PSMenu) module, making it user-friendly and easy to navigate. The main menu provides options to check dependencies, authenticate with Azure, generate CSVs, process resources, and more. For more information on PSMenu, visit the [GitHub repository](https://github.com/Sebazzz/PSMenu).

### Comprehensive Logging

The application includes robust logging functionalities to record messages and errors during script execution. This helps in tracking the progress and troubleshooting any issues that may arise.

## Contribution Guidelines

- **Adding New Functionality**: Add new scripts or functions in separate files and update `MainMenu.ps1` to include the new functionality.
- **Improving Existing Scripts**: Follow existing coding standards and comment your code for better readability.
- **Testing**: Ensure all new features are thoroughly tested before submitting a pull request.

## Troubleshooting

- If you encounter issues during authentication, ensure that you have the correct Azure CLI installed and configured.
- For dependency issues, verify that all required modules are installed by running `CheckDependencies.ps1`.

## Contact Information

For any questions or support, please contact the project maintainers at issues page.

## Additional Resources

- [Azure CLI Documentation](https://docs.microsoft.com/en-us/cli/azure/)
- [PowerShell Documentation](https://docs.microsoft.com/en-us/powershell/)
- [Azure Resource Manager Templates](https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/)

## TBD Features

- [ ] Create ETL.
- [ ] Visualization.
- [ ] Interactive Reports.
- [ ] Optimize performance for large datasets.
- [ ] More logging and observability for the gathering and ETL flow.
