/**
 * Bcryptjs 测试数据生成器
 * 
 * 用于生成 bcryptjs 的测试数据，以验证仓颉实现的兼容性
 * 
 * 使用方法:
 *   node test_bcryptjs_compatibility.js
 */

const bcrypt = require('bcryptjs');

async function generateTestData() {
    console.log('=== Bcryptjs 测试数据生成 ===\n');
    
    const testCases = [
        'UCToo123',
        'password123',
        'admin',
        '',
        'ThisIsAVeryLongPasswordThatExceedsTheTypicalLengthLimit1234567890!@#$%^&*()',
        'P@ssw0rd!#$%^&*()_+-=[]{}|;\':",./<>?',
        '密码测试123'
    ];
    
    const results = [];
    
    for (const password of testCases) {
        console.log(`密码: "${password}"`);
        
        // 生成 cost=10 的哈希
        const hash10 = await bcrypt.hash(password, 10);
        console.log(`  Hash (cost=10): ${hash10}`);
        
        // 验证
        const verify = await bcrypt.compare(password, hash10);
        console.log(`  验证: ${verify}`);
        
        // 生成 cost=4 的哈希（用于测试不同 cost）
        const hash4 = await bcrypt.hash(password, 4);
        console.log(`  Hash (cost=4): ${hash4}`);
        
        // 生成 cost=12 的哈希
        const hash12 = await bcrypt.hash(password, 12);
        console.log(`  Hash (cost=12): ${hash12}`);
        
        console.log();
        
        results.push({
            password,
            hash10,
            hash4,
            hash12,
            verify
        });
    }
    
    // 输出 JSON 格式的测试数据
    console.log('\n=== JSON 格式测试数据 ===\n');
    console.log(JSON.stringify(results, null, 2));
    
    // 输出仓颉测试代码
    console.log('\n=== 仓颉测试代码 ===\n');
    console.log('// 将以下代码添加到 bcrypt_test.cj 中进行验证');
    console.log('');
    
    for (const result of results) {
        console.log(`// 密码: "${result.password}"`);
        console.log(`let hash_${result.password.replace(/[^a-zA-Z0-9]/g, '_')} = "${result.hash10}";`);
        console.log(`let verify_${result.password.replace(/[^a-zA-Z0-9]/g, '_')} = Bcrypt.verify("${result.password}", hash_${result.password.replace(/[^a-zA-Z0-9]/g, '_')});`);
        console.log(`println("验证 '${result.password}': \${verify_${result.password.replace(/[^a-zA-Z0-9]/g, '_')}}");`);
        console.log('');
    }
}

// 运行测试
generateTestData().catch(console.error);
