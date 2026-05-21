import mongoose, { Schema, Document } from 'mongoose';

export interface IReminder extends Document {
  partyId: string;
  partyName: string;
  partyPhone: string;
  title: string;
  note: string;
  date: Date;
  status: string;
  createdAt: Date;
  updatedAt: Date;
}

const ReminderSchema: Schema = new Schema({
  partyId: { type: String, default: '' },
  partyName: { type: String, default: '' },
  partyPhone: { type: String, default: '' },
  title: { type: String, required: true },
  note: { type: String, default: '' },
  date: { type: Date, required: true },
  status: { type: String, default: 'upcoming' },
}, {
  timestamps: true
});

export const Reminder = mongoose.model<IReminder>('Reminder', ReminderSchema);
