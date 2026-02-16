#!/usr/bin/env node

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const RUNTIME_DIR = path.join(__dirname, '..', 'runtime');

function postinstall() {
  console.log('\n📦 @opencangjie/skills installed successfully!\n');
  
  if (!fs.existsSync(RUNTIME_DIR)) {
    fs.mkdirSync(RUNTIME_DIR, { recursive: true });
  }
  
  console.log('To get started:\n');
  console.log('  1. Install the runtime:');
  console.log('     npx skills install-runtime\n');
  console.log('  2. Start the runtime:');
  console.log('     npx skills start\n');
  console.log('  3. Or connect to an existing runtime:');
  console.log('     npx skills status\n');
  console.log('Documentation: https://github.com/UCTooCom/agentskills-runtime\n');
}

postinstall();
