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
  const isDryRun = process.argv.includes('--dry-run');
  if (isDryRun) {
    console.log('=========================================');
    console.log('            DRY RUN ENABLED              ');
    console.log(' (No writes will be made to the database)');
    console.log('=========================================');
  } else {
    console.log('=========================================');
    console.log('           LIVE RUN - WRITING            ');
    console.log('=========================================');
  }

  console.log('Connecting to database...');
  await mongoose.connect(MONGO_URI);
  console.log('Connected successfully.');

  // Load JSON transactions
  const jsonPath = path.join(__dirname, '../transactions_to_import.json');
  if (!fs.existsSync(jsonPath)) {
    console.error(`Error: JSON file not found at ${jsonPath}. Run Python parser first.`);
    process.exit(1);
  }

  const transactionsData: ExcelTransaction[] = JSON.parse(fs.readFileSync(jsonPath, 'utf-8'));
  console.log(`Loaded ${transactionsData.length} transactions from JSON.`);

  // Load all parties from database to match and keep in-memory cache of balances
  console.log('Fetching existing parties from database...');
  const allParties = await Party.find();
  const partyMap = new Map<string, typeof allParties[0]>();
  
  // Normalize names for lookup (trim, case-insensitive comparison)
  allParties.forEach(p => {
    partyMap.set(p.name.trim().toLowerCase(), p);
  });

  console.log(`Cached ${partyMap.size} parties for mapping.`);

  // Tracking counts
  let successCount = 0;
  let errorCount = 0;
  let cashTxCount = 0;
  let goldTxCount = 0;
  let diamondTxCount = 0;

  // Track modified party balances in-memory
  const modifiedBalances = new Map<string, {
    originalCash: number;
    newCash: number;
    originalGold: number;
    newGold: number;
    originalDiamond: number;
    newDiamond: number;
    partyId: string;
  }>();

  for (const txn of transactionsData) {
    const key = txn.partyName.trim().toLowerCase();
    const party = partyMap.get(key);

    if (!party) {
      console.error(`Error: Row Index ${txn.excelRowIndex} (Sr. No. ${txn.srNo}) - Customer Name "${txn.partyName}" not found in database!`);
      errorCount++;
      continue;
    }

    // Initialize tracking for this party if not done yet
    if (!modifiedBalances.has(party.id)) {
      modifiedBalances.set(party.id, {
        originalCash: party.cashBalance,
        newCash: party.cashBalance,
        originalGold: party.goldBalanceGrams,
        newGold: party.goldBalanceGrams,
        originalDiamond: party.diamondBalanceCarats,
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
      cashTxCount++;
    } else if (txn.metalType === 'gold') {
      // Gold
      if (isDebit) balanceInfo.newGold += txn.metalWeight;
      if (isCredit) balanceInfo.newGold -= txn.metalWeight;
      goldTxCount++;
    } else if (txn.metalType === 'diamond') {
      // Diamond
      if (isDebit) balanceInfo.newDiamond += txn.metalWeight;
      if (isCredit) balanceInfo.newDiamond -= txn.metalWeight;
      diamondTxCount++;
    }

    if (!isDryRun) {
      // Insert Transaction Document
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
    }

    successCount++;
  }

  console.log('\n=========================================');
  console.log('             SUMMARY OF DATA             ');
  console.log(`Total transactions processed: ${successCount}`);
  console.log(`Total errors: ${errorCount}`);
  console.log(`- Cash/Online transactions: ${cashTxCount}`);
  console.log(`- Gold transactions: ${goldTxCount}`);
  console.log(`- Diamond transactions: ${diamondTxCount}`);
  console.log('=========================================\n');

  if (errorCount > 0) {
    console.error('CRITICAL ERROR: Some customer names could not be matched. Fix them before running live.');
    if (!isDryRun) {
      console.error('Aborting. Transaction documents saved so far will not be deleted automatically, please verify.');
    }
    await mongoose.disconnect();
    process.exit(1);
  }

  // Update customer balances in database
  if (!isDryRun) {
    console.log('Updating customer balances in database...');
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
  } else {
    console.log('DRY RUN: Showing sample balance updates (top 15 modified):');
    let count = 0;
    for (const [partyId, balanceInfo] of modifiedBalances.entries()) {
      const party = allParties.find(p => p.id === partyId)!;
      console.log(`* Party: "${party.name}"`);
      if (balanceInfo.originalCash !== balanceInfo.newCash) {
        console.log(`  - Cash Balance: ${balanceInfo.originalCash} -> ${balanceInfo.newCash}`);
      }
      if (balanceInfo.originalGold !== balanceInfo.newGold) {
        console.log(`  - Gold Balance (g): ${balanceInfo.originalGold} -> ${balanceInfo.newGold}`);
      }
      if (balanceInfo.originalDiamond !== balanceInfo.newDiamond) {
        console.log(`  - Diamond Balance (ct): ${balanceInfo.originalDiamond} -> ${balanceInfo.newDiamond}`);
      }
      count++;
      if (count >= 15) break;
    }
  }

  await mongoose.disconnect();
  console.log('Disconnected.');
}

run().catch(err => {
  console.error('Fatal Error:', err);
  process.exit(1);
});
