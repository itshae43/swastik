import express, { Request, Response } from 'express';
import mongoose from 'mongoose';
import cors from 'cors';
import dotenv from 'dotenv';
import dns from 'dns';
import { Admin } from './models/Admin';
import { Party } from './models/Party';
import { Transaction } from './models/Transaction';
import { Reminder } from './models/Reminder';
import { UserProfile } from './models/UserProfile';

// Force use of reliable public DNS to prevent SRV ETIMEOUT on some networks
dns.setServers(['8.8.8.8', '1.1.1.1']);

dotenv.config();

const app = express();
const PORT = process.env.PORT || 5000;
const MONGO_URI = process.env.MONGO_URI || '';

app.use(cors());
app.use(express.json());

// In-Memory/Local Admin records as fallback if MongoDB is not connected
let isMongoConnected = false;
let fallbackAdmins: any[] = [];

// In-Memory/Local UserProfile records as fallback if MongoDB is not connected
let fallbackUserProfiles: any[] = [
  {
    _id: '60d5ec4b86cd5d3a9c7b99c1',
    name: 'Shailendra',
    mobile: '9876543210',
    status: 'inactive',
    sessionActive: false,
    requestPending: false,
    requestedAt: null,
    lastApprovalTime: null,
    approvedBy: null,
    deviceInfo: {
      deviceModel: 'Pixel 6',
      platform: 'android'
    },
    createdAt: new Date(),
    updatedAt: new Date()
  }
];

// Connect to MongoDB
mongoose
  .connect(MONGO_URI)
  .then(async () => {
    console.log('Connected to MongoDB successfully');
    isMongoConnected = true;
    console.log('Admin seeding on startup is disabled.');
    seedUserProfile();
  })
  .catch((err) => {
    console.error('================================================================');
    console.error('WARNING: MongoDB connection failed (bad credentials or network)');
    console.error('Error details:', err.message);
    console.error('FALLBACK: The server will use in-memory mock database for testing.');
    console.error('================================================================');
    isMongoConnected = false;
  });

// Seed default UserProfile if none exists
async function seedUserProfile() {
  try {
    if (!isMongoConnected) return;
    const profileCount = await UserProfile.countDocuments();
    if (profileCount === 0) {
      console.log('No user profiles found in database. Seeding default profile...');
      const defaultProfile = new UserProfile({
        name: 'Shailendra',
        mobile: '9876543210',
        status: 'inactive',
        sessionActive: false,
        requestPending: false,
        requestedAt: null,
        lastApprovalTime: null,
        approvedBy: null,
        deviceInfo: {
          deviceModel: '',
          platform: '',
        },
      });
      await defaultProfile.save();
      console.log('Default user profile seeded successfully:', defaultProfile);
    }
  } catch (error) {
    console.error('Error seeding user profile:', error);
  }
}

// Seed default Admin user if none exists (disabled)
async function seedAdmin() {
  try {
    const adminCount = await Admin.countDocuments();
    if (adminCount === 0) {
      console.log('No admins found in database. Seeding default admin...');
      const defaultAdmin = new Admin({
        brand: 'google',
        model: 'Pixel Tablet',
        androidId: 'd0b41708a4f50758',
      });
      await defaultAdmin.save();
      console.log('Default admin seeded successfully:', defaultAdmin);
    } else {
      const exists = await Admin.findOne({ androidId: 'd0b41708a4f50758' });
      if (!exists) {
        console.log('Default target admin not found. Creating it...');
        const targetAdmin = new Admin({
          brand: 'google',
          model: 'Pixel Tablet',
          androidId: 'd0b41708a4f50758',
        });
        await targetAdmin.save();
        console.log('Target admin seeded:', targetAdmin);
      } else {
        console.log('Target admin already exists in database.');
      }
    }
  } catch (error) {
    console.error('Error seeding database:', error);
  }
}

// Mock Device Sessions
interface IDeviceSession {
  id: string;
  userName: string;
  phoneNumber: string;
  brand: string;
  model: string;
  androidId: string;
  lastActive: string;
}

let mockDeviceSessions: IDeviceSession[] = [
  {
    id: "session_1",
    userName: "Swastik Jewels Admin",
    phoneNumber: "+91 98765 43210",
    brand: "Google",
    model: "Pixel Tablet",
    androidId: "d0b41708a4f50758",
    lastActive: "Active Now"
  },
  {
    id: "session_2",
    userName: "Manager",
    phoneNumber: "+91 99999 88888",
    brand: "Samsung",
    model: "Galaxy Tab S9 Ultra",
    androidId: "mock_android_id_2",
    lastActive: "Active 5 mins ago"
  },
  {
    id: "session_3",
    userName: "Sales Representative",
    phoneNumber: "+91 88888 77777",
    brand: "OnePlus",
    model: "OnePlus 11 5G",
    androidId: "mock_android_id_3",
    lastActive: "Active 2 hours ago"
  }
];

// Helper to track/upsert dynamic device sessions
const registerDeviceSession = (brand: string, model: string, androidId: string) => {
  const exists = mockDeviceSessions.some(
    (session) => session.androidId.toLowerCase() === androidId.toLowerCase()
  );
  if (!exists) {
    mockDeviceSessions.push({
      id: `session_${Date.now()}`,
      userName: "Swastik Jewels Admin",
      phoneNumber: "+91 98765 43210",
      brand,
      model: model || "Unknown Model",
      androidId,
      lastActive: "Active Now"
    });
  } else {
    // Update active state of existing device
    mockDeviceSessions = mockDeviceSessions.map((session) => {
      if (session.androidId.toLowerCase() === androidId.toLowerCase()) {
        return { ...session, lastActive: "Active Now" };
      }
      return session;
    });
  }
};

// Verification Endpoint
app.post('/api/verify', async (req: Request, res: Response) => {
  try {
    const { androidId, brand, model } = req.body;

    if (!androidId || !brand) {
      return res.status(400).json({
        verified: false,
        message: 'Missing required parameters: androidId and brand',
      });
    }

    console.log(`[VERIFICATION REQUEST] brand=${brand}, model=${model}, androidId=${androidId}`);

    if (isMongoConnected) {
      // Check if any admins exist in MongoDB
      const adminCount = await Admin.countDocuments();
      if (adminCount === 0) {
        console.log('No admins found in database. Registering this device as the admin...');
        const newAdmin = new Admin({
          brand,
          model: model || 'Unknown Model',
          androidId,
        });
        await newAdmin.save();
        console.log('First admin registered successfully:', newAdmin);
        registerDeviceSession(brand, model || 'Unknown Model', androidId);
        return res.json({ verified: true, admin: newAdmin });
      }

      // Query database for matching brand and androidId (case-insensitive for brand)
      const matchingAdmin = await Admin.findOne({
        androidId: { $regex: new RegExp(`^${androidId}$`, 'i') },
        brand: { $regex: new RegExp(`^${brand}$`, 'i') },
      });

      if (matchingAdmin) {
        console.log('Verification Success (MongoDB): Match found.');
        registerDeviceSession(brand, model || 'Unknown Model', androidId);
        return res.json({ verified: true, admin: matchingAdmin });
      }
    } else {
      // In-memory fallback
      if (fallbackAdmins.length === 0) {
        console.log('No admins found in-memory. Registering this device as the admin...');
        const newAdmin = {
          brand,
          model: model || 'Unknown Model',
          androidId,
        };
        fallbackAdmins.push(newAdmin);
        console.log('First fallback admin registered successfully:', newAdmin);
        registerDeviceSession(brand, model || 'Unknown Model', androidId);
        return res.json({ verified: true, admin: newAdmin });
      }

      // Query local fallback memory database
      const match = fallbackAdmins.find(
        (admin) =>
          admin.androidId.toLowerCase() === androidId.toLowerCase() &&
          admin.brand.toLowerCase() === brand.toLowerCase()
      );

      if (match) {
        console.log('Verification Success (In-Memory Fallback): Match found.');
        registerDeviceSession(brand, model || 'Unknown Model', androidId);
        return res.json({ verified: true, admin: match });
      }
    }

    console.log('Verification Failed: No match found.');
    return res.json({
      verified: false,
      message: 'Device not authorized. Please contact to admin.',
    });
  } catch (error: any) {
    console.error('Error in /api/verify endpoint:', error);
    return res.status(500).json({
      verified: false,
      message: 'Server error during verification.',
    });
  }
});

// Device Management Endpoints
app.get('/api/devices', (req: Request, res: Response) => {
  try {
    res.json(mockDeviceSessions);
  } catch (error: any) {
    console.error('Error in GET /api/devices:', error);
    res.status(500).json({ error: 'Server error retrieving device sessions.' });
  }
});

app.delete('/api/devices/:id', async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const sessionIndex = mockDeviceSessions.findIndex((s) => s.id === id);

    if (sessionIndex === -1) {
      return res.status(404).json({ error: 'Device session not found.' });
    }

    const session = mockDeviceSessions[sessionIndex];
    const androidId = session.androidId;

    // Delete session from list
    mockDeviceSessions.splice(sessionIndex, 1);

    // Also deauthorize/delete from Admin collection to trigger real logout on that device
    if (isMongoConnected) {
      const deletedAdmin = await Admin.findOneAndDelete({
        androidId: { $regex: new RegExp(`^${androidId}$`, 'i') },
      });
      console.log(`Deauthorized admin device ${androidId} via session deletion:`, deletedAdmin);
    } else {
      const initialLength = fallbackAdmins.length;
      fallbackAdmins = fallbackAdmins.filter(
        (admin) => admin.androidId.toLowerCase() !== androidId.toLowerCase()
      );
      console.log(
        `Deauthorized fallback admin device ${androidId} via session deletion. Count reduced by ${
          initialLength - fallbackAdmins.length
        }`
      );
    }

    res.json({ success: true, message: 'Device logged out successfully.' });
  } catch (error: any) {
    console.error('Error in DELETE /api/devices/:id:', error);
    res.status(500).json({ error: 'Server error deleting device session.' });
  }
});

// CRUD/API endpoints for User Profiles
app.get('/api/user-profiles', async (req: Request, res: Response) => {
  try {
    if (isMongoConnected) {
      const profiles = await UserProfile.find().sort({ createdAt: -1 });
      res.json(profiles);
    } else {
      res.json(fallbackUserProfiles);
    }
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/user-profiles', async (req: Request, res: Response) => {
  try {
    const { name, mobile, deviceInfo } = req.body;
    if (!name || !mobile) {
      return res.status(400).json({ error: 'Name and mobile number are required.' });
    }

    if (isMongoConnected) {
      const newProfile = new UserProfile({
        name,
        mobile,
        status: 'inactive',
        sessionActive: false,
        requestPending: false,
        requestedAt: null,
        lastApprovalTime: null,
        approvedBy: null,
        deviceInfo: {
          deviceModel: deviceInfo?.deviceModel || '',
          platform: deviceInfo?.platform || '',
        },
      });
      const savedProfile = await newProfile.save();
      res.status(201).json(savedProfile);
    } else {
      const newProfile = {
        _id: `mock_profile_${Date.now()}`,
        name,
        mobile,
        status: 'inactive',
        sessionActive: false,
        requestPending: false,
        requestedAt: null,
        lastApprovalTime: null,
        approvedBy: null,
        deviceInfo: {
          deviceModel: deviceInfo?.deviceModel || '',
          platform: deviceInfo?.platform || '',
        },
        createdAt: new Date(),
        updatedAt: new Date(),
      };
      fallbackUserProfiles.push(newProfile);
      res.status(201).json(newProfile);
    }
  } catch (err: any) {
    res.status(400).json({ error: err.message });
  }
});

app.post('/api/user-profiles/:id/request-access', async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const { deviceInfo } = req.body;

    if (isMongoConnected) {
      const updated = await UserProfile.findByIdAndUpdate(
        id,
        {
          status: 'pending_approval',
          requestPending: true,
          requestedAt: new Date(),
          ...(deviceInfo && {
            deviceInfo: {
              deviceModel: deviceInfo.deviceModel || '',
              platform: deviceInfo.platform || '',
            },
          }),
        },
        { new: true }
      );
      if (!updated) {
        return res.status(404).json({ error: 'User profile not found.' });
      }
      res.json(updated);
    } else {
      const profile = fallbackUserProfiles.find((p) => p._id === id);
      if (!profile) {
        return res.status(404).json({ error: 'User profile not found.' });
      }
      profile.status = 'pending_approval';
      profile.requestPending = true;
      profile.requestedAt = new Date();
      if (deviceInfo) {
        profile.deviceInfo = {
          deviceModel: deviceInfo.deviceModel || '',
          platform: deviceInfo.platform || '',
        };
      }
      profile.updatedAt = new Date();
      res.json(profile);
    }
  } catch (err: any) {
    res.status(400).json({ error: err.message });
  }
});

// CRUD Routes for Parties
app.get('/api/parties', async (req, res) => {
  try {
    const parties = await Party.find().sort({ updatedAt: -1 });
    res.json(parties);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});
app.post('/api/parties', async (req, res) => {
  try {
    const newParty = new Party(req.body);
    const savedParty = await newParty.save();
    res.status(201).json(savedParty);
  } catch (err: any) {
    res.status(400).json({ error: err.message });
  }
});
app.put('/api/parties/:id', async (req, res) => {
  try {
    const updatedParty = await Party.findByIdAndUpdate(req.params.id, req.body, { new: true });
    res.json(updatedParty);
  } catch (err: any) {
    res.status(400).json({ error: err.message });
  }
});
app.delete('/api/parties/:id', async (req, res) => {
  try {
    await Party.findByIdAndDelete(req.params.id);
    res.json({ message: 'Party deleted successfully' });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

// CRUD Routes for Transactions
app.get('/api/transactions', async (req, res) => {
  try {
    const transactions = await Transaction.find().sort({ date: -1 });
    res.json(transactions);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});
app.post('/api/transactions', async (req, res) => {
  try {
    const newTx = new Transaction(req.body);
    const savedTx = await newTx.save();
    res.status(201).json(savedTx);
  } catch (err: any) {
    res.status(400).json({ error: err.message });
  }
});
app.put('/api/transactions/:id', async (req, res) => {
  try {
    const updatedTx = await Transaction.findByIdAndUpdate(req.params.id, req.body, { new: true });
    res.json(updatedTx);
  } catch (err: any) {
    res.status(400).json({ error: err.message });
  }
});
app.delete('/api/transactions/:id', async (req, res) => {
  try {
    await Transaction.findByIdAndDelete(req.params.id);
    res.json({ message: 'Transaction deleted successfully' });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

// CRUD Routes for Reminders
app.get('/api/reminders', async (req, res) => {
  try {
    const reminders = await Reminder.find().sort({ date: 1 });
    res.json(reminders);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});
app.post('/api/reminders', async (req, res) => {
  try {
    const newReminder = new Reminder(req.body);
    const savedReminder = await newReminder.save();
    res.status(201).json(savedReminder);
  } catch (err: any) {
    res.status(400).json({ error: err.message });
  }
});
app.put('/api/reminders/:id', async (req, res) => {
  try {
    const updatedReminder = await Reminder.findByIdAndUpdate(req.params.id, req.body, { new: true });
    res.json(updatedReminder);
  } catch (err: any) {
    res.status(400).json({ error: err.message });
  }
});
app.delete('/api/reminders/:id', async (req, res) => {
  try {
    await Reminder.findByIdAndDelete(req.params.id);
    res.json({ message: 'Reminder deleted successfully' });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({
    status: 'ok',
    database: isMongoConnected ? 'connected' : 'fallback_in_memory',
    fallbackActive: !isMongoConnected,
  });
});

app.listen(PORT, () => {
  console.log(`Swastik Admin Verification Server is running on port ${PORT}`);
});
