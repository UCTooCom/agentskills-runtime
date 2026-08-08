const fs = require('fs');
const path = require('path');

class PerformanceBenchmark {
    constructor() {
        this.results = [];
    }

    generateTestData() {
        return {
            small: this.generateSmallJson(),
            medium: this.generateMediumJson(),
            large: this.generateLargeJson(),
            deepNested: this.generateDeepNested(),
            wideArray: this.generateWideArray(),
            stringHeavy: this.generateStringHeavy(),
            numberHeavy: this.generateNumberHeavy()
        };
    }

    generateSmallJson() {
        return JSON.stringify({
            name: "John Doe",
            age: 30,
            active: true,
            email: "john@example.com"
        });
    }

    generateMediumJson() {
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

    generateLargeJson() {
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

    generateDeepNested() {
        let result = { value: 0 };
        let current = result;
        
        for (let i = 0; i < 50; i++) {
            current.nested = { value: i + 1 };
            current = current.nested;
        }
        
        return JSON.stringify(result);
    }

    generateWideArray() {
        const arr = [];
        for (let i = 0; i < 10000; i++) {
            arr.push({ id: i, value: `item${i}` });
        }
        return JSON.stringify(arr);
    }

    generateStringHeavy() {
        const obj = {};
        for (let i = 0; i < 100; i++) {
            obj[`key${i}`] = "This is a longer string value that contains multiple words and characters to test string parsing performance. ".repeat(5);
        }
        return JSON.stringify(obj);
    }

    generateNumberHeavy() {
        const arr = [];
        for (let i = 0; i < 10000; i++) {
            arr.push({
                integer: i,
                float: i * 3.14159,
                scientific: i * 1.5e10,
                negative: -i
            });
        }
        return JSON.stringify(arr);
    }

    measureTime(fn, iterations = 100) {
        const times = [];
        
        for (let i = 0; i < iterations; i++) {
            const start = process.hrtime.bigint();
            fn();
            const end = process.hrtime.bigint();
            times.push(Number(end - start) / 1e6);
        }
        
        return {
            min: Math.min(...times),
            max: Math.max(...times),
            avg: times.reduce((a, b) => a + b, 0) / times.length,
            median: times.sort((a, b) => a - b)[Math.floor(times.length / 2)],
            p95: times.sort((a, b) => a - b)[Math.floor(times.length * 0.95)]
        };
    }

    measureMemory(fn) {
        if (global.gc) global.gc();
        
        const before = process.memoryUsage();
        fn();
        const after = process.memoryUsage();
        
        return {
            heapUsed: (after.heapUsed - before.heapUsed) / 1024,
            heapTotal: (after.heapTotal - before.heapTotal) / 1024,
            external: (after.external - before.external) / 1024
        };
    }

    runBenchmark(name, jsonStr, iterations = 100) {
        const sizeKB = Buffer.byteLength(jsonStr, 'utf8') / 1024;
        
        console.log(`\n=== ${name} (${sizeKB.toFixed(2)} KB) ===`);
        
        const parseTime = this.measureTime(() => JSON.parse(jsonStr), iterations);
        const stringifyTime = this.measureTime(() => JSON.stringify(JSON.parse(jsonStr)), iterations);
        
        const throughput = (sizeKB / 1024) / (parseTime.avg / 1000);
        const opsPerSec = 1000 / parseTime.avg;
        
        const result = {
            name,
            sizeKB,
            iterations,
            parseTime,
            stringifyTime,
            throughput,
            opsPerSec
        };
        
        this.results.push(result);
        
        console.log(`  Parse Time:`);
        console.log(`    Min: ${parseTime.min.toFixed(4)} ms`);
        console.log(`    Max: ${parseTime.max.toFixed(4)} ms`);
        console.log(`    Avg: ${parseTime.avg.toFixed(4)} ms`);
        console.log(`    Median: ${parseTime.median.toFixed(4)} ms`);
        console.log(`    P95: ${parseTime.p95.toFixed(4)} ms`);
        console.log(`  Throughput: ${throughput.toFixed(2)} MB/s`);
        console.log(`  Ops/sec: ${opsPerSec.toFixed(0)}`);
        
        return result;
    }

    runAllBenchmarks() {
        console.log('=== JSON Parser Performance Benchmark ===\n');
        console.log(`Node.js: ${process.version}`);
        console.log(`Platform: ${process.platform} ${process.arch}`);
        console.log(`CPU: ${require('os').cpus()[0].model}`);
        console.log(`Memory: ${(require('os').totalmem() / 1024 / 1024 / 1024).toFixed(1)} GB\n`);
        
        const testData = this.generateTestData();
        
        this.runBenchmark('Small JSON', testData.small, 10000);
        this.runBenchmark('Medium JSON', testData.medium, 1000);
        this.runBenchmark('Large JSON', testData.large, 100);
        this.runBenchmark('Deep Nested', testData.deepNested, 1000);
        this.runBenchmark('Wide Array', testData.wideArray, 100);
        this.runBenchmark('String Heavy', testData.stringHeavy, 500);
        this.runBenchmark('Number Heavy', testData.numberHeavy, 100);
        
        this.printSummary();
    }

    printSummary() {
        console.log('\n=== Performance Summary ===\n');
        console.log('| Test | Size (KB) | Avg Time (ms) | Throughput (MB/s) | Ops/sec |');
        console.log('|------|-----------|---------------|-------------------|---------|');
        
        for (const r of this.results) {
            console.log(`| ${r.name.padEnd(15)} | ${r.sizeKB.toFixed(2).padStart(9)} | ${r.parseTime.avg.toFixed(4).padStart(13)} | ${r.throughput.toFixed(2).padStart(17)} | ${r.opsPerSec.toFixed(0).padStart(7)} |`);
        }
        
        const avgThroughput = this.results.reduce((a, b) => a + b.throughput, 0) / this.results.length;
        console.log(`\nAverage Throughput: ${avgThroughput.toFixed(2)} MB/s`);
    }

    generateReport() {
        const report = {
            timestamp: new Date().toISOString(),
            environment: {
                nodeVersion: process.version,
                platform: process.platform,
                arch: process.arch,
                cpu: require('os').cpus()[0].model,
                memory: require('os').totalmem()
            },
            results: this.results.map(r => ({
                name: r.name,
                sizeKB: r.sizeKB,
                parseTime: r.parseTime,
                throughput: r.throughput,
                opsPerSec: r.opsPerSec
            }))
        };
        
        return report;
    }
}

function runDetailedAnalysis() {
    console.log('\n=== Detailed Analysis ===\n');
    
    const sizes = [100, 500, 1000, 5000, 10000];
    
    console.log('| Size (bytes) | Parse Time (ms) | Throughput (MB/s) |');
    console.log('|--------------|-----------------|-------------------|');
    
    for (const size of sizes) {
        const json = JSON.stringify({
            data: Array(size).fill(0).map((_, i) => ({ id: i, value: `item${i}` }))
        });
        
        const start = process.hrtime.bigint();
        JSON.parse(json);
        const end = process.hrtime.bigint();
        
        const timeMs = Number(end - start) / 1e6;
        const sizeKB = Buffer.byteLength(json, 'utf8') / 1024;
        const throughput = (sizeKB / 1024) / (timeMs / 1000);
        
        console.log(`| ${size.toString().padStart(12)} | ${timeMs.toFixed(4).padStart(15)} | ${throughput.toFixed(2).padStart(17)} |`);
    }
}

function runMemoryAnalysis() {
    console.log('\n=== Memory Analysis ===\n');
    
    const sizes = [
        { name: '10KB', count: 200 },
        { name: '100KB', count: 2000 },
        { name: '500KB', count: 10000 },
        { name: '1MB', count: 20000 }
    ];
    
    console.log('| Size | Heap Used (KB) | Heap Total (KB) | Ratio |');
    console.log('|------|----------------|-----------------|-------|');
    
    for (const { name, count } of sizes) {
        const json = JSON.stringify({
            data: Array(count).fill(0).map((_, i) => ({ id: i, value: `item${i}` }))
        });
        
        if (global.gc) global.gc();
        const before = process.memoryUsage();
        
        const parsed = JSON.parse(json);
        
        const after = process.memoryUsage();
        
        const heapUsed = (after.heapUsed - before.heapUsed) / 1024;
        const heapTotal = (after.heapTotal - before.heapTotal) / 1024;
        const jsonSize = Buffer.byteLength(json, 'utf8') / 1024;
        const ratio = heapUsed / jsonSize;
        
        console.log(`| ${name.padEnd(4)} | ${heapUsed.toFixed(0).padStart(14)} | ${heapTotal.toFixed(0).padStart(15)} | ${ratio.toFixed(2).padStart(5)} |`);
    }
}

function main() {
    const benchmark = new PerformanceBenchmark();
    benchmark.runAllBenchmarks();
    
    runDetailedAnalysis();
    runMemoryAnalysis();
    
    const report = benchmark.generateReport();
    const reportPath = path.join(__dirname, '..', 'tests', 'benchmark', 'performance_report.json');
    
    const benchmarkDir = path.dirname(reportPath);
    if (!fs.existsSync(benchmarkDir)) {
        fs.mkdirSync(benchmarkDir, { recursive: true });
    }
    
    fs.writeFileSync(reportPath, JSON.stringify(report, null, 2));
    console.log(`\nReport saved to: ${reportPath}`);
}

main();