# Workflows Directory

This directory contains workflow templates that are automatically imported into n8n on startup and when files change.

## Automatic Import Features

- **Startup Import**: All workflows are imported when n8n starts
- **Live Import**: New or modified workflows are automatically imported when files change
- **File Watching**: The system watches this directory for changes using nodemon
- **Error Handling**: Failed imports are logged but don't stop the service

## Creating Workflow Files

1. **Export from n8n UI**:
   - Build your workflow in the n8n interface
   - Go to Settings → Download
   - Save the JSON file to this directory

2. **Manual Creation**:
   - Create a valid n8n workflow JSON file
   - Ensure it has the proper structure with `name`, `nodes`, and `connections`

## Example Workflow Structure

```json
{
  "name": "My Automation",
  "nodes": [
    {
      "parameters": {},
      "type": "n8n-nodes-base.manualTrigger",
      "typeVersion": 1,
      "position": [0, 0],
      "name": "Manual Trigger"
    }
  ],
  "connections": {},
  "active": false,
  "settings": {
    "executionOrder": "v1"
  }
}
```

## Best Practices

1. **Naming**: Use descriptive names for both files and workflow names
2. **Version Control**: Commit workflow files to track changes
3. **Documentation**: Add comments in workflow descriptions
4. **Sensitive Information**: Keep sensitive data in credentials, not in workflow files
5. **Dependencies**: Ensure required credentials and nodes are available

## Troubleshooting

- **Import Failures**: Check n8n logs for specific error messages
- **Missing Nodes**: Ensure required custom nodes are installed
- **Invalid JSON**: Validate JSON syntax before placing files here
- **Permissions**: Ensure files are readable by the n8n container
