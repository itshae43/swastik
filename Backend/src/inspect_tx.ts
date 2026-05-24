import mongoose from 'mongoose';
import dotenv from 'dotenv';
import dns from 'dns';
import { Transaction } from './models/Transaction';

dns.setServers(['8.8.8.8', '1.1.1.1']);
dotenv.config();

const MONGO_URI = process.env.MONGO_URI || '';

async function run() {
  await mongoose.connect(MONGO_URI);
  
  const total = await Transaction.countDocuments();
  console.log(`Total transactions in DB: ${total}`);

  // Count created today (May 24, 2026)
  const todayStart = new Date();
  todayStart.setHours(0, 0, 0, 0);
  
  const createdToday = await Transaction.countDocuments({ createdAt: { $gte: todayStart } });
  console.log(`Transactions created today: ${createdToday}`);
  
  const createdBefore = await Transaction.countDocuments({ createdAt: { $lt: todayStart } });
  console.log(`Transactions created before today: ${createdBefore}`);

  await mongoose.disconnect();
}

run().catch(err => {
  console.error(err);
  process.exit(1);
});
