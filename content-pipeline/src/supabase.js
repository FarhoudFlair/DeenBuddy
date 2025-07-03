import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import chalk from 'chalk';

dotenv.config();

export class SupabaseManager {
  constructor() {
    const supabaseUrl = process.env.SUPABASE_URL || 'https://bbccqnfxgtdjhorhocwq.supabase.co';
    const supabaseKey = process.env.SUPABASE_ANON_KEY;
    
    if (!supabaseKey) {
      throw new Error('SUPABASE_ANON_KEY environment variable is required');
    }
    
    this.supabase = createClient(supabaseUrl, supabaseKey);
  }

  async getStatus() {
    try {
      // Get total guides count
      const { count: totalGuides } = await this.supabase
        .from('prayer_guides')
        .select('*', { count: 'exact', head: true });

      // Get Sunni guides count
      const { count: sunniGuides } = await this.supabase
        .from('prayer_guides')
        .select('*', { count: 'exact', head: true })
        .eq('sect', 'sunni');

      // Get Shia guides count
      const { count: shiaGuides } = await this.supabase
        .from('prayer_guides')
        .select('*', { count: 'exact', head: true })
        .eq('sect', 'shia');

      // Get offline available guides count
      const { count: offlineGuides } = await this.supabase
        .from('prayer_guides')
        .select('*', { count: 'exact', head: true })
        .eq('is_available_offline', true);

      // Get pending downloads count
      const { count: pendingDownloads } = await this.supabase
        .from('content_downloads')
        .select('*', { count: 'exact', head: true })
        .in('download_status', ['pending', 'downloading']);

      // Get recent updates
      const { data: recentUpdates } = await this.supabase
        .from('prayer_guides')
        .select('title, updated_at')
        .order('updated_at', { ascending: false })
        .limit(5);

      return {
        totalGuides: totalGuides || 0,
        sunniGuides: sunniGuides || 0,
        shiaGuides: shiaGuides || 0,
        offlineGuides: offlineGuides || 0,
        pendingDownloads: pendingDownloads || 0,
        recentUpdates: (recentUpdates || []).map(update => ({
          title: update.title,
          date: new Date(update.updated_at).toLocaleDateString()
        }))
      };
    } catch (error) {
      throw new Error(`Failed to get status: ${error.message}`);
    }
  }

  async getAllGuides() {
    try {
      const { data, error } = await this.supabase
        .from('prayer_guides')
        .select('*')
        .order('prayer_name', { ascending: true })
        .order('sect', { ascending: true });

      if (error) throw error;
      return data || [];
    } catch (error) {
      throw new Error(`Failed to get guides: ${error.message}`);
    }
  }

  async getGuideByContentId(contentId) {
    try {
      const { data, error } = await this.supabase
        .from('prayer_guides')
        .select('*')
        .eq('content_id', contentId)
        .single();

      if (error && error.code !== 'PGRST116') throw error;
      return data;
    } catch (error) {
      throw new Error(`Failed to get guide: ${error.message}`);
    }
  }

  async upsertGuide(guide) {
    try {
      const { data, error } = await this.supabase
        .from('prayer_guides')
        .upsert(guide, { 
          onConflict: 'content_id',
          returning: 'minimal'
        });

      if (error) throw error;
      return data;
    } catch (error) {
      throw new Error(`Failed to upsert guide: ${error.message}`);
    }
  }

  async deleteGuide(contentId) {
    try {
      const { error } = await this.supabase
        .from('prayer_guides')
        .delete()
        .eq('content_id', contentId);

      if (error) throw error;
    } catch (error) {
      throw new Error(`Failed to delete guide: ${error.message}`);
    }
  }

  async createDownloadRecord(guideId, fileSize) {
    try {
      const { data, error } = await this.supabase
        .from('content_downloads')
        .insert({
          guide_id: guideId,
          file_size: fileSize,
          download_status: 'pending'
        })
        .select()
        .single();

      if (error) throw error;
      return data;
    } catch (error) {
      throw new Error(`Failed to create download record: ${error.message}`);
    }
  }

  async updateDownloadProgress(downloadId, progress, downloadedSize) {
    try {
      const { error } = await this.supabase
        .from('content_downloads')
        .update({
          download_progress: progress,
          downloaded_size: downloadedSize,
          download_status: progress >= 100 ? 'completed' : 'downloading'
        })
        .eq('id', downloadId);

      if (error) throw error;
    } catch (error) {
      throw new Error(`Failed to update download progress: ${error.message}`);
    }
  }

  async syncContent({ force = false } = {}) {
    console.log(chalk.blue('🔄 Syncing content with Supabase...'));
    
    const guides = await this.getAllGuides();
    console.log(chalk.green(`Found ${guides.length} guides in database`));
    
    // Here you would implement the actual sync logic
    // For now, just return the current state
    return {
      synced: guides.length,
      errors: []
    };
  }
}
