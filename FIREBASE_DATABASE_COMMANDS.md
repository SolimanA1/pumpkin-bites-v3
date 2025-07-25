# Firebase Database Update Commands

This guide provides Firebase CLI commands to properly update the Firestore database with production data.

## Prerequisites

1. **Install Firebase CLI**:
   ```bash
   npm install -g firebase-tools
   ```

2. **Login to Firebase**:
   ```bash
   firebase login
   ```

3. **Initialize Firebase project** (if not already done):
   ```bash
   firebase init firestore
   ```

## Project Information

- **Project ID**: `pumpkin-bites-jvouko` (from firebase_options.dart)
- **Database**: Firestore
- **Collections**: `bites`, `users`, `comments`, `gifts`

## Method 1: Using Firebase Admin SDK (Recommended)

Create a Node.js script to seed production data:

### 1. Setup Admin SDK

```bash
# In your project directory
npm init -y
npm install firebase-admin
```

### 2. Download Service Account Key

1. Go to Firebase Console → Project Settings → Service Accounts
2. Click "Generate new private key"
3. Save as `service-account-key.json` (DO NOT commit to git)

### 3. Create Seeding Script

Create `seed-production-data.js`:

```javascript
const admin = require('firebase-admin');
const serviceAccount = require('./service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

const productionBites = [
  {
    title: 'The Tiny Revolution',
    description: 'How the smallest changes create the biggest transformations. Discover why incremental shifts are more powerful than dramatic overhauls.',
    category: 'Psychology',
    duration: 195,
    authorName: 'Dr. Sarah Chen',
    isPremium: false,
    dayNumber: 1,
    audioUrl: 'https://cdn.pixabay.com/download/audio/2022/10/30/audio_347111d654.mp3',
    thumbnailUrl: 'https://dummyimage.com/400x225/FF6B35/FFFFFF.png&text=Psychology'
  },
  {
    title: 'The Undoing Hypothesis',
    description: 'Sometimes growth means unlearning what we thought we knew. Explore the counterintuitive art of letting go of harmful patterns.',
    category: 'Psychology',
    duration: 167,
    authorName: 'Marcus Rivera',
    isPremium: false,
    dayNumber: 2,
    audioUrl: 'https://cdn.pixabay.com/download/audio/2022/03/15/audio_c8e9d46df7.mp3',
    thumbnailUrl: 'https://dummyimage.com/400x225/F7931E/FFFFFF.png&text=Psychology'
  },
  // Add all 30 bites here...
];

async function seedData() {
  console.log('🚀 Starting production data seeding...');
  
  try {
    // Clear existing bites (optional)
    const existingBites = await db.collection('bites').get();
    console.log(`Found ${existingBites.docs.length} existing bites`);
    
    if (existingBites.docs.length > 0) {
      const batch = db.batch();
      existingBites.docs.forEach(doc => {
        batch.delete(doc.ref);
      });
      await batch.commit();
      console.log('✅ Cleared existing bites');
    }
    
    // Add production bites
    const batch = db.batch();
    productionBites.forEach((biteData, index) => {
      const biteRef = db.collection('bites').doc();
      const biteDocument = {
        ...biteData,
        date: admin.firestore.Timestamp.now(),
        isPremiumOnly: false,
        commentCount: 0,
        giftedBy: '',
        giftMessage: ''
      };
      batch.set(biteRef, biteDocument);
    });
    
    await batch.commit();
    console.log(`✅ Created ${productionBites.length} production bites`);
    
    console.log('🎉 Production data seeding completed successfully!');
  } catch (error) {
    console.error('❌ Error seeding data:', error);
  } finally {
    process.exit(0);
  }
}

seedData();
```

### 4. Run the Script

```bash
node seed-production-data.js
```

## Method 2: Using Firebase CLI with JSON Import

### 1. Create Data Export

Create `bites-export.json`:

```json
{
  "bites": {
    "bite1": {
      "title": "The Tiny Revolution",
      "description": "How the smallest changes create the biggest transformations...",
      "category": "Psychology",
      "duration": 195,
      "authorName": "Dr. Sarah Chen",
      "isPremium": false,
      "dayNumber": 1,
      "date": {"_seconds": 1640995200, "_nanoseconds": 0},
      "audioUrl": "https://cdn.pixabay.com/download/audio/2022/10/30/audio_347111d654.mp3",
      "thumbnailUrl": "https://dummyimage.com/400x225/FF6B35/FFFFFF.png&text=Psychology",
      "isPremiumOnly": false,
      "commentCount": 0,
      "giftedBy": "",
      "giftMessage": ""
    }
  }
}
```

### 2. Import Data

```bash
# Clear existing data first (CAREFUL!)
firebase firestore:delete bites --recursive --yes

# Import new data
firebase firestore:import bites-export.json
```

## Method 3: Manual Firestore Console (Small datasets)

1. Go to Firebase Console → Firestore Database
2. Select the `bites` collection
3. Manually add documents with the required fields
4. Use the Auto-ID option for document IDs

## Method 4: Using the App's Built-in Seeder (For Testing Only)

1. Build and run the app
2. Navigate to Profile → Diagnostics → "Production Data Manager"
3. Tap "CLEAR ALL EXISTING BITES" (with caution)
4. Tap "SEED PRODUCTION DATA"

**⚠️ Warning**: This method is only for testing and may cause performance issues with large datasets.

## Backup and Restore Commands

### Create Backup

```bash
# Export entire database
firebase firestore:export gs://your-bucket-name/backups/$(date +%Y-%m-%d)

# Export specific collection
firebase firestore:export --collection-ids=bites gs://your-bucket-name/bites-backup
```

### Restore from Backup

```bash
firebase firestore:import gs://your-bucket-name/backups/2024-01-01
```

## Firestore Security Rules

Make sure your security rules allow the operations:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Bites collection
    match /bites/{biteId} {
      allow read: if true; // Public read
      allow write: if request.auth != null; // Authenticated write
    }
    
    // Users collection
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## Monitoring and Verification

### Check Document Count

```bash
# Using Firebase CLI
firebase firestore:indexes

# Or use this Node.js snippet
const snapshot = await db.collection('bites').get();
console.log(`Total bites: ${snapshot.size}`);
```

### Verify Data Structure

```javascript
// Get a sample document to verify structure
const sample = await db.collection('bites').limit(1).get();
sample.forEach(doc => {
  console.log('Sample bite structure:', doc.data());
});
```

## Performance Considerations

1. **Batch Operations**: Always use batched writes for multiple documents
2. **Rate Limits**: Firestore has write limits (1 write per second per document)
3. **Index Creation**: Ensure proper indexes for queries
4. **Connection Limits**: Use connection pooling for large operations

## Troubleshooting

### Common Issues

1. **Permission Denied**: Check Firestore security rules
2. **Quota Exceeded**: Monitor Firebase usage quotas
3. **Network Timeouts**: Use smaller batch sizes
4. **Invalid Data**: Validate data structure before importing

### Error Codes

- `PERMISSION_DENIED`: Check authentication and security rules
- `RESOURCE_EXHAUSTED`: You've hit quota limits
- `DEADLINE_EXCEEDED`: Operation timed out
- `INVALID_ARGUMENT`: Check data format and types

## Best Practices

1. **Always backup** before major data operations
2. **Test with small datasets** first
3. **Use transactions** for related document updates
4. **Monitor costs** during large operations
5. **Set up alerts** for unusual activity
6. **Use staging environment** for testing

## Production Checklist

- [ ] Service account key is secure and not in version control
- [ ] Firestore security rules are properly configured
- [ ] Backup created before data migration
- [ ] Data validation script tested
- [ ] Staging environment tested
- [ ] Monitoring and alerts configured
- [ ] Rollback plan prepared