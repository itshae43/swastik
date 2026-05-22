import { Schema, model } from 'mongoose';

export interface IUserProfile {
  name: string;
  mobile: string;
  status: 'inactive' | 'pending_approval' | 'approved';
  sessionActive: boolean;
  requestPending: boolean;
  requestedAt: Date | null;
  lastApprovalTime: Date | null;
  approvedBy: string | null;
  deviceInfo: {
    deviceModel: string;
    platform: string;
  };
  createdAt?: Date;
  updatedAt?: Date;
}

const userProfileSchema = new Schema<IUserProfile>(
  {
    name: { type: String, required: true },
    mobile: { type: String, required: true },
    status: {
      type: String,
      enum: ['inactive', 'pending_approval', 'approved'],
      default: 'inactive',
    },
    sessionActive: { type: Boolean, default: false },
    requestPending: { type: Boolean, default: false },
    requestedAt: { type: Date, default: null },
    lastApprovalTime: { type: Date, default: null },
    approvedBy: { type: String, default: null },
    deviceInfo: {
      deviceModel: { type: String, default: '' },
      platform: { type: String, default: '' },
    },
  },
  {
    timestamps: true,
  }
);

export const UserProfile = model<IUserProfile>('UserProfile', userProfileSchema);
