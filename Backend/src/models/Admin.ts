import { Schema, model } from 'mongoose';

export interface IAdmin {
  brand: string;
  model: string;
  androidId: string;
  createdAt?: Date;
}

const adminSchema = new Schema<IAdmin>(
  {
    brand: { type: String, required: true },
    model: { type: String, required: true },
    androidId: { type: String, required: true, unique: true },
  },
  {
    timestamps: true,
  }
);

export const Admin = model<IAdmin>('Admin', adminSchema);
