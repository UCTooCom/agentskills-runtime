const fs = require('fs');

function generateMediumJson() {
    let result = '{"users":[';
    for (let i = 0; i < 100; i++) {
        if (i > 0) result += ',';
        result += `{"id":${i},"name":"User${i}","active":true,"score":${i * 1.5}}`;
    }
    return result + '],"count":100}';
}

function generateLargeJson() {
    let result = '{"data":[';
    for (let i = 0; i < 1000; i++) {
        if (i > 0) result += ',';
        result += `{"id":${i},"value":${i},"nested":{"a":1,"b":2}}`;
    }
    return result + '],"count":1000}';
}

function traverseAll(value) {
    let count = 0;
    if (Array.isArray(value)) {
        for (const item of value) {
            count += 1;
            count += traverseAll(item);
        }
    } else if (typeof value === 'object' && value !== null) {
        for (const key in value) {
            count += 1;
            count += traverseAll(value[key]);
        }
    }
    return count;
}

function getFirstUserName(value) {
    if (typeof value === 'object' && value !== null && 'users' in value && Array.isArray(value.users)) {
        if (value.users.length > 0) {
            const user = value.users[0];
            if (typeof user === 'object' && user !== null && 'name' in user) {
                return user.name;
            }
        }
    }
    return '';
}

console.log('=== Node.js JSON 解析器基准测试 ===\n');

const smallJson = '{"name":"John","age":30,"active":true,"email":"john@example.com","nested":{"a":1,"b":2}}';
const mediumJson = generateMediumJson();
const largeJson = generateLargeJson();

console.log(`Small: ${smallJson.length}B`);
console.log(`Medium: ${mediumJson.length}B`);
console.log(`Large: ${largeJson.length}B\n`);

// Parse benchmark
console.log('=== 解析性能测试 ===\n');

let start = Date.now();
let iterations = 10000;
for (let i = 0; i < iterations; i++) {
    JSON.parse(smallJson);
}
let timeSmall = Date.now() - start;
let mbPerSec = (smallJson.length * iterations) / (timeSmall / 1000) / (1024 * 1024);
console.log(`Small JSON (${smallJson.length}B x ${iterations}): ${timeSmall}ms (${mbPerSec.toFixed(2)} MB/s)`);

start = Date.now();
iterations = 3000;
for (let i = 0; i < iterations; i++) {
    JSON.parse(mediumJson);
}
let timeMedium = Date.now() - start;
mbPerSec = (mediumJson.length * iterations) / (timeMedium / 1000) / (1024 * 1024);
console.log(`Medium JSON (${mediumJson.length}B x ${iterations}): ${timeMedium}ms (${mbPerSec.toFixed(2)} MB/s)`);

start = Date.now();
iterations = 200;
for (let i = 0; i < iterations; i++) {
    JSON.parse(largeJson);
}
let timeLarge = Date.now() - start;
mbPerSec = (largeJson.length * iterations) / (timeLarge / 1000) / (1024 * 1024);
console.log(`Large JSON (${largeJson.length}B x ${iterations}): ${timeLarge}ms (${mbPerSec.toFixed(2)} MB/s)`);

console.log('\n=== 遍历所有节点 ===\n');

start = Date.now();
iterations = 10000;
let count = 0;
for (let i = 0; i < iterations; i++) {
    const v = JSON.parse(smallJson);
    count = traverseAll(v);
}
timeSmall = Date.now() - start;
mbPerSec = (smallJson.length * iterations) / (timeSmall / 1000) / (1024 * 1024);
console.log(`Small JSON + Traverse (${smallJson.length}B x ${iterations}): ${timeSmall}ms (${mbPerSec.toFixed(2)} MB/s)`);

start = Date.now();
iterations = 2000;
for (let i = 0; i < iterations; i++) {
    const v = JSON.parse(mediumJson);
    count = traverseAll(v);
}
timeMedium = Date.now() - start;
mbPerSec = (mediumJson.length * iterations) / (timeMedium / 1000) / (1024 * 1024);
console.log(`Medium JSON + Traverse (${mediumJson.length}B x ${iterations}): ${timeMedium}ms (${mbPerSec.toFixed(2)} MB/s)`);

start = Date.now();
iterations = 100;
for (let i = 0; i < iterations; i++) {
    const v = JSON.parse(largeJson);
    count = traverseAll(v);
}
timeLarge = Date.now() - start;
mbPerSec = (largeJson.length * iterations) / (timeLarge / 1000) / (1024 * 1024);
console.log(`Large JSON + Traverse (${largeJson.length}B x ${iterations}): ${timeLarge}ms (${mbPerSec.toFixed(2)} MB/s)`);

console.log('\n=== 部分访问 (首用户名称) ===\n');

start = Date.now();
iterations = 10000;
let name = '';
for (let i = 0; i < iterations; i++) {
    const v = JSON.parse(smallJson);
    name = getFirstUserName(v);
}
timeSmall = Date.now() - start;
mbPerSec = (smallJson.length * iterations) / (timeSmall / 1000) / (1024 * 1024);
console.log(`Small JSON + Partial (${smallJson.length}B x ${iterations}): ${timeSmall}ms (${mbPerSec.toFixed(2)} MB/s)`);

start = Date.now();
iterations = 3000;
for (let i = 0; i < iterations; i++) {
    const v = JSON.parse(mediumJson);
    name = getFirstUserName(v);
}
timeMedium = Date.now() - start;
mbPerSec = (mediumJson.length * iterations) / (timeMedium / 1000) / (1024 * 1024);
console.log(`Medium JSON + Partial (${mediumJson.length}B x ${iterations}): ${timeMedium}ms (${mbPerSec.toFixed(2)} MB/s)`);

start = Date.now();
iterations = 500;
for (let i = 0; i < iterations; i++) {
    const v = JSON.parse(largeJson);
    name = getFirstUserName(v);
}
timeLarge = Date.now() - start;
mbPerSec = (largeJson.length * iterations) / (timeLarge / 1000) / (1024 * 1024);
console.log(`Large JSON + Partial (${largeJson.length}B x ${iterations}): ${timeLarge}ms (${mbPerSec.toFixed(2)} MB/s)`);

console.log('\nDone!');
