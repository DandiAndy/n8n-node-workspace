import { ExampleNode } from '../nodes/ExampleNode.node';

describe('ExampleNode', () => {
	let node: ExampleNode;

	beforeEach(() => {
		node = new ExampleNode();
	});

	test('should have correct node properties', () => {
		expect(node.description.displayName).toBe('Example Node');
		expect(node.description.name).toBe('exampleNode');
		expect(node.description.version).toBe(1);
	});

	test('should have correct inputs and outputs', () => {
		expect(node.description.inputs).toEqual(['main']);
		expect(node.description.outputs).toEqual(['main']);
	});
});
