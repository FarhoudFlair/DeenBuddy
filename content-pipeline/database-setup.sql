-- DeenBuddy Supabase Database Schema
-- This script sets up the database schema for the DeenBuddy content pipeline

-- Drop existing tables if they exist (for clean setup)
DROP TABLE IF EXISTS content_downloads CASCADE;
DROP TABLE IF EXISTS prayer_guides CASCADE;

-- Create prayer_guides table
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

-- Create content_downloads table for tracking offline content
CREATE TABLE content_downloads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  guide_id UUID REFERENCES prayer_guides(id) ON DELETE CASCADE,
  download_status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (download_status IN ('pending', 'downloading', 'completed', 'failed')),
  download_progress INTEGER DEFAULT 0 CHECK (download_progress >= 0 AND download_progress <= 100),
  file_size BIGINT,
  downloaded_size BIGINT DEFAULT 0,
  error_message TEXT,
  started_at TIMESTAMP WITH TIME ZONE,
  completed_at TIMESTAMP WITH TIME ZONE
);

-- Create indexes for better performance
CREATE INDEX idx_prayer_guides_prayer_name ON prayer_guides(prayer_name);
CREATE INDEX idx_prayer_guides_sect ON prayer_guides(sect);
CREATE INDEX idx_prayer_guides_content_id ON prayer_guides(content_id);
CREATE INDEX idx_prayer_guides_updated_at ON prayer_guides(updated_at);
CREATE INDEX idx_content_downloads_guide_id ON content_downloads(guide_id);
CREATE INDEX idx_content_downloads_status ON content_downloads(download_status);

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger for prayer_guides
CREATE TRIGGER update_prayer_guides_updated_at 
    BEFORE UPDATE ON prayer_guides 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Enable Row Level Security (RLS)
ALTER TABLE prayer_guides ENABLE ROW LEVEL SECURITY;
ALTER TABLE content_downloads ENABLE ROW LEVEL SECURITY;

-- Create policies for public read access (since this is content, not user data)
CREATE POLICY "Allow public read access on prayer_guides" ON prayer_guides
    FOR SELECT USING (true);

CREATE POLICY "Allow public read access on content_downloads" ON content_downloads
    FOR SELECT USING (true);

-- Allow authenticated users to insert/update (for content management)
CREATE POLICY "Allow authenticated insert on prayer_guides" ON prayer_guides
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Allow authenticated update on prayer_guides" ON prayer_guides
    FOR UPDATE USING (auth.role() = 'authenticated');

CREATE POLICY "Allow authenticated insert on content_downloads" ON content_downloads
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Allow authenticated update on content_downloads" ON content_downloads
    FOR UPDATE USING (auth.role() = 'authenticated');
