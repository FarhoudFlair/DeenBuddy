# DeenBuddy Database Setup Guide

## Quick Setup

To set up the Supabase database for DeenBuddy, follow these steps:

### 1. Access Supabase Dashboard

1. Go to [https://supabase.com/dashboard](https://supabase.com/dashboard)
2. Navigate to your DeenBuddy project: `https://hjgwbkcjjclwqamtmhsa.supabase.co`
3. Click on the "SQL Editor" tab in the left sidebar

### 2. Run Database Setup Script

1. In the SQL Editor, copy and paste the contents of `database-setup.sql`
2. Click "Run" to execute the script
3. This will create the required tables and indexes

### 3. Verify Setup

After running the script, you should see these tables in your database:

- `prayer_guides` - Main table for storing prayer guide content
- `content_downloads` - Table for tracking offline content downloads

### 4. Test Connection

Run the following command from the content-pipeline directory to test the connection:

```bash
npm run status
```

You should see output like:
```
📊 Content Pipeline Status
────────────────────────────────────────
Total Guides: 0
Sunni Guides: 0
Shia Guides: 0
Offline Available: 0
Pending Downloads: 0
```

## Manual Setup (Alternative)

If you prefer to set up the tables manually, here are the key tables:

### prayer_guides Table

```sql
CREATE TABLE prayer_guides (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  content_id VARCHAR(100) UNIQUE NOT NULL,
  title VARCHAR(200) NOT NULL,
  prayer_name VARCHAR(50) NOT NULL,
  sect VARCHAR(20) NOT NULL CHECK (sect IN ('sunni', 'shia')),
  rakah_count INTEGER NOT NULL,
  content_type VARCHAR(20) NOT NULL DEFAULT 'guide',
  text_content JSONB,
  video_url TEXT,
  thumbnail_url TEXT,
  is_available_offline BOOLEAN DEFAULT FALSE,
  local_data BYTEA,
  version INTEGER DEFAULT 1,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### content_downloads Table

```sql
CREATE TABLE content_downloads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  guide_id UUID REFERENCES prayer_guides(id) ON DELETE CASCADE,
  download_status VARCHAR(20) NOT NULL DEFAULT 'pending',
  download_progress INTEGER DEFAULT 0,
  file_size BIGINT,
  downloaded_size BIGINT DEFAULT 0,
  error_message TEXT,
  started_at TIMESTAMP WITH TIME ZONE,
  completed_at TIMESTAMP WITH TIME ZONE
);
```

## Next Steps

Once the database is set up:

1. Test the content pipeline: `npm run validate`
2. Ingest sample content: `npm run ingest --dry-run`
3. Upload content to Supabase: `npm run ingest`
