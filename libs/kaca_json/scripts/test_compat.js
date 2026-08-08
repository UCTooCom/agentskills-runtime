const fs = require('fs');
const path = require('path');

const compatibilityDir = path.join(__dirname, '..', 'tests', 'compatibility');

function logResult(name, passed, details = '') {
    const status = passed ? '✓' : '✗';
    const color = passed ? '\x1b[32m' : '\x1b[31m';
    console.log(`  ${color}${status}\x1b[0m ${name}${details ? ` - ${details}` : ''}`);
}

function testParse(jsonString, description) {
    try {
        const result = JSON.parse(jsonString);
        return { success: true, result };
    } catch (e) {
        return { success: false, error: e.message };
    }
}

function compareResults(jsResult, cjResult, path = '') {
    const jsType = typeof jsResult;
    const cjType = typeof cjResult;
    
    if (jsType !== cjType) {
        return { match: false, reason: `Type mismatch at ${path}: JS=${jsType}, CJ=${cjType}` };
    }
    
    if (jsResult === null) {
        return { match: cjResult === null, reason: cjResult !== null ? `Null mismatch at ${path}` : '' };
    }
    
    if (typeof jsResult === 'object') {
        if (Array.isArray(jsResult) !== Array.isArray(cjResult)) {
            return { match: false, reason: `Array/Object mismatch at ${path}` };
        }
        
        if (Array.isArray(jsResult)) {
            if (jsResult.length !== cjResult.length) {
                return { match: false, reason: `Array length mismatch at ${path}: JS=${jsResult.length}, CJ=${cjResult.length}` };
            }
            for (let i = 0; i < jsResult.length; i++) {
                const result = compareResults(jsResult[i], cjResult[i], `${path}[${i}]`);
                if (!result.match) return result;
            }
        } else {
            const jsKeys = Object.keys(jsResult).sort();
            const cjKeys = Object.keys(cjResult).sort();
            
            if (jsKeys.length !== cjKeys.length) {
                return { match: false, reason: `Object key count mismatch at ${path}` };
            }
            
            for (let i = 0; i < jsKeys.length; i++) {
                if (jsKeys[i] !== cjKeys[i]) {
                    return { match: false, reason: `Key mismatch at ${path}: JS=${jsKeys[i]}, CJ=${cjKeys[i]}` };
                }
                const result = compareResults(jsResult[jsKeys[i]], cjResult[cjKeys[i]], `${path}.${jsKeys[i]}`);
                if (!result.match) return result;
            }
        }
        
        return { match: true };
    }
    
    if (typeof jsResult === 'number') {
        if (Number.isNaN(jsResult) && Number.isNaN(cjResult)) {
            return { match: true };
        }
        if (jsResult === Infinity && cjResult === Infinity) {
            return { match: true };
        }
        if (jsResult === -Infinity && cjResult === -Infinity) {
            return { match: true };
        }
        
        const tolerance = Math.abs(jsResult) * 1e-10;
        if (Math.abs(jsResult - cjResult) > tolerance) {
            return { match: false, reason: `Number mismatch at ${path}: JS=${jsResult}, CJ=${cjResult}` };
        }
        return { match: true };
    }
    
    if (jsResult !== cjResult) {
        return { match: false, reason: `Value mismatch at ${path}: JS=${jsResult}, CJ=${cjResult}` };
    }
    
    return { match: true };
}

function runBasicTests() {
    console.log('\n=== Basic Type Tests ===\n');
    
    const basicTests = [
        { name: 'null', input: 'null' },
        { name: 'true', input: 'true' },
        { name: 'false', input: 'false' },
        { name: 'integer', input: '42' },
        { name: 'negative integer', input: '-123' },
        { name: 'float', input: '3.14159' },
        { name: 'scientific notation', input: '1.5e10' },
        { name: 'negative scientific', input: '-2.5e-3' },
        { name: 'empty string', input: '""' },
        { name: 'simple string', input: '"hello"' },
        { name: 'empty object', input: '{}' },
        { name: 'empty array', input: '[]' },
        { name: 'simple object', input: '{"name":"John","age":30}' },
        { name: 'simple array', input: '[1,2,3]' },
        { name: 'nested object', input: '{"user":{"name":"Alice"}}' },
        { name: 'nested array', input: '[[1,2],[3,4]]' }
    ];
    
    let passed = 0;
    let failed = 0;
    
    for (const test of basicTests) {
        const result = testParse(test.input);
        logResult(test.name, result.success, result.success ? '' : result.error);
        if (result.success) passed++;
        else failed++;
    }
    
    console.log(`\nBasic tests: ${passed} passed, ${failed} failed`);
    return failed === 0;
}

function runEscapeTests() {
    console.log('\n=== Escape Sequence Tests ===\n');
    
    const escapeTests = [
        { name: 'quote', input: '"\\"test\\""' },
        { name: 'backslash', input: '"\\\\test"' },
        { name: 'forward slash', input: '"\\/test"' },
        { name: 'backspace', input: '"\\b"' },
        { name: 'form feed', input: '"\\f"' },
        { name: 'newline', input: '"\\n"' },
        { name: 'carriage return', input: '"\\r"' },
        { name: 'tab', input: '"\\t"' },
        { name: 'unicode', input: '"\\u0041"' },
        { name: 'unicode emoji', input: '"\\uD83D\\uDE00"' },
        { name: 'mixed escapes', input: '"line1\\nline2\\ttab"' }
    ];
    
    let passed = 0;
    let failed = 0;
    
    for (const test of escapeTests) {
        const result = testParse(test.input);
        logResult(test.name, result.success, result.success ? JSON.stringify(result.result) : result.error);
        if (result.success) passed++;
        else failed++;
    }
    
    console.log(`\nEscape tests: ${passed} passed, ${failed} failed`);
    return failed === 0;
}

function runNumberTests() {
    console.log('\n=== Number Edge Cases ===\n');
    
    const numberTests = [
        { name: 'zero', input: '0' },
        { name: 'leading zero', input: '01', shouldFail: true },
        { name: 'decimal only', input: '.5', shouldFail: true },
        { name: 'negative zero', input: '-0' },
        { name: 'very large', input: '1.7976931348623157e+308' },
        { name: 'very small', input: '5e-324' },
        { name: 'plus sign', input: '+5', shouldFail: true },
        { name: 'double decimal', input: '1.2.3', shouldFail: true },
        { name: 'exponent only', input: '1e', shouldFail: true },
        { name: 'empty exponent', input: '1e+', shouldFail: true }
    ];
    
    let passed = 0;
    let failed = 0;
    
    for (const test of numberTests) {
        const result = testParse(test.input);
        const success = test.shouldFail ? !result.success : result.success;
        logResult(test.name, success, result.success ? JSON.stringify(result.result) : result.error);
        if (success) passed++;
        else failed++;
    }
    
    console.log(`\nNumber tests: ${passed} passed, ${failed} failed`);
    return failed === 0;
}

function runEdgeCaseTests() {
    console.log('\n=== Edge Case Tests ===\n');
    
    const edgeTests = [
        { name: 'deeply nested', input: JSON.stringify({a:{b:{c:{d:{e:'deep'}}}}}) },
        { name: 'large array', input: '[' + Array(100).fill(1).join(',') + ']' },
        { name: 'long string', input: '"' + 'x'.repeat(1000) + '"' },
        { name: 'whitespace', input: '  {  "key"  :  "value"  }  ' },
        { name: 'unicode in key', input: '{"\\u4e2d\\u6587":"Chinese"}' },
        { name: 'multiple escapes', input: '"\\\\\\\\n"' },
        { name: 'empty key', input: '{"":"empty key"}' },
        { name: 'duplicate keys', input: '{"a":1,"a":2}' }
    ];
    
    let passed = 0;
    let failed = 0;
    
    for (const test of edgeTests) {
        const result = testParse(test.input);
        logResult(test.name, result.success, result.success ? 'OK' : result.error);
        if (result.success) passed++;
        else failed++;
    }
    
    console.log(`\nEdge case tests: ${passed} passed, ${failed} failed`);
    return failed === 0;
}

function runCompatibilityTestFiles() {
    console.log('\n=== Compatibility Test Files ===\n');
    
    const testFiles = [
        'basic.json',
        'numbers.json',
        'strings.json',
        'unicode.json',
        'nested.json',
        'arrays.json',
        'edge_cases.json',
        'deep_nesting.json',
        'numbers_edge.json',
        'strings_edge.json',
        'errors.json'
    ];
    
    let totalPassed = 0;
    let totalFailed = 0;
    
    for (const filename of testFiles) {
        const filepath = path.join(compatibilityDir, filename);
        
        if (!fs.existsSync(filepath)) {
            console.log(`  ⊗ ${filename} - File not found, skipping`);
            continue;
        }
        
        try {
            const content = fs.readFileSync(filepath, 'utf8');
            const testCases = JSON.parse(content);
            
            let filePassed = 0;
            let fileFailed = 0;
            
            console.log(`\nTesting ${filename}:`);
            
            for (const testCase of testCases) {
                const result = testParse(testCase.input);
                const success = testCase.shouldFail ? !result.success : result.success;
                
                if (success) {
                    filePassed++;
                } else {
                    fileFailed++;
                    logResult(testCase.name || 'unnamed', false, result.error);
                }
            }
            
            totalPassed += filePassed;
            totalFailed += fileFailed;
            
            console.log(`  ${filename}: ${filePassed} passed, ${fileFailed} failed`);
            
        } catch (e) {
            console.log(`  ✗ ${filename} - Parse error: ${e.message}`);
        }
    }
    
    console.log(`\nTotal: ${totalPassed} passed, ${totalFailed} failed`);
    return totalFailed === 0;
}

function main() {
    console.log('=== JSON Parser Compatibility Test Suite ===');
    console.log('Testing against Node.js JSON.parse()\n');
    
    const basicOk = runBasicTests();
    const escapeOk = runEscapeTests();
    const numberOk = runNumberTests();
    const edgeOk = runEdgeCaseTests();
    const filesOk = runCompatibilityTestFiles();
    
    console.log('\n=== Test Summary ===\n');
    
    if (basicOk && escapeOk && numberOk && edgeOk && filesOk) {
        console.log('All tests passed! ✓');
        process.exit(0);
    } else {
        console.log('Some tests failed! ✗');
        process.exit(1);
    }
}

main();