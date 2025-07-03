import { SupabaseManager } from './supabase.js';
import chalk from 'chalk';

export class ContentValidator {
  constructor(options = {}) {
    this.fix = options.fix || false;
    this.verbose = options.verbose || false;
    this.supabase = new SupabaseManager();
  }

  async run() {
    const errors = [];
    const warnings = [];
    
    try {
      console.log(chalk.blue('🔍 Validating content in database...'));
      
      // Get all guides from database
      const guides = await this.supabase.getAllGuides();
      
      if (guides.length === 0) {
        warnings.push('No prayer guides found in database');
        return { errors, warnings };
      }
      
      console.log(chalk.green(`Found ${guides.length} prayer guides to validate`));
      
      // Validate each guide
      for (const guide of guides) {
        await this.validateGuide(guide, errors, warnings);
      }
      
      // Check for missing prayers
      this.checkMissingPrayers(guides, warnings);
      
      // Check for duplicate content
      this.checkDuplicates(guides, errors);
      
      return { errors, warnings };
      
    } catch (error) {
      errors.push(`Validation failed: ${error.message}`);
      return { errors, warnings };
    }
  }

  async validateGuide(guide, errors, warnings) {
    const prefix = `[${guide.content_id}]`;
    
    // Validate required fields
    if (!guide.title || guide.title.trim().length === 0) {
      errors.push(`${prefix} Missing or empty title`);
    }
    
    if (!guide.prayer_name || !['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'].includes(guide.prayer_name)) {
      errors.push(`${prefix} Invalid prayer name: ${guide.prayer_name}`);
    }
    
    if (!guide.sect || !['sunni', 'shia'].includes(guide.sect)) {
      errors.push(`${prefix} Invalid sect: ${guide.sect}`);
    }
    
    if (!guide.rakah_count || guide.rakah_count < 1 || guide.rakah_count > 4) {
      errors.push(`${prefix} Invalid rakah count: ${guide.rakah_count}`);
    }
    
    // Validate content structure
    if (guide.text_content) {
      try {
        const content = typeof guide.text_content === 'string' 
          ? JSON.parse(guide.text_content) 
          : guide.text_content;
        
        this.validateContentStructure(content, guide.content_id, errors, warnings);
      } catch (error) {
        errors.push(`${prefix} Invalid JSON in text_content: ${error.message}`);
      }
    } else {
      warnings.push(`${prefix} No text content found`);
    }
    
    // Validate video URL if present
    if (guide.video_url) {
      if (!this.isValidUrl(guide.video_url)) {
        errors.push(`${prefix} Invalid video URL: ${guide.video_url}`);
      }
    }
    
    // Validate content ID format
    if (!guide.content_id.match(/^[a-z]+_[a-z]+_guide$/)) {
      warnings.push(`${prefix} Content ID doesn't follow naming convention (prayer_sect_guide)`);
    }
    
    if (this.verbose) {
      console.log(chalk.gray(`  ✓ Validated ${guide.title}`));
    }
  }

  validateContentStructure(content, contentId, errors, warnings) {
    const prefix = `[${contentId}]`;
    
    // Check for steps array
    if (!content.steps || !Array.isArray(content.steps)) {
      errors.push(`${prefix} Missing or invalid steps array in content`);
      return;
    }
    
    if (content.steps.length === 0) {
      warnings.push(`${prefix} No steps found in content`);
    }
    
    // Validate each step
    content.steps.forEach((step, index) => {
      if (!step.title || step.title.trim().length === 0) {
        errors.push(`${prefix} Step ${index + 1} missing title`);
      }
      
      if (!step.description || step.description.trim().length === 0) {
        warnings.push(`${prefix} Step ${index + 1} missing description`);
      }
      
      if (step.arabic && step.arabic.trim().length > 0) {
        // Check if Arabic text contains Arabic characters
        if (!/[\u0600-\u06FF]/.test(step.arabic)) {
          warnings.push(`${prefix} Step ${index + 1} Arabic text may not contain Arabic characters`);
        }
      }
    });
    
    // Check for rakah instructions
    if (!content.rakah_instructions || !Array.isArray(content.rakah_instructions)) {
      warnings.push(`${prefix} Missing rakah instructions`);
    } else if (content.rakah_instructions.length === 0) {
      warnings.push(`${prefix} Empty rakah instructions array`);
    }
  }

  checkMissingPrayers(guides, warnings) {
    const prayers = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
    const sects = ['sunni', 'shia'];
    
    for (const prayer of prayers) {
      for (const sect of sects) {
        const found = guides.find(g => g.prayer_name === prayer && g.sect === sect);
        if (!found) {
          warnings.push(`Missing ${prayer} prayer guide for ${sect} tradition`);
        }
      }
    }
  }

  checkDuplicates(guides, errors) {
    const contentIds = new Set();
    const combinations = new Set();
    
    for (const guide of guides) {
      // Check for duplicate content IDs
      if (contentIds.has(guide.content_id)) {
        errors.push(`Duplicate content ID: ${guide.content_id}`);
      }
      contentIds.add(guide.content_id);
      
      // Check for duplicate prayer/sect combinations
      const combination = `${guide.prayer_name}_${guide.sect}`;
      if (combinations.has(combination)) {
        errors.push(`Duplicate prayer/sect combination: ${combination}`);
      }
      combinations.add(combination);
    }
  }

  isValidUrl(string) {
    try {
      new URL(string);
      return true;
    } catch (_) {
      return false;
    }
  }
}
