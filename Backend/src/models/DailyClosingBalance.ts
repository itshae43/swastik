import mongoose, { Schema, Document } from 'mongoose';

export interface IDailyClosingBalance extends Document {
  date: string; // Format: YYYY-MM-DD
  closingCash: number;
  closingOnline: number;
  closingGold: number;
  closingDiamond: number;
  createdAt: Date;
  updatedAt: Date;
}

const DailyClosingBalanceSchema: Schema = new Schema({
  date: { type: String, required: true, unique: true }, // Format: YYYY-MM-DD
  closingCash: { type: Number, default: 0 },
  closingOnline: { type: Number, default: 0 },
  closingGold: { type: Number, default: 0 },
  closingDiamond: { type: Number, default: 0 },
}, {
  timestamps: true
});

export const DailyClosingBalance = mongoose.model<IDailyClosingBalance>('DailyClosingBalance', DailyClosingBalanceSchema);
