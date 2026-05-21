import express, { Request, Response } from 'express';
import mongoose from 'mongoose';
import cors from 'cors';
import dotenv from 'dotenv';
import dns from 'dns';
import { Admin } from './models/Admin';

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

// Connect to MongoDB
mongoose
  .connect(MONGO_URI)
  .then(async () => {
    console.log('Connected to MongoDB successfully');
    isMongoConnected = true;
    console.log('Admin seeding on startup is disabled.');
  })
  .catch((err) => {
    console.error('================================================================');
    console.error('WARNING: MongoDB connection failed (bad credentials or network)');
    console.error('Error details:', err.message);
    console.error('FALLBACK: The server will use in-memory mock database for testing.');
    console.error('================================================================');
    isMongoConnected = false;
  });

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
