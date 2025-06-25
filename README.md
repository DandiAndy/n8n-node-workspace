# n8n-node-workspace

A Docker-based development setup with intelligent hot-reload for creating n8n custom nodes. Features separate file watchers that restart n8n for node changes while hot-importing workflows and credentials without interruption, streamlining the development workflow with automatic imports and organized project structure.

## Project Structure

```
n8n-nodes/
├── docker-compose.yaml        # Defines the services for n8n and custom nodes
├── Dockerfile.n8n            # Custom n8n Dockerfile with nodemon for development
├── start-with-watch.sh        # Startup script for n8n with file watching
├── create-node.sh             # Script to generate new custom nodes
├── import-workflows.sh        # Script to import workflows via API (optional)
├── nodes/                     # Directory containing custom nodes
│   └── n8n-nodes-example/     # Example custom node
│       ├── Dockerfile         # Dockerfile for the example node
│       ├── package.json       # Dependencies and scripts for the example node
│       └── nodes/             # Directory containing the node implementation
│           └── ExampleNode.node.ts
├── workflows/                 # Directory for workflows (auto-imported on startup)
│   ├── README.md             # Detailed workflow documentation
│   └── example-workflow.json  # Example workflow
├── credentials/               # Directory for credentials (auto-imported with env substitution)
│   ├── README.md             # Detailed credential documentation
│   ├── example-api-credentials.json      # Example API credentials
│   └── slack-api-credentials.json        # Example Slack credentials
├── data/                      # Directory for persistent n8n data
│   └── .gitkeep              # Keeps the data directory in version control
├── ollama-data/              # Directory for Ollama AI model data
├── examples/                 # Directory for examples (currently empty)
├── .env                      # Environment variables for n8n configuration
├── .env.example              # Template for environment variables
└── README.md                 # Project documentation
```

## Setup Instructions

1. **Clone the Repository**
   Clone this repository to your local machine.

2. **Install Docker and Docker Compose**
   Ensure that you have Docker and Docker Compose installed on your machine.

3. **Configure Environment Variables**
   Edit the `.env` file to set up your environment variables, including database connection settings and API keys.

4. **Build and Run the Project**
   Navigate to the project directory and run the following command to start the services:
   ```
   docker-compose up --build
   ```

5. **Access n8n**
   Once the services are running, you can access the n8n interface by navigating to `http://localhost:5678` in your web browser.

## Custom Node Generator

This project includes a bash script to quickly generate new custom nodes. The script creates a complete node structure with optional credentials support.

### Usage

```bash
./create-node.sh --name YourNodeName [--credentials] [--docker] [--output nodes]
```

### Options

- `-n, --name NAME`: Node name (required) - Must start with capital letter, e.g., `MyApiNode`, `WeatherConnector`
- `-c, --credentials`: Include credentials file for API authentication
- `-d, --docker`: Automatically update docker-compose.yaml to include the new node
- `-o, --output DIR`: Output directory (default: `nodes`)
- `-h, --help`: Show help message

### Examples

Create a basic node:
```bash
./create-node.sh --name WeatherNode
```

Create a node with credentials:
```bash
./create-node.sh --name SlackConnector --credentials
```

Create a node and update Docker Compose:
```bash
./create-node.sh --name MyApiNode --credentials --docker
```

Create a node in custom directory:
```bash
./create-node.sh --name MyApiNode --credentials --output my-nodes
```

### Generated Structure

The script creates a complete n8n custom node package with:
- TypeScript node implementation (declarative style)
- Optional credentials file for API authentication
- Package.json with all necessary dependencies
- TypeScript configuration
- ESLint configuration for code quality
- Jest test configuration
- Basic test file
- README with usage instructions
- SVG icon (customizable)
- Git ignore file

### After Generation

1. Navigate to the generated directory:
   ```bash
   cd nodes/n8n-nodes-your-node-name
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Build the node:
   ```bash
   npm run build
   ```

4. **For Docker setup** (if you used `--docker` flag):
   ```bash
   docker-compose up --build
   ```

5. **For local development** (without Docker):
   ```bash
   npm link
   cd ~/.n8n/custom
   npm init # if not already done
   npm link n8n-nodes-your-node-name
   ```

### Docker Integration

When using the `--docker` flag, the script automatically:
- Adds a new service to `docker-compose.yaml` for building your node
- Adds the volume mount to make your node available to n8n
- Updates the n8n service dependencies
- Creates a backup of the original `docker-compose.yaml`

This makes it easy to test your custom node in the Docker environment alongside the existing setup.

### Customization

After generation, you'll typically want to:
- Update API endpoints in the node file
- Customize authentication in credentials file (if using credentials)
- Replace the default SVG icon
- Add proper error handling and validation
- Write comprehensive tests

## Workflows

This project supports automatic workflow import both on startup and when files change. Workflows placed in the `workflows/` directory will be automatically imported into n8n using the `n8n import:workflow` command.

Simply place your workflow JSON files in the `workflows/` directory and they'll be automatically available in n8n. The system watches for file changes and imports new or modified workflows in real-time.

**📁 For detailed workflow documentation, see [workflows/README.md](workflows/README.md)**

## Credentials

This project supports automatic credential import with secure environment variable substitution. Credentials placed in the `credentials/` directory will be automatically imported into n8n.

Instead of storing sensitive information directly in credential files, use environment variable substitution with the `{{$env.VARIABLE_NAME}}` syntax. Set your actual secrets in the `.env` file, and the system will automatically substitute them during import.

**📁 For detailed credential documentation, see [credentials/README.md](credentials/README.md)**

Quick setup:
1. Copy `.env.example` to `.env` and add your secrets
2. Create credential JSON files using `{{$env.VAR_NAME}}` placeholders
3. Credentials are automatically imported on startup and file changes

## Ollama Setup

This project includes Ollama for running large language models locally. After starting the services, you can install and manage models:

### Installing Models

1. **List available models**:
   ```bash
   docker-compose exec ollama ollama list
   ```

2. **Install a model** (e.g., Llama 2):
   ```bash
   docker-compose exec ollama ollama pull llama2
   ```

3. **Install other popular models**:
   ```bash
   # Smaller, faster models
   docker-compose exec ollama ollama pull llama2:7b
   docker-compose exec ollama ollama pull mistral
   docker-compose exec ollama ollama pull codellama
   
   # Larger, more capable models
   docker-compose exec ollama ollama pull llama2:13b
   docker-compose exec ollama ollama pull llama2:70b
   ```

4. **Test a model**:
   ```bash
   docker-compose exec ollama ollama run llama2 "Hello, how are you?"
   ```

### Using Ollama with n8n

Once models are installed, you can create n8n workflows that interact with Ollama:

- **Ollama API endpoint**: `http://ollama:11434` (from within n8n workflows)
- **External access**: `http://localhost:11434` (from your host machine)

Example HTTP request node configuration in n8n:
- **URL**: `http://ollama:11434/api/generate`
- **Method**: POST
- **Body**: 
  ```json
  {
    "model": "llama2",
    "prompt": "Your prompt here",
    "stream": false
  }
  ```

## Custom Nodes

This project includes example custom nodes:

- **ExampleNode**: An example custom node demonstrating basic functionality.

Each custom node has its own directory containing a Dockerfile, package.json, and the node implementation.

## Contributing

Feel free to contribute to this project by adding new custom nodes or improving existing ones. Make sure to follow the project structure and guidelines.

## License

This project is licensed under the MIT License. See the LICENSE file for more details.