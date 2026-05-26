import express, { Request, Response, NextFunction } from 'express';
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

// Server-Sent Events (SSE) clients
let sseClients: Response[] = [];

// Helper to broadcast profile updates
function broadcastProfilesUpdated() {
  sseClients.forEach(client => {
    client.write('event: profiles_updated\ndata: {}\n\n');
  });
}

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
    expiresAt: null,
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
        expiresAt: null,
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
        return res.json({ verified: true, admin: newAdmin });
      }

      // Query database for matching brand and androidId (case-insensitive for brand)
      const matchingAdmin = await Admin.findOne({
        androidId: { $regex: new RegExp(`^${androidId}$`, 'i') },
        brand: { $regex: new RegExp(`^${brand}$`, 'i') },
      });

      if (matchingAdmin) {
        console.log('Verification Success (MongoDB): Match found.');
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
app.get('/api/devices', async (req: Request, res: Response) => {
  try {
    const now = new Date();
    
    // Auto-expire sessions
    if (isMongoConnected) {
      await UserProfile.updateMany(
        { sessionActive: true, expiresAt: { $lt: now } },
        { sessionActive: false, status: 'inactive' }
      );
    } else {
      fallbackUserProfiles.forEach(p => {
        if (p.sessionActive && p.expiresAt && now.getTime() > p.expiresAt.getTime()) {
          p.sessionActive = false;
          p.status = 'inactive';
          p.updatedAt = new Date();
        }
      });
    }

    const activeProfiles: any[] = [];
    if (isMongoConnected) {
      const profiles = await UserProfile.find({ sessionActive: true });
      profiles.forEach(profile => {
        activeProfiles.push({
          id: profile._id.toString(),
          userName: profile.name,
          phoneNumber: profile.mobile,
          brand: profile.deviceInfo.platform === 'android' ? 'Android' : (profile.deviceInfo.platform === 'ios' ? 'iOS' : 'Device'),
          model: profile.deviceInfo.deviceModel || 'Staff Device',
          androidId: `profile_${profile._id.toString()}`,
          lastActive: profile.lastApprovalTime 
            ? `Active since ${new Date(profile.lastApprovalTime).toLocaleTimeString()}`
            : 'Active Now'
        });
      });
    } else {
      fallbackUserProfiles.forEach(profile => {
        if (profile.sessionActive) {
          activeProfiles.push({
            id: profile._id,
            userName: profile.name,
            phoneNumber: profile.mobile,
            brand: profile.deviceInfo.platform === 'android' ? 'Android' : (profile.deviceInfo.platform === 'ios' ? 'iOS' : 'Device'),
            model: profile.deviceInfo.deviceModel || 'Staff Device',
            androidId: `profile_${profile._id}`,
            lastActive: profile.lastApprovalTime 
              ? `Active since ${new Date(profile.lastApprovalTime).toLocaleTimeString()}`
              : 'Active Now'
          });
        }
      });
    }
    const allSessions = [...activeProfiles];
    res.json(allSessions);
  } catch (error: any) {
    console.error('Error in GET /api/devices:', error);
    res.status(500).json({ error: 'Server error retrieving device sessions.' });
  }
});

app.delete('/api/devices/:id', async (req: Request, res: Response) => {
  try {
    const { id } = req.params;

    // Check if it matches a UserProfile ID
    if (isMongoConnected) {
      const profile = await UserProfile.findById(id);
      if (profile) {
        profile.sessionActive = false;
        profile.status = 'inactive';
        profile.requestPending = false;
        await profile.save();
        console.log(`Deauthorized UserProfile session ${id} remotely.`);
        return res.json({ success: true, message: 'User profile session terminated successfully.' });
      }
    } else {
      const profile = fallbackUserProfiles.find((p) => p._id === id);
      if (profile) {
        profile.sessionActive = false;
        profile.status = 'inactive';
        profile.requestPending = false;
        profile.updatedAt = new Date();
        console.log(`Deauthorized fallback UserProfile session ${id} remotely.`);
        return res.json({ success: true, message: 'User profile session terminated successfully.' });
      }
    }

    // Also deauthorize/delete from Admin collection to trigger real logout on that device if id matches an admin
    if (isMongoConnected) {
      const deletedAdmin = await Admin.findOneAndDelete({
        androidId: { $regex: new RegExp(`^${id}$`, 'i') },
      });
      if (deletedAdmin) {
         console.log(`Deauthorized admin device ${id} via session deletion:`, deletedAdmin);
         return res.json({ success: true, message: 'Admin device logged out successfully.' });
      }
    } else {
      const initialLength = fallbackAdmins.length;
      fallbackAdmins = fallbackAdmins.filter(
        (admin) => admin.androidId.toLowerCase() !== id.toLowerCase()
      );
      if (initialLength > fallbackAdmins.length) {
         console.log(`Deauthorized fallback admin device ${id} via session deletion.`);
         return res.json({ success: true, message: 'Admin device logged out successfully.' });
      }
    }

    return res.status(404).json({ error: 'Device session not found.' });

    res.json({ success: true, message: 'Device logged out successfully.' });
  } catch (error: any) {
    console.error('Error in DELETE /api/devices/:id:', error);
    res.status(500).json({ error: 'Server error deleting device session.' });
  }
});

// CRUD/API endpoints for User Profiles
app.get('/api/user-profiles', async (req: Request, res: Response) => {
  try {
    const thirtySecondsAgo = new Date(Date.now() - 30000);
    if (isMongoConnected) {
      // Proactively clean up expired requests and expired sessions in DB
      const now = new Date();
      await UserProfile.updateMany(
        {
          status: 'pending_approval',
          requestedAt: { $lt: thirtySecondsAgo }
        },
        {
          status: 'inactive',
          requestPending: false
        }
      );
      await UserProfile.updateMany(
        { sessionActive: true, expiresAt: { $lt: now } },
        { sessionActive: false, status: 'inactive' }
      );
      const profiles = await UserProfile.find().sort({ createdAt: -1 });
      res.json(profiles);
    } else {
      // Proactively clean up expired requests in fallback memory
      const now = Date.now();
      fallbackUserProfiles.forEach((p) => {
        if (p.status === 'pending_approval' && p.requestedAt) {
          const requestedTime = new Date(p.requestedAt).getTime();
          if (now - requestedTime > 30000) {
            p.status = 'inactive';
            p.requestPending = false;
            p.updatedAt = new Date();
          }
        }
      });
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
        expiresAt: null,
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
        expiresAt: null,
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
      const profile = await UserProfile.findById(id);
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
      const updated = await profile.save();

      // Set 30s timer to revert status to inactive
      setTimeout(async () => {
        try {
          const currentProfile = await UserProfile.findById(id);
          if (currentProfile && currentProfile.status === 'pending_approval') {
            currentProfile.status = 'inactive';
            currentProfile.requestPending = false;
            await currentProfile.save();
            console.log(`[ACCESS REQUEST EXPIRED] Profile ${currentProfile.name} (DB) reverted to inactive.`);
          }
        } catch (timeoutErr) {
          console.error('[ACCESS REQUEST EXPIRED TIMER ERROR] ', timeoutErr);
        }
      }, 30000);

      res.json(updated);
      broadcastProfilesUpdated();
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

      // Set 30s timer to revert status to inactive
      setTimeout(() => {
        if (profile.status === 'pending_approval') {
          profile.status = 'inactive';
          profile.requestPending = false;
          profile.updatedAt = new Date();
          console.log(`[ACCESS REQUEST EXPIRED] Profile ${profile.name} (In-Memory) reverted to inactive.`);
        }
      }, 30000);

      res.json(profile);
      broadcastProfilesUpdated();
    }
  } catch (err: any) {
    res.status(400).json({ error: err.message });
  }
});

app.post('/api/user-profiles/:id/approve', async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    if (isMongoConnected) {
      const profile = await UserProfile.findById(id);
      if (!profile) {
        return res.status(404).json({ error: 'User profile not found.' });
      }
      profile.status = 'approved';
      profile.sessionActive = true;
      profile.requestPending = false;
      profile.lastApprovalTime = new Date();
      profile.approvedBy = 'Admin';

      // Expiry Logic: 8 PM IST or 10 mins
      const now = new Date();
      const istOffsetMs = 5.5 * 60 * 60 * 1000;
      const istTime = new Date(now.getTime() + istOffsetMs);
      let expiresAt: Date;

      if (istTime.getUTCHours() < 20) {
        const ist8PM = new Date(istTime);
        ist8PM.setUTCHours(20, 0, 0, 0);
        expiresAt = new Date(ist8PM.getTime() - istOffsetMs);
      } else {
        expiresAt = new Date(now.getTime() + 10 * 60 * 1000);
      }
      profile.expiresAt = expiresAt;

      const updated = await profile.save();
      console.log(`[ACCESS REQUEST APPROVED] Profile ${profile.name} (DB) approved by Admin. Expires at ${expiresAt}`);
      res.json(updated);
      broadcastProfilesUpdated();
    } else {
      const profile = fallbackUserProfiles.find((p) => p._id === id);
      if (!profile) {
        return res.status(404).json({ error: 'User profile not found.' });
      }
      profile.status = 'approved';
      profile.sessionActive = true;
      profile.requestPending = false;
      profile.lastApprovalTime = new Date();
      profile.approvedBy = 'Admin';

      const now = new Date();
      const istOffsetMs = 5.5 * 60 * 60 * 1000;
      const istTime = new Date(now.getTime() + istOffsetMs);
      let expiresAt: Date;

      if (istTime.getUTCHours() < 20) {
        const ist8PM = new Date(istTime);
        ist8PM.setUTCHours(20, 0, 0, 0);
        expiresAt = new Date(ist8PM.getTime() - istOffsetMs);
      } else {
        expiresAt = new Date(now.getTime() + 10 * 60 * 1000);
      }
      profile.expiresAt = expiresAt;
      
      profile.updatedAt = new Date();
      console.log(`[ACCESS REQUEST APPROVED] Profile ${profile.name} (In-Memory) approved by Admin. Expires at ${expiresAt}`);
      res.json(profile);
      broadcastProfilesUpdated();
    }
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/user-profiles/:id/decline', async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    if (isMongoConnected) {
      const profile = await UserProfile.findById(id);
      if (!profile) {
        return res.status(404).json({ error: 'User profile not found.' });
      }
      profile.status = 'inactive';
      profile.sessionActive = false;
      profile.requestPending = false;
      profile.requestedAt = null;
      const updated = await profile.save();
      console.log(`[ACCESS REQUEST DECLINED] Profile ${profile.name} (DB) declined by Admin.`);
      res.json(updated);
      broadcastProfilesUpdated();
    } else {
      const profile = fallbackUserProfiles.find((p) => p._id === id);
      if (!profile) {
        return res.status(404).json({ error: 'User profile not found.' });
      }
      profile.status = 'inactive';
      profile.sessionActive = false;
      profile.requestPending = false;
      profile.requestedAt = null;
      profile.updatedAt = new Date();
      console.log(`[ACCESS REQUEST DECLINED] Profile ${profile.name} (In-Memory) declined by Admin.`);
      res.json(profile);
      broadcastProfilesUpdated();
    }
  } catch (err: any) {
    res.status(500).json({ error: err.message });
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

// Authentication & Authorization Middlewares
async function authenticate(req: Request, res: Response, next: NextFunction) {
  try {
    const androidId = req.headers['x-android-id'] as string;
    const brand = req.headers['x-device-brand'] as string;
    const staffId = req.headers['x-staff-id'] as string;

    // Check if it matches an Admin
    if (androidId && brand) {
      if (isMongoConnected) {
        const admin = await Admin.findOne({
          androidId: { $regex: new RegExp(`^${androidId}$`, 'i') },
          brand: { $regex: new RegExp(`^${brand}$`, 'i') },
        });
        if (admin) {
          req.body.callerRole = 'admin';
          return next();
        }
      } else {
        const admin = fallbackAdmins.find(
          (a) =>
            a.androidId.toLowerCase() === androidId.toLowerCase() &&
            a.brand.toLowerCase() === brand.toLowerCase()
        );
        if (admin) {
          req.body.callerRole = 'admin';
          return next();
        }
      }
    }

    // Check if it matches an approved active Staff Profile
    if (staffId) {
      if (isMongoConnected) {
        const profile = await UserProfile.findById(staffId);
        if (profile && profile.sessionActive && profile.status === 'approved') {
          req.body.callerRole = 'staff';
          return next();
        }
      } else {
        const profile = fallbackUserProfiles.find(
          (p) => p._id === staffId && p.sessionActive && p.status === 'approved'
        );
        if (profile) {
          req.body.callerRole = 'staff';
          return next();
        }
      }
    }

    return res.status(401).json({ error: 'Unauthorized: Access denied. Missing or invalid authentication headers.' });
  } catch (err: any) {
    return res.status(500).json({ error: err.message });
  }
}

function requireAdmin(req: Request, res: Response, next: NextFunction) {
  if (req.body.callerRole === 'admin') {
    return next();
  }
  return res.status(403).json({ error: 'Forbidden: Only Admins can modify or delete finalized transactions.' });
}

// CRUD Routes for Transactions
app.get('/api/transactions', authenticate, async (req, res) => {
  try {
    const transactions = await Transaction.find().sort({ date: -1 });
    res.json(transactions);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});
app.post('/api/transactions', authenticate, async (req, res) => {
  try {
    const newTx = new Transaction(req.body);
    const savedTx = await newTx.save();
    res.status(201).json(savedTx);
  } catch (err: any) {
    res.status(400).json({ error: err.message });
  }
});
app.put('/api/transactions/:id', authenticate, requireAdmin, async (req, res) => {
  try {
    const updatedTx = await Transaction.findByIdAndUpdate(req.params.id, req.body, { new: true });
    res.json(updatedTx);
  } catch (err: any) {
    res.status(400).json({ error: err.message });
  }
});
app.delete('/api/transactions/:id', authenticate, requireAdmin, async (req, res) => {
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

// Server time endpoint for network clock synchronization
app.get('/api/time', (req, res) => {
  res.json({
    serverTime: new Date().toISOString(),
  });
});

// SSE Endpoint
app.get('/api/events', (req: Request, res: Response) => {
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');

  // Initial connection event
  res.write('data: connected\n\n');

  sseClients.push(res);

  req.on('close', () => {
    sseClients = sseClients.filter(client => client !== res);
  });
});

// Auto-logout expired sessions every 1 minute
setInterval(async () => {
  const now = new Date();
  if (isMongoConnected) {
    try {
      const expiredProfiles = await UserProfile.find({
        status: 'approved',
        expiresAt: { $lte: now },
      });
      for (const profile of expiredProfiles) {
        profile.status = 'inactive';
        profile.sessionActive = false;
        profile.expiresAt = null;
        await profile.save();
        console.log(`[CRON] DB Profile ${profile.name} automatically logged out due to expiry.`);
      }
    } catch (err) {
      console.error('Error running cron job:', err);
    }
  } else {
    fallbackUserProfiles.forEach(profile => {
      if (profile.status === 'approved' && profile.expiresAt && profile.expiresAt <= now) {
        profile.status = 'inactive';
        profile.sessionActive = false;
        profile.expiresAt = null;
        console.log(`[CRON] In-Memory Profile ${profile.name} automatically logged out due to expiry.`);
      }
    });
  }
}, 60 * 1000);

app.listen(PORT, () => {
  console.log(`Swastik Admin Verification Server is running on port ${PORT}`);
});
