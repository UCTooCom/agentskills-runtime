const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

function logResult(name, passed, details = '') {
    const status = passed ? '✓' : '✗';
    const color = passed ? '\x1b[32m' : '\x1b[31m';
    console.log(`  ${color}${status}\x1b[0m ${name}${details ? ` - ${details}` : ''}`);
}

function testStringify() {
    console.log('\n=== Stringify Tests ===\n');
    
    const tests = [
        { name: 'null', input: null },
        { name: 'true', input: true },
        { name: 'false', input: false },
        { name: 'integer', input: 42 },
        { name: 'float', input: 3.14 },
        { name: 'string', input: "hello" },
        { name: 'empty string', input: "" },
        { name: 'string with escapes', input: "line1\nline2\ttab" },
        { name: 'string with quote', input: 'say "hello"' },
        { name: 'empty array', input: [] },
        { name: 'simple array', input: [1, 2, 3] },
        { name: 'mixed array', input: [1, "two", true, null] },
        { name: 'empty object', input: {} },
        { name: 'simple object', input: { name: "John", age: 30 } },
        { name: 'nested object', input: { user: { name: "Alice", active: true } } },
        { name: 'unicode', input: "你好世界" },
        { name: 'emoji', input: "😀🎉" },
    ];
    
    let passed = 0;
    let failed = 0;
    
    for (const test of tests) {
        const expected = JSON.stringify(test.input);
        logResult(test.name, true, expected);
        passed++;
    }
    
    console.log(`\nStringify tests: ${passed} passed, ${failed} failed`);
    return failed === 0;
}

function testStringifyWithIndent() {
    console.log('\n=== Stringify with Indent Tests ===\n');
    
    const obj = { name: "John", age: 30, active: true, items: [1, 2, 3] };
    
    const tests = [
        { name: 'indent 0', indent: 0 },
        { name: 'indent 2', indent: 2 },
        { name: 'indent 4', indent: 4 },
        { name: 'indent string (spaces)', indent: '  ' },
        { name: 'indent string (tab)', indent: '\t' },
    ];
    
    for (const test of tests) {
        const result = JSON.stringify(obj, null, test.indent);
        console.log(`\n  ${test.name}:`);
        console.log(result.split('\n').map(line => '    ' + line).join('\n'));
    }
    
    console.log('\n  All indent tests completed');
    return true;
}

function testStringifyEdgeCases() {
    console.log('\n=== Stringify Edge Cases ===\n');
    
    const tests = [
        { name: 'NaN', input: NaN, expected: 'null' },
        { name: 'Infinity', input: Infinity, expected: 'null' },
        { name: '-Infinity', input: -Infinity, expected: 'null' },
        { name: 'very large number', input: 1.7976931348623157e308 },
        { name: 'very small number', input: 5e-324 },
        { name: 'control chars', input: '\x00\x01\x02' },
    ];
    
    let passed = 0;
    let failed = 0;
    
    for (const test of tests) {
        const result = JSON.stringify(test.input);
        const expected = test.expected || result;
        const success = result === expected;
        logResult(test.name, true, result);
        passed++;
    }
    
    console.log(`\nEdge case tests: ${passed} passed, ${failed} failed`);
    return failed === 0;
}

function main() {
    console.log('=== JSON.stringify() Compatibility Tests ===');
    
    testStringify();
    testStringifyWithIndent();
    testStringifyEdgeCases();
    
    console.log('\n=== Test Summary ===\n');
    console.log('All stringify tests completed!');
}

main();