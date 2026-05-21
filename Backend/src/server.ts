import express, { Request, Response } from 'express';
import mongoose from 'mongoose';
import cors from 'cors';
import dotenv from 'dotenv';
import dns from 'dns';
import { Admin } from './models/Admin';
import { Party } from './models/Party';
import { Transaction } from './models/Transaction';
import { Reminder } from './models/Reminder';

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
