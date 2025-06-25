# Credentials Directory

This directory contains credential templates that are automatically imported into n8n on startup.

## Security Features

- **Environment Variable Substitution**: Use `=$env.VARIABLE_NAME` syntax to reference environment variables as expressions
- **No Sensitive Data**: Credential files should never contain actual passwords, tokens, or keys
- **Automatic Import**: Files are imported on startup and when changed

## Creating Credential Files

1. Create a JSON file with the credential structure
2. Use environment variable substitution for sensitive values
3. Set the actual values in your `.env` file

## Example Structure

```json
[
  {
    "id": "my-service-001",
    "name": "My Service API",
    "type": "httpHeaderAuth",
    "data": {
      "name": "Authorization",
      "value": "=`Bearer ${$env.MY_SERVICE_API_TOKEN}`"
    }
  }
]
```

**Important**: 
- Credential files must be wrapped in an array `[]` for n8n's import command
- Each credential must have a unique `id` field for the database
- Use n8n expression syntax: `=$env.VARIABLE_NAME` for simple values or `=\`Bearer ${$env.TOKEN}\`` for templated strings
- Use descriptive IDs like `service-name-001` to avoid conflicts

## Common Credential Types

- `httpBasicAuth` - Username/password authentication
- `httpHeaderAuth` - Custom header authentication
- `oauth2Api` - OAuth2 authentication
- Service-specific types like `slackApi`, `googleApi`, etc.

## Environment Variables

Add your actual credential values to the `.env` file:

```bash
MY_SERVICE_API_TOKEN=your_actual_token_here
DATABASE_PASSWORD=your_db_password
```

## Security Best Practices

1. Never commit actual credential values to git
2. Use descriptive environment variable names
3. Keep the `.env` file in `.gitignore`
4. Use `.env.example` to document required variables
5. Rotate credentials regularly

## Troubleshooting

- Check the n8n logs if credentials fail to import
- Ensure environment variables are set correctly
- Verify the credential type matches n8n's expected format
- Test with simple credentials first before complex ones
