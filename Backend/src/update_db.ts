import mongoose from 'mongoose';
import dotenv from 'dotenv';
import dns from 'dns';
import { Party } from './models/Party';
import { Transaction } from './models/Transaction';

dns.setServers(['8.8.8.8', '1.1.1.1']);
dotenv.config();

const MONGO_URI = process.env.MONGO_URI || '';

async function run() {
  console.log('Connecting to database...');
  await mongoose.connect(MONGO_URI);
  console.log('Connected successfully.');

  // 1. Update party name from "OPENING" to "swastik jewels"
  console.log('Checking for party named "OPENING"...');
  const openingParty = await Party.findOne({ name: { $regex: /^opening$/i } });
  
  if (openingParty) {
    console.log(`Found party: "${openingParty.name}" (ID: ${openingParty._id}). Renaming to "swastik jewels"...`);
    openingParty.name = "swastik jewels";
    await openingParty.save();
    console.log('Party renamed successfully.');
  } else {
    console.log('Party named "OPENING" not found.');
  }

  // 2. Update transaction partyNames from "OPENING" to "swastik jewels"
  console.log('Updating partyName in transactions from "OPENING" to "swastik jewels"...');
  const txNameUpdateResult = await Transaction.updateMany(
    { partyName: { $regex: /^opening$/i } },
    { $set: { partyName: "swastik jewels" } }
  );
  console.log(`Updated partyName in ${txNameUpdateResult.modifiedCount} transactions.`);

  // 3. Update transactions where metalPurity is "24K" to "100 %"
  console.log('Updating metalPurity in transactions from "24K" to "100 %"...');
  const txPurityUpdateResult = await Transaction.updateMany(
    { metalPurity: "24K" },
    { $set: { metalPurity: "100 %" } }
  );
  console.log(`Updated metalPurity in ${txPurityUpdateResult.modifiedCount} transactions.`);

  await mongoose.disconnect();
  console.log('Disconnected.');
}

run().catch(err => {
  console.error('Fatal Error:', err);
  process.exit(1);
});
