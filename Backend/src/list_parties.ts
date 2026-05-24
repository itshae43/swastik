import mongoose from 'mongoose';
import dotenv from 'dotenv';
import dns from 'dns';
import { Party } from './models/Party';

dns.setServers(['8.8.8.8', '1.1.1.1']);
dotenv.config();

const MONGO_URI = process.env.MONGO_URI || '';

async function run() {
  console.log('Connecting to database...');
  await mongoose.connect(MONGO_URI);
  console.log('Connected.');

  console.log('Fetching parties...');
  const parties = await Party.find().sort({ name: 1 });
  console.log(`Found ${parties.length} parties:`);
  
  parties.forEach((p, idx) => {
    console.log(`${idx + 1}. Name: "${p.name}" | Cash Balance: ${p.cashBalance} | Gold Balance (g): ${p.goldBalanceGrams} | Silver Balance (g): ${p.silverBalanceGrams} | Diamond Balance (carats): ${p.diamondBalanceCarats} | ID: ${p._id}`);
  });

  await mongoose.disconnect();
  console.log('Disconnected.');
}

run().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
