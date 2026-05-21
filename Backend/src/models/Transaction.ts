import mongoose, { Schema, Document } from 'mongoose';

export interface ITransaction extends Document {
  partyId: string;
  partyName: string;
  partyPhone: string;
  type: string;
  paymentMode: string;
  cashAmount: number;
  metalType: string;
  metalWeight: number;
  metalPurity: string;
  notes: string;
  date: Date;
  createdAt: Date;
  updatedAt: Date;
}

const TransactionSchema: Schema = new Schema({
  partyId: { type: String, required: true },
  partyName: { type: String, default: '' },
  partyPhone: { type: String, default: '' },
  type: { type: String, required: true },
  paymentMode: { type: String, required: true },
  cashAmount: { type: Number, default: 0 },
  metalType: { type: String, default: '' },
  metalWeight: { type: Number, default: 0 },
  metalPurity: { type: String, default: '' },
  notes: { type: String, default: '' },
  date: { type: Date, default: Date.now },
}, {
  timestamps: true
});

export const Transaction = mongoose.model<ITransaction>('Transaction', TransactionSchema);
