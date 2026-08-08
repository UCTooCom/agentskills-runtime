const fs = require('fs');
const path = require('path');

function logResult(name, passed, details = '') {
    const status = passed ? '✓' : '✗';
    const color = passed ? '\x1b[32m' : '\x1b[31m';
    console.log(`  ${color}${status}\x1b[0m ${name}${details ? ` - ${details}` : ''}`);
}

function testParse(json5String, description) {
    try {
        const result = eval('(' + json5String + ')');
        return { success: true, result };
    } catch (e) {
        return { success: false, error: e.message };
    }
}

function runJson5Tests() {
    console.log('\n=== JSON5 Feature Tests ===\n');
    
    const tests = [
        { name: 'single quote string', input: "'hello world'" },
        { name: 'double quote string', input: '"hello world"' },
        { name: 'unquoted key', input: '{name: "Alice"}' },
        { name: 'trailing comma object', input: '{a: 1, b: 2,}' },
        { name: 'trailing comma array', input: '[1, 2, 3,]' },
        { name: 'single line comment', input: '{a: 1, // comment\nb: 2}' },
        { name: 'multi line comment', input: '{a: 1, /* comment */ b: 2}' },
        { name: 'hex number', input: '0xFF' },
        { name: 'leading plus', input: '+42' },
        { name: 'leading decimal', input: '.5' },
        { name: 'trailing decimal', input: '5.' },
        { name: 'infinity', input: 'Infinity' },
        { name: 'negative infinity', input: '-Infinity' },
        { name: 'nan', input: 'NaN' },
        { name: 'identifier underscore', input: '{_name: "test"}' },
        { name: 'identifier dollar', input: '{$name: "test"}' }
    ];
    
    let passed = 0;
    let failed = 0;
    
    for (const test of tests) {
        const result = testParse(test.input);
        logResult(test.name, result.success, result.success ? JSON.stringify(result.result) : result.error);
        if (result.success) passed++;
        else failed++;
    }
    
    console.log(`\nJSON5 tests: ${passed} passed, ${failed} failed`);
    return failed === 0;
}

function runJson5FileTests() {
    console.log('\n=== JSON5 Test Files ===\n');
    
    const testFiles = [
        'json5.json',
        'json5_edge.json'
    ];
    
    let totalPassed = 0;
    let totalFailed = 0;
    
    for (const testFile of testFiles) {
        const testFilePath = path.join(__dirname, '..', 'tests', 'compatibility', testFile);
        
        if (!fs.existsSync(testFilePath)) {
            console.log(`  JSON5 test file not found: ${testFile}`);
            continue;
        }
        
        try {
            const content = fs.readFileSync(testFilePath, 'utf8');
            const testCases = JSON.parse(content);
            
            let passed = 0;
            let failed = 0;
            
            for (const testCase of testCases) {
                const result = testParse(testCase.input);
                const success = testCase.shouldFail ? !result.success : result.success;
                
                logResult(testCase.name, success, result.success ? 'OK' : result.error);
                
                if (success) passed++;
                else failed++;
            }
            
            totalPassed += passed;
            totalFailed += failed;
            
            console.log(`\n${testFile}: ${passed} passed, ${failed} failed`);
        } catch (e) {
            console.log(`  Error reading test file: ${e.message}`);
        }
    }
    
    // Test chromium_example.json5
    console.log('\n--- Testing chromium_example.json5 ---\n');
    const chromiumPath = path.join(__dirname, '..', 'tests', 'chromium_example.json5');
    if (fs.existsSync(chromiumPath)) {
        try {
            const content = fs.readFileSync(chromiumPath, 'utf8');
            const result = testParse(content);
            if (result.success) {
                console.log(`  \x1b[32m✓\x1b[0m chromium_example.json5 - Parse successful`);
                console.log(`    Top-level keys: ${Object.keys(result.result).join(', ')}`);
                console.log(`    Data array length: ${result.result.data ? result.result.data.length : 'N/A'}`);
                totalPassed++;
            } else {
                console.log(`  \x1b[31m✗\x1b[0m chromium_example.json5 - Parse failed: ${result.error}`);
                totalFailed++;
            }
        } catch (e) {
            console.log(`  \x1b[31m✗\x1b[0m chromium_example.json5 - Error: ${e.message}`);
            totalFailed++;
        }
    } else {
        console.log(`  JSON5 test file not found: chromium_example.json5`);
    }
    
    console.log(`\nTotal JSON5 file tests: ${totalPassed} passed, ${totalFailed} failed`);
    return totalFailed === 0;
}

function main() {
    console.log('=== JSON5 Compatibility Test Suite ===');
    console.log('Testing JSON5 features against JavaScript eval()\n');
    
    const basicOk = runJson5Tests();
    const fileOk = runJson5FileTests();
    
    console.log('\n=== Test Summary ===\n');
    
    if (basicOk && fileOk) {
        console.log('All JSON5 tests passed! ✓');
        process.exit(0);
    } else {
        console.log('Some JSON5 tests failed! ✗');
        process.exit(1);
    }
}

main();