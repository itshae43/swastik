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

interface JsonParty {
  id: string;
  name: string;
  cashBalance: number;
  goldBalance: number;
  silverBalance: number;
  diamondBalance: number;
}

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

function escapeRegExp(str: string) {
  return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

async function run() {
  console.log('Connecting to database...');
  await mongoose.connect(MONGO_URI);
  console.log('Connected successfully.');

  // 1. Load parties.json
  const partiesJsonPath = path.join(__dirname, 'parties.json');
  if (!fs.existsSync(partiesJsonPath)) {
    console.error(`Error: parties.json not found at ${partiesJsonPath}`);
    process.exit(1);
  }

  const partiesData: JsonParty[] = JSON.parse(fs.readFileSync(partiesJsonPath, 'utf-8'));
  console.log(`Loaded ${partiesData.length} parties from parties.json for balance reset.`);

  // 2. Reset or create all party balances in MongoDB by matching on name (case-insensitive)
  console.log('Resetting/creating all party balances in MongoDB to original base values...');
  let resetCount = 0;
  let createdCount = 0;
  for (const p of partiesData) {
    const escapedName = escapeRegExp(p.name.trim());
    let partyDoc = await Party.findOne({ name: { $regex: new RegExp('^' + escapedName + '$', 'i') } });
    
    if (!partyDoc) {
      console.log(`Party "${p.name}" not found in database. Creating it...`);
      partyDoc = new Party({
        name: p.name.trim(),
        cashBalance: p.cashBalance,
        goldBalanceGrams: p.goldBalance,
        silverBalanceGrams: p.silverBalance,
        diamondBalanceCarats: p.diamondBalance
      });
      await partyDoc.save();
      createdCount++;
    } else {
      partyDoc.cashBalance = p.cashBalance;
      partyDoc.goldBalanceGrams = p.goldBalance;
      partyDoc.silverBalanceGrams = p.silverBalance;
      partyDoc.diamondBalanceCarats = p.diamondBalance;
      await partyDoc.save();
      resetCount++;
    }
  }
  console.log(`Successfully reset balances for ${resetCount} parties and created ${createdCount} missing parties.`);

  // 3. Rename "OPENING" to "swastik jewels" in the database
  console.log('Checking for party named "OPENING"...');
  const openingParty = await Party.findOne({ name: { $regex: /^opening$/i } });
  if (openingParty) {
    console.log(`Found party "OPENING" (ID: ${openingParty._id}). Renaming to "swastik jewels"...`);
    openingParty.name = 'swastik jewels';
    await openingParty.save();
    console.log('Party renamed successfully.');
  }

  // 4. Delete all existing transactions from database
  console.log('Clearing all transactions from database...');
  const deleteResult = await Transaction.deleteMany({});
  console.log(`Successfully deleted ${deleteResult.deletedCount} transactions.`);

  // 5. Load transactions from transactions_to_import.json
  const jsonPath = path.join(__dirname, '../transactions_to_import.json');
  if (!fs.existsSync(jsonPath)) {
    console.error(`Error: JSON file not found at ${jsonPath}. Run Python parser first.`);
    process.exit(1);
  }

  const transactionsData: ExcelTransaction[] = JSON.parse(fs.readFileSync(jsonPath, 'utf-8'));
  console.log(`Loaded ${transactionsData.length} transactions from JSON.`);

  // 6. Fetch the fresh parties for matching and sequential balance updates
  const allParties = await Party.find();
  const partyMap = new Map<string, typeof allParties[0]>();
  allParties.forEach(p => {
    partyMap.set(p.name.trim().toLowerCase(), p);
  });

  // Track modified balances in-memory
  const modifiedBalances = new Map<string, {
    newCash: number;
    newGold: number;
    newDiamond: number;
    partyId: string;
  }>();

  console.log('Inserting transactions sequentially and updating party balances in-memory...');
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

    // Initialize balance tracking for this party if not tracked yet
    if (!modifiedBalances.has(party.id)) {
      modifiedBalances.set(party.id, {
        newCash: party.cashBalance,
        newGold: party.goldBalanceGrams,
        newDiamond: party.diamondBalanceCarats,
        partyId: party.id
      });
    }

    const balanceInfo = modifiedBalances.get(party.id)!;

    // Apply sequential balance updates in-memory
    const isDebit = txn.type === 'payment' || txn.type === 'metalOut';
    const isCredit = txn.type === 'receipt' || txn.type === 'metalIn';

    if (!txn.metalType) {
      // Cash
      if (isDebit) balanceInfo.newCash += txn.cashAmount;
      if (isCredit) balanceInfo.newCash -= txn.cashAmount;
    } else if (txn.metalType === 'gold') {
      // Gold
      if (isDebit) balanceInfo.newGold += txn.metalWeight;
      if (isCredit) balanceInfo.newGold -= txn.metalWeight;
    } else if (txn.metalType === 'diamond') {
      // Diamond
      if (isDebit) balanceInfo.newDiamond += txn.metalWeight;
      if (isCredit) balanceInfo.newDiamond -= txn.metalWeight;
    }

    // Save Transaction document
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

  console.log(`Successfully saved ${successCount} transactions to MongoDB.`);
  console.log(`Errors encountered during parsing/matching: ${errorCount}`);

  if (errorCount > 0) {
    console.error('CRITICAL WARNING: Missing parties matched. Fix them!');
  }

  // 7. Save the updated party balances to MongoDB
  console.log('Writing updated party balances to database...');
  let partiesUpdatedCount = 0;
  for (const [partyId, balanceInfo] of modifiedBalances.entries()) {
    await Party.findByIdAndUpdate(partyId, {
      cashBalance: balanceInfo.newCash,
      goldBalanceGrams: balanceInfo.newGold,
      diamondBalanceCarats: balanceInfo.newDiamond
    });
    partiesUpdatedCount++;
  }
  console.log(`Successfully updated balances for ${partiesUpdatedCount} parties in database.`);

  console.log('=========================================');
  console.log('         DATABASE SYNC COMPLETED         ');
  console.log('=========================================');

  await mongoose.disconnect();
  console.log('Disconnected.');
}

run().catch(err => {
  console.error('Fatal Error:', err);
  process.exit(1);
});
