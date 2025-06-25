#!/bin/bash

# n8n Custom Node Generator
# Creates a new declarative-style custom node for n8n

set -e

# Default values
NODE_NAME=""
REQUIRES_CREDENTIALS=false
OUTPUT_DIR="nodes"
UPDATE_DOCKER_COMPOSE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display usage
usage() {
    echo -e "${BLUE}n8n Custom Node Generator${NC}"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -n, --name NAME             Node name (required)"
    echo "  -c, --credentials           Include credentials file"
    echo "  -o, --output DIR            Output directory (default: nodes)"
    echo "  -d, --docker                Update docker-compose.yaml"
    echo "  -h, --help                  Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --name MyApiNode"
    echo "  $0 --name MyApiNode --credentials"
    echo "  $0 -n MyApiNode -c -o my-nodes"
    echo "  $0 --name MyApiNode --credentials --docker"
    exit 1
}

# Function to convert PascalCase to kebab-case
to_kebab_case() {
    echo "$1" | sed 's/\([a-z0-9]\)\([A-Z]\)/\1-\2/g' | tr '[:upper:]' '[:lower:]'
}

# Function to convert PascalCase to camelCase
to_camel_case() {
    local first_char=$(echo "$1" | cut -c1 | tr '[:upper:]' '[:lower:]')
    local rest=$(echo "$1" | cut -c2-)
    echo "${first_char}${rest}"
}

# Function to convert kebab-case to PascalCase
to_pascal_case() {
    echo "$1" | sed -r 's/(^|-)([a-z])/\U\2/g'
}

# Function to validate node name
validate_node_name() {
    if [[ ! "$1" =~ ^[A-Z][a-zA-Z0-9]*$ ]]; then
        echo -e "${RED}Error: Node name must start with a capital letter and contain only alphanumeric characters${NC}"
        echo "Example: MyApiNode, WeatherNode, SlackConnector"
        exit 1
    fi
}

# Function to update docker-compose.yaml
update_docker_compose() {
    local docker_compose_file="docker-compose.yaml"
    local service_name="$PACKAGE_NAME"
    
    if [ ! -f "$docker_compose_file" ]; then
        echo -e "${YELLOW}Warning: docker-compose.yaml not found in current directory${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}Updating docker-compose.yaml...${NC}"
    
    # Create backup
    cp "$docker_compose_file" "${docker_compose_file}.backup"
    
    # Check if the service already exists
    if grep -q "^  $service_name:" "$docker_compose_file"; then
        echo -e "${YELLOW}Service '$service_name' already exists in docker-compose.yaml${NC}"
        return 0
    fi
    
    # Create temporary files for processing
    local temp_file=$(mktemp)
    local new_service_file=$(mktemp)
    
    # Create the new service definition
    cat > "$new_service_file" << EOF

  $service_name:
    build:
      context: ./$OUTPUT_DIR/$PACKAGE_NAME
    volumes:
      - ./$OUTPUT_DIR/$PACKAGE_NAME:/usr/src/app

EOF
    
    # Process the docker-compose file
    awk -v service_name="$service_name" -v new_service_file="$new_service_file" '
    /^  n8n:/ { in_n8n = 1 }
    /^    volumes:/ && in_n8n { in_volumes = 1 }
    /^    depends_on:/ && in_n8n { 
        in_volumes = 0
        in_depends = 1
        print $0
        print "      - " service_name
        next
    }
    /^  [a-zA-Z]/ && !/^  n8n:/ && in_n8n {
        in_n8n = 0
        in_volumes = 0
        in_depends = 0
    }
    in_volumes && /^      - \.\/nodes/ {
        print $0
        print "      - ./'$OUTPUT_DIR'/'$PACKAGE_NAME':/home/node/.n8n/custom/'$PACKAGE_NAME'"
        next
    }
    { print $0 }
    ' "$docker_compose_file" > "$temp_file"
    
    # Find where to insert the new service (before ollama service)
    if grep -q "^  ollama:" "$temp_file"; then
        # Insert before ollama
        awk '/^  ollama:/ {
            while ((getline line < "'$new_service_file'") > 0) print line
            close("'$new_service_file'")
        }
        { print $0 }' "$temp_file" > "$docker_compose_file"
    else
        # Insert before networks section
        awk '/^networks:/ {
            while ((getline line < "'$new_service_file'") > 0) print line
            close("'$new_service_file'")
        }
        { print $0 }' "$temp_file" > "$docker_compose_file"
    fi
    
    # Clean up
    rm -f "$temp_file" "$new_service_file"
    
    echo -e "${GREEN}✅ Updated docker-compose.yaml with new service '$service_name'${NC}"
    echo -e "${BLUE}Added volume mount: ./$OUTPUT_DIR/$PACKAGE_NAME:/home/node/.n8n/custom/$PACKAGE_NAME${NC}"
    echo -e "${BLUE}Added dependency: n8n depends_on $service_name${NC}"
    echo -e "${YELLOW}Backup saved as: ${docker_compose_file}.backup${NC}"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--name)
            NODE_NAME="$2"
            shift 2
            ;;
        -c|--credentials)
            REQUIRES_CREDENTIALS=true
            shift
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -d|--docker)
            UPDATE_DOCKER_COMPOSE=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            ;;
    esac
done

# Validate required parameters
if [ -z "$NODE_NAME" ]; then
    echo -e "${RED}Error: Node name is required${NC}"
    usage
fi

validate_node_name "$NODE_NAME"

# Generate names in different cases
KEBAB_NAME=$(to_kebab_case "$NODE_NAME")
CAMEL_NAME=$(to_camel_case "$NODE_NAME")
PACKAGE_NAME="$KEBAB_NAME"
NODE_DIR="$OUTPUT_DIR/$KEBAB_NAME"

echo -e "${BLUE}Creating n8n custom node...${NC}"
echo -e "Node Name: ${GREEN}$NODE_NAME${NC}"
echo -e "Package Name: ${GREEN}$PACKAGE_NAME${NC}"
echo -e "Credentials: ${GREEN}$([ "$REQUIRES_CREDENTIALS" = true ] && echo "Yes" || echo "No")${NC}"
echo -e "Output Directory: ${GREEN}$NODE_DIR${NC}"
echo -e "Update Docker Compose: ${GREEN}$([ "$UPDATE_DOCKER_COMPOSE" = true ] && echo "Yes" || echo "No")${NC}"
echo ""

# Create directory structure
echo -e "${YELLOW}Creating directory structure...${NC}"
mkdir -p "$NODE_DIR/nodes/$NODE_NAME"
mkdir -p "$NODE_DIR/credentials" 2>/dev/null || true

# Create package.json
echo -e "${YELLOW}Creating package.json...${NC}"
cat > "$NODE_DIR/package.json" << EOF
{
  "name": "$PACKAGE_NAME",
  "version": "1.0.0",
  "description": "$NODE_NAME custom node for n8n",
  "main": "dist/nodes/$NODE_NAME/$NODE_NAME.node.js",
  "scripts": {
    "build": "npx tsc",
    "build:watch": "npx tsc --watch",
    "dev": "npm run build:watch",
    "lint": "npx eslint nodes credentials --ext .ts",
    "lint:fix": "npx eslint nodes credentials --ext .ts --fix",
    "test": "jest"
  },
  "n8n": {
    "n8nNodesApiVersion": 1,
    "nodes": [
      "dist/nodes/$NODE_NAME/$NODE_NAME.node.js"
    ]$([ "$REQUIRES_CREDENTIALS" = true ] && echo ",
    \"credentials\": [
      \"dist/credentials/${NODE_NAME}Api.credentials.js\"
    ]" || echo "")
  },
  "files": [
    "dist"
  ],
  "dependencies": {
    "n8n-core": "^1.99.0",
    "n8n-workflow": "^1.82.0"
  },
  "devDependencies": {
    "@types/node": "^20.0.0",
    "@typescript-eslint/eslint-plugin": "^6.0.0",
    "@typescript-eslint/parser": "^6.0.0",
    "eslint": "^8.0.0",
    "jest": "^29.7.0",
    "@types/jest": "^29.5.0",
    "typescript": "^5.6.0"
  },
  "keywords": [
    "n8n",
    "n8n-community-node-package",
    "custom-node"
  ],
  "author": "Your Name",
  "license": "MIT",
  "repository": {
    "type": "git",
    "url": "git+https://github.com/yourusername/$PACKAGE_NAME.git"
  },
  "bugs": {
    "url": "https://github.com/yourusername/$PACKAGE_NAME/issues"
  },
  "homepage": "https://github.com/yourusername/$PACKAGE_NAME#readme"
}
EOF

# Create tsconfig.json
echo -e "${YELLOW}Creating tsconfig.json...${NC}"
cat > "$NODE_DIR/tsconfig.json" << EOF
{
  "compilerOptions": {
    "target": "ES2019",
    "module": "commonjs",
    "lib": ["ES2019"],
    "declaration": true,
    "outDir": "./dist",
    "rootDir": "./",
    "strict": true,
    "noImplicitAny": true,
    "strictNullChecks": true,
    "strictFunctionTypes": true,
    "noImplicitReturns": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "exactOptionalPropertyTypes": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true
  },
  "include": [
    "nodes/**/*",
    "credentials/**/*"
  ],
  "exclude": [
    "node_modules",
    "dist"
  ]
}
EOF

# Create .eslintrc.js
echo -e "${YELLOW}Creating .eslintrc.js...${NC}"
cat > "$NODE_DIR/.eslintrc.js" << EOF
module.exports = {
  parser: '@typescript-eslint/parser',
  parserOptions: {
    ecmaVersion: 2020,
    sourceType: 'module',
  },
  extends: [
    '@typescript-eslint/recommended',
  ],
  plugins: [
    '@typescript-eslint',
  ],
  rules: {
    '@typescript-eslint/no-unused-vars': ['error', { argsIgnorePattern: '^_' }],
    '@typescript-eslint/explicit-function-return-type': 'off',
    '@typescript-eslint/no-explicit-any': 'warn',
    '@typescript-eslint/prefer-nullish-coalescing': 'error',
    '@typescript-eslint/prefer-optional-chain': 'error',
  },
  ignorePatterns: ['dist/', 'node_modules/'],
};
EOF

# Create .gitignore
echo -e "${YELLOW}Creating .gitignore...${NC}"
cat > "$NODE_DIR/.gitignore" << EOF
# Dependencies
node_modules/

# Build output
dist/

# Environment variables
.env
.env.local
.env.*.local

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Logs
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Runtime data
pids
*.pid
*.seed
*.pid.lock
EOF

# Create main node file
echo -e "${YELLOW}Creating node file...${NC}"
cat > "$NODE_DIR/nodes/$NODE_NAME/$NODE_NAME.node.ts" << EOF
import { INodeType, INodeTypeDescription } from 'n8n-workflow';

export class $NODE_NAME implements INodeType {
	description: INodeTypeDescription = {
		displayName: '$NODE_NAME',
		name: '$CAMEL_NAME',
		icon: 'file:${KEBAB_NAME}.svg',
		group: ['transform'],
		version: 1,
		subtitle: '={{\\$parameter["operation"] + ": " + \\$parameter["resource"]}}',
		description: 'A custom node for $NODE_NAME integration',
		defaults: {
			name: '$NODE_NAME',
		},
		inputs: ['main'],
		outputs: ['main'],$([ "$REQUIRES_CREDENTIALS" = true ] && echo "
		credentials: [
			{
				name: '${NODE_NAME}Api',
				required: true,
			},
		]," || echo "")
		requestDefaults: {
			headers: {
				Accept: 'application/json',
				'Content-Type': 'application/json',
			},
		},
		properties: [
			{
				displayName: 'Resource',
				name: 'resource',
				type: 'options',
				noDataExpression: true,
				options: [
					{
						name: 'Item',
						value: 'item',
					},
				],
				default: 'item',
			},
			{
				displayName: 'Operation',
				name: 'operation',
				type: 'options',
				noDataExpression: true,
				displayOptions: {
					show: {
						resource: ['item'],
					},
				},
				options: [
					{
						name: 'Get',
						value: 'get',
						action: 'Get an item',
						description: 'Get an item',
						routing: {
							request: {
								method: 'GET',
								url: '/api/item',
							},
						},
					},
					{
						name: 'Create',
						value: 'create',
						action: 'Create an item',
						description: 'Create a new item',
						routing: {
							request: {
								method: 'POST',
								url: '/api/item',
							},
						},
					},
				],
				default: 'get',
			},
			{
				displayName: 'Item ID',
				name: 'itemId',
				type: 'string',
				required: true,
				displayOptions: {
					show: {
						resource: ['item'],
						operation: ['get'],
					},
				},
				default: '',
				description: 'The ID of the item to retrieve',
				routing: {
					request: {
						url: '=/api/item/{{$value}}',
					},
				},
			},
			{
				displayName: 'Additional Fields',
				name: 'additionalFields',
				type: 'collection',
				placeholder: 'Add Field',
				default: {},
				displayOptions: {
					show: {
						resource: ['item'],
						operation: ['create'],
					},
				},
				options: [
					{
						displayName: 'Name',
						name: 'name',
						type: 'string',
						default: '',
						description: 'Name of the item',
						routing: {
							request: {
								body: {
									name: '={{ $value }}',
								},
							},
						},
					},
					{
						displayName: 'Description',
						name: 'description',
						type: 'string',
						default: '',
						description: 'Description of the item',
						routing: {
							request: {
								body: {
									description: '={{ $value }}',
								},
							},
						},
					},
				],
			},
		],
	};
}
EOF

# Create node metadata file
echo -e "${YELLOW}Creating node metadata file...${NC}"
cat > "$NODE_DIR/nodes/$NODE_NAME/$NODE_NAME.node.json" << EOF
{
	"node": "$PACKAGE_NAME.$NODE_NAME",
	"nodeVersion": "1.0",
	"codexVersion": "1.0",
	"categories": [
		"Miscellaneous"
	],
	"resources": {$([ "$REQUIRES_CREDENTIALS" = true ] && echo "
		\"credentialDocumentation\": [
			{
				\"url\": \"https://docs.example.com/api-key\"
			}
		]," || echo "")
		"primaryDocumentation": [
			{
				"url": "https://github.com/yourusername/$PACKAGE_NAME"
			}
		]
	}
}
EOF

# Create credentials file if required
if [ "$REQUIRES_CREDENTIALS" = true ]; then
    echo -e "${YELLOW}Creating credentials file...${NC}"
    cat > "$NODE_DIR/credentials/${NODE_NAME}Api.credentials.ts" << EOF
import {
	IAuthenticateGeneric,
	ICredentialType,
	INodeProperties,
} from 'n8n-workflow';

export class ${NODE_NAME}Api implements ICredentialType {
	name = '${NODE_NAME}Api';
	displayName = '$NODE_NAME API';
	documentationUrl = 'https://docs.example.com/api-key';
	
	properties: INodeProperties[] = [
		{
			displayName: 'API Key',
			name: 'apiKey',
			type: 'string',
			typeOptions: {
				password: true,
			},
			default: '',
			required: true,
			description: 'The API key for $NODE_NAME',
		},
		{
			displayName: 'Base URL',
			name: 'baseUrl',
			type: 'string',
			default: 'https://api.example.com',
			description: 'The base URL for the $NODE_NAME API',
		},
	];

	authenticate: IAuthenticateGeneric = {
		type: 'generic',
		properties: {
			headers: {
				Authorization: '=Bearer {{$credentials.apiKey}}',
			},
		},
	};
}
EOF
fi

# Create a basic SVG icon
echo -e "${YELLOW}Creating node icon...${NC}"
cat > "$NODE_DIR/nodes/$NODE_NAME/${KEBAB_NAME}.svg" << EOF
<svg xmlns="http://www.w3.org/2000/svg" width="60" height="60" viewBox="0 0 60 60">
  <rect width="60" height="60" rx="12" fill="#4A90E2"/>
  <text x="30" y="40" font-family="Arial, sans-serif" font-size="24" font-weight="bold" text-anchor="middle" fill="white">
    ${NODE_NAME:0:1}
  </text>
</svg>
EOF

# Create README.md
echo -e "${YELLOW}Creating README.md...${NC}"
cat > "$NODE_DIR/README.md" << EOF
# $PACKAGE_NAME

A custom n8n node for $NODE_NAME integration.

## Installation

### Local Development

1. Clone this repository
2. Install dependencies:
   \`\`\`bash
   npm install
   \`\`\`
3. Build the node:
   \`\`\`bash
   npm run build
   \`\`\`
4. Link to your n8n installation:
   \`\`\`bash
   npm link
   cd ~/.n8n/custom
   npm link $PACKAGE_NAME
   \`\`\`

### Production

Install via npm:
\`\`\`bash
npm install $PACKAGE_NAME
\`\`\`

## Configuration
$([ "$REQUIRES_CREDENTIALS" = true ] && echo "
### Credentials

1. Create new credentials in n8n
2. Select \"$NODE_NAME API\" 
3. Enter your API key and base URL
" || echo "
This node does not require credentials.
")
## Usage

1. Add the $NODE_NAME node to your workflow
2. Configure the node parameters:
   - **Resource**: Select the resource type
   - **Operation**: Choose the operation to perform
   - Configure additional fields as needed

## Development

### Building

\`\`\`bash
npm run build
\`\`\`

### Watching for changes

\`\`\`bash
npm run build:watch
\`\`\`

### Linting

\`\`\`bash
npm run lint
npm run lint:fix
\`\`\`

## License

MIT
EOF

# Create a basic test file
echo -e "${YELLOW}Creating test file...${NC}"
mkdir -p "$NODE_DIR/test"
cat > "$NODE_DIR/test/$NODE_NAME.test.ts" << EOF
import { $NODE_NAME } from '../nodes/$NODE_NAME/$NODE_NAME.node';

describe('$NODE_NAME', () => {
	let node: $NODE_NAME;

	beforeEach(() => {
		node = new $NODE_NAME();
	});

	test('should have correct node properties', () => {
		expect(node.description.displayName).toBe('$NODE_NAME');
		expect(node.description.name).toBe('$CAMEL_NAME');
		expect(node.description.version).toBe(1);
	});

	test('should have correct inputs and outputs', () => {
		expect(node.description.inputs).toEqual(['main']);
		expect(node.description.outputs).toEqual(['main']);
	});
});
EOF

# Create Jest configuration
cat > "$NODE_DIR/jest.config.js" << EOF
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/test'],
  testMatch: ['**/*.test.ts'],
  collectCoverageFrom: [
    'nodes/**/*.ts',
    'credentials/**/*.ts',
    '!**/*.d.ts',
  ],
};
EOF

# Update docker-compose.yaml if requested
if [ "$UPDATE_DOCKER_COMPOSE" = true ]; then
    echo ""
    update_docker_compose
    echo ""
fi

echo ""
echo -e "${GREEN}✅ Custom node '$NODE_NAME' created successfully!${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo -e "1. ${YELLOW}cd $NODE_DIR${NC}"
echo -e "2. ${YELLOW}npm install${NC}"
echo -e "3. ${YELLOW}npm run build${NC}"
if [ "$UPDATE_DOCKER_COMPOSE" = true ]; then
    echo -e "4. ${YELLOW}docker-compose up --build${NC} (to rebuild with new node)"
else
    echo -e "4. Test the node locally by linking it to your n8n installation"
    echo -e "   ${YELLOW}npm link && cd ~/.n8n/custom && npm link $PACKAGE_NAME${NC}"
fi
echo ""
echo -e "${BLUE}Project structure:${NC}"
echo -e "$NODE_DIR/"
echo -e "  nodes/$NODE_NAME/"
echo -e "    $NODE_NAME.node.ts"
echo -e "    $NODE_NAME.node.json"
echo -e "    ${KEBAB_NAME}.svg"
$([ "$REQUIRES_CREDENTIALS" = true ] && echo -e "  credentials/
    ${NODE_NAME}Api.credentials.ts" || echo "")
echo -e "  test/"
echo -e "    $NODE_NAME.test.ts"
echo -e "  package.json"
echo -e "  tsconfig.json"
echo -e "  .eslintrc.js"
echo -e "  .gitignore"
echo -e "  jest.config.js"
echo -e "  README.md"
echo ""
echo -e "${YELLOW}Don't forget to:${NC}"
echo -e "- Update the API endpoints in the node file"
echo -e "- Customize the SVG icon"
echo -e "- Update the README with specific usage instructions"
$([ "$REQUIRES_CREDENTIALS" = true ] && echo -e "- Configure the authentication method in credentials file" || echo "")
echo -e "- Add proper error handling and validation"
echo ""
