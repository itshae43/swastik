import mongoose, { Schema, Document } from 'mongoose';

export interface IAppointment extends Document {
  customerName: string;
  phoneNumber: string;
  date: Date;
  notes: string;
  remindBefore: boolean;
  status: string;
  createdAt: Date;
  updatedAt: Date;
}

const AppointmentSchema: Schema = new Schema({
  customerName: { type: String, required: true },
  phoneNumber: { type: String, default: '' },
  date: { type: Date, required: true },
  notes: { type: String, default: '' },
  remindBefore: { type: Boolean, default: false },
  status: { type: String, default: 'upcoming' },
}, {
  timestamps: true
});

export const Appointment = mongoose.model<IAppointment>('Appointment', AppointmentSchema);
