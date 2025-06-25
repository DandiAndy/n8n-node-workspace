import {
    IExecuteFunctions,
    INodeExecutionData,
    INodeType,
    INodeTypeDescription,
} from 'n8n-workflow';

export class ExampleNode implements INodeType {
    description: INodeTypeDescription = {
        displayName: 'Example Node',
        name: 'exampleNode',
        group: ['transform'],
        version: 1,
        description: 'An example custom node for n8n',
        defaults: {
            name: 'Example Node',
            color: '#FF5733',
        },
        inputs: ['main'],
        outputs: ['main'],
        properties: [
            {
                displayName: 'Input',
                name: 'input',
                type: 'string',
                default: '',
                placeholder: 'Enter some input',
                required: false,
                description: 'The input for the example node.',
            },
            {
                displayName: 'Output',
                name: 'output',
                type: 'string',
                default: '',
                placeholder: 'Output will be displayed here',
                required: false,
                description: 'The output of the example node.',
            },
        ],
    };

    async execute(this: IExecuteFunctions): Promise<INodeExecutionData[][]> {
        const input = this.getNodeParameter('input', 0) as string;
        const output = this.getNodeParameter('output', 0) as string;

        // Example logic: simply return the input as output
        return [this.helpers.returnJsonArray([{ output: output ?? input }])];
    }
}