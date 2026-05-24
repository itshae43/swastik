import mongoose from 'mongoose';
import dotenv from 'dotenv';
import dns from 'dns';
import * as fs from 'fs';
import * as path from 'path';
import { Party } from './models/Party';
import { Transaction } from './models/Transaction';

dns.setServers(['8.8.8.8', '1.1.1.1']);
dotenv.config();

const MONGO_URI = process.env.MONGO_URI || '';

interface ExcelTransaction {
  srNo: number | null;
  excelRowIndex: number;
  partyName: string;
  notes: string;
  date: string;
  cashAmount: number;
  metalWeight: number;
  metalType: string;
  metalPurity: string;
  paymentMode: string;
  type: string;
}

async function run() {
  console.log('Connecting to database...');
  await mongoose.connect(MONGO_URI);
  console.log('Connected successfully.');

  // Delete all existing transactions from DB (since they were all created today during first import)
  console.log('Clearing all existing transactions from database...');
  const deleteResult = await Transaction.deleteMany({});
  console.log(`Successfully deleted ${deleteResult.deletedCount} transactions.`);

  // Load JSON transactions
  const jsonPath = path.join(__dirname, '../transactions_to_import.json');
  if (!fs.existsSync(jsonPath)) {
    console.error(`Error: JSON file not found at ${jsonPath}. Run Python parser first.`);
    process.exit(1);
  }

  const transactionsData: ExcelTransaction[] = JSON.parse(fs.readFileSync(jsonPath, 'utf-8'));
  console.log(`Loaded ${transactionsData.length} transactions from JSON.`);

  // Cache all parties for ID lookup
  console.log('Fetching parties from database...');
  const allParties = await Party.find();
  const partyMap = new Map<string, typeof allParties[0]>();
  allParties.forEach(p => {
    partyMap.set(p.name.trim().toLowerCase(), p);
  });

  console.log('Inserting transactions sequentially with updated times...');
  let successCount = 0;
  let errorCount = 0;

  for (const txn of transactionsData) {
    const key = txn.partyName.trim().toLowerCase();
    const party = partyMap.get(key);

    if (!party) {
      console.error(`Error: Row Index ${txn.excelRowIndex} (Sr. No. ${txn.srNo}) - Customer Name "${txn.partyName}" not found in database!`);
      errorCount++;
      continue;
    }

    const dbTxn = new Transaction({
      partyId: party.id,
      partyName: party.name,
      partyPhone: party.phone || '',
      type: txn.type,
      paymentMode: txn.paymentMode,
      cashAmount: txn.cashAmount,
      metalType: txn.metalType,
      metalWeight: txn.metalWeight,
      metalPurity: txn.metalPurity,
      notes: txn.notes,
      date: new Date(txn.date)
    });
    
    await dbTxn.save();
    successCount++;
  }

  console.log('=========================================');
  console.log(`Successfully imported ${successCount} transactions with corrected dates/times.`);
  console.log(`Errors encountered: ${errorCount}`);
  console.log('=========================================');

  await mongoose.disconnect();
  console.log('Disconnected.');
}

run().catch(err => {
  console.error('Fatal Error:', err);
  process.exit(1);
});
