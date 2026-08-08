const fs = require('fs');
const path = require('path');

function generateSmallJson() {
    return JSON.stringify({
        name: "John Doe",
        age: 30,
        active: true,
        email: "john@example.com"
    });
}

function generateMediumJson() {
    const obj = {
        users: [],
        metadata: {
            version: "1.0.0",
            generated: new Date().toISOString()
        }
    };
    
    for (let i = 0; i < 100; i++) {
        obj.users.push({
            id: i,
            name: `User ${i}`,
            email: `user${i}@example.com`,
            tags: ["tag1", "tag2", "tag3"],
            profile: {
                age: 20 + (i % 50),
                location: "City",
                active: i % 2 === 0
            }
        });
    }
    
    return JSON.stringify(obj);
}

function generateLargeJson() {
    const obj = {
        data: [],
        nested: {}
    };
    
    for (let i = 0; i < 1000; i++) {
        obj.data.push({
            id: i,
            values: Array(10).fill(0).map((_, j) => i * 10 + j),
            metadata: {
                created: new Date().toISOString(),
                updated: new Date().toISOString(),
                tags: Array(5).fill(0).map((_, j) => `tag-${i}-${j}`)
            }
        });
    }
    
    for (let i = 0; i < 100; i++) {
        obj.nested[`level${i}`] = {
            data: Array(10).fill(0).map((_, j) => `item-${i}-${j}`),
            children: {}
        };
        
        for (let j = 0; j < 10; j++) {
            obj.nested[`level${i}`].children[`child${j}`] = {
                value: j,
                active: j % 2 === 0
            };
        }
    }
    
    return JSON.stringify(obj);
}

function benchmark(jsonStr, name, iterations = 1000) {
    const sizeKB = Buffer.byteLength(jsonStr, 'utf8') / 1024;
    
    console.log(`\n=== ${name} (${sizeKB.toFixed(2)} KB) ===`);
    
    const start = process.hrtime.bigint();
    
    for (let i = 0; i < iterations; i++) {
        JSON.parse(jsonStr);
    }
    
    const end = process.hrtime.bigint();
    const elapsedNs = Number(end - start);
    const elapsedMs = elapsedNs / 1e6;
    
    const throughput = (sizeKB * iterations / 1024) / (elapsedMs / 1000);
    const opsPerSec = iterations / (elapsedMs / 1000);
    
    console.log(`  Iterations: ${iterations}`);
    console.log(`  Total time: ${elapsedMs.toFixed(2)} ms`);
    console.log(`  Avg time: ${(elapsedMs / iterations).toFixed(4)} ms/op`);
    console.log(`  Throughput: ${throughput.toFixed(2)} MB/s`);
    console.log(`  Ops/sec: ${opsPerSec.toFixed(0)}`);
    
    return {
        name,
        sizeKB,
        iterations,
        elapsedMs,
        throughput,
        opsPerSec
    };
}

function benchmarkStringParsing() {
    console.log('\n=== String Parsing Benchmark ===');
    
    const strings = [
        { name: 'simple', str: '"hello world"' },
        { name: 'escaped', str: '"hello\\nworld\\ttab"' },
        { name: 'unicode', str: '"\\u4e2d\\u6587\\u5b57\\u7b26"' },
        { name: 'emoji', str: '"\\uD83D\\uDE00\\uD83D\\uDC95"' },
        { name: 'long', str: '"' + 'x'.repeat(1000) + '"' }
    ];
    
    const iterations = 10000;
    
    for (const { name, str } of strings) {
        const start = process.hrtime.bigint();
        
        for (let i = 0; i < iterations; i++) {
            JSON.parse(str);
        }
        
        const end = process.hrtime.bigint();
        const elapsedMs = Number(end - start) / 1e6;
        
        console.log(`  ${name}: ${(elapsedMs / iterations).toFixed(6)} ms/op`);
    }
}

function benchmarkNumberParsing() {
    console.log('\n=== Number Parsing Benchmark ===');
    
    const numbers = [
        { name: 'integer', str: '42' },
        { name: 'negative', str: '-12345' },
        { name: 'float', str: '3.14159265358979' },
        { name: 'scientific', str: '1.5e10' },
        { name: 'small', str: '0.0000001' },
        { name: 'large', str: '12345678901234567890' }
    ];
    
    const iterations = 10000;
    
    for (const { name, str } of numbers) {
        const start = process.hrtime.bigint();
        
        for (let i = 0; i < iterations; i++) {
            JSON.parse(str);
        }
        
        const end = process.hrtime.bigint();
        const elapsedMs = Number(end - start) / 1e6;
        
        console.log(`  ${name}: ${(elapsedMs / iterations).toFixed(6)} ms/op`);
    }
}

function generateTestFiles() {
    const benchmarkDir = path.join(__dirname, '..', 'tests', 'benchmark');
    
    if (!fs.existsSync(benchmarkDir)) {
        fs.mkdirSync(benchmarkDir, { recursive: true });
    }
    
    console.log('\n=== Generating Test Files ===');
    
    const files = [
        { name: 'small.json', data: generateSmallJson() },
        { name: 'medium.json', data: generateMediumJson() },
        { name: 'large.json', data: generateLargeJson() }
    ];
    
    for (const { name, data } of files) {
        const filepath = path.join(benchmarkDir, name);
        fs.writeFileSync(filepath, data);
        const sizeKB = Buffer.byteLength(data, 'utf8') / 1024;
        console.log(`  ${name}: ${sizeKB.toFixed(2)} KB`);
    }
}

function main() {
    console.log('=== JSON Parser Performance Benchmark ===\n');
    
    console.log('Node.js version:', process.version);
    console.log('Platform:', process.platform);
    console.log('Architecture:', process.arch);
    
    generateTestFiles();
    
    benchmark(generateSmallJson(), 'Small JSON', 10000);
    benchmark(generateMediumJson(), 'Medium JSON', 1000);
    benchmark(generateLargeJson(), 'Large JSON', 100);
    
    benchmarkStringParsing();
    benchmarkNumberParsing();
    
    console.log('\n=== Benchmark Complete ===');
}

main();