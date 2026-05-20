import mongoose from 'mongoose';
import dotenv from 'dotenv';
import dns from 'dns';

// Force use of reliable public DNS to prevent SRV ETIMEOUT on some networks
dns.setServers(['8.8.8.8', '1.1.1.1']);

dotenv.config();
const MONGO_URI = process.env.MONGO_URI || '';

console.log('Connecting to:', MONGO_URI);
mongoose.connect(MONGO_URI)
  .then(() => {
    console.log('SUCCESSFULLY CONNECTED');
    process.exit(0);
  })
  .catch((err) => {
    console.error('CONNECTION FAILED:', err);
    process.exit(1);
  });
