import mongoose from 'mongoose';
import dotenv from 'dotenv';
import dns from 'dns';
import * as fs from 'fs';
import * as path from 'path';
import { Party } from './models/Party';

dns.setServers(['8.8.8.8', '1.1.1.1']);
dotenv.config();

const MONGO_URI = process.env.MONGO_URI || '';

async function run() {
  console.log('Connecting to database...');
  await mongoose.connect(MONGO_URI);
  console.log('Connected.');

  console.log('Fetching parties...');
  const parties = await Party.find().select('name _id cashBalance goldBalanceGrams silverBalanceGrams diamondBalanceCarats');
  
  const outputData = parties.map(p => ({
    id: p._id.toString(),
    name: p.name,
    cashBalance: p.cashBalance,
    goldBalance: p.goldBalanceGrams,
    silverBalance: p.silverBalanceGrams,
    diamondBalance: p.diamondBalanceCarats
  }));

  const outputPath = path.join(__dirname, 'parties.json');
  fs.writeFileSync(outputPath, JSON.stringify(outputData, null, 2));
  console.log(`Saved ${outputData.length} parties to ${outputPath}`);

  await mongoose.disconnect();
}

run().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
