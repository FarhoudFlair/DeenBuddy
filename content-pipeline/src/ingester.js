import fs from 'fs/promises';
import path from 'path';
import { marked } from 'marked';
import yaml from 'yaml';
import chalk from 'chalk';
import ora from 'ora';
import { SupabaseManager } from './supabase.js';

export class ContentIngester {
  constructor(options = {}) {
    this.sourcePath = options.sourcePath || './content';
    this.dryRun = options.dryRun || false;
    this.verbose = options.verbose || false;
    this.supabase = new SupabaseManager();
  }

  async run() {
    const spinner = ora('Scanning content directory...').start();
    
    try {
      // Check if source directory exists
      await fs.access(this.sourcePath);
      
      // Find all markdown files
      const markdownFiles = await this.findMarkdownFiles(this.sourcePath);
      spinner.succeed(`Found ${markdownFiles.length} markdown files`);
      
      if (markdownFiles.length === 0) {
        console.log(chalk.yellow('No markdown files found in source directory'));
        return;
      }

      // Process each file
      const results = [];
      for (const filePath of markdownFiles) {
        spinner.start(`Processing ${path.basename(filePath)}...`);
        
        try {
          const result = await this.processMarkdownFile(filePath);
          results.push(result);
          spinner.succeed(`Processed ${result.contentId}`);
        } catch (error) {
          spinner.fail(`Failed to process ${path.basename(filePath)}: ${error.message}`);
          if (this.verbose) {
            console.error(error);
          }
        }
      }

      // Upload to Supabase if not dry run
      if (!this.dryRun && results.length > 0) {
        spinner.start('Uploading to Supabase...');
        
        for (const guide of results) {
          await this.supabase.upsertGuide(guide);
        }
        
        spinner.succeed(`Uploaded ${results.length} guides to Supabase`);
      }

      // Summary
      console.log(chalk.blue('\n📊 Ingestion Summary:'));
      console.log(`Files processed: ${chalk.green(results.length)}`);
      console.log(`Dry run: ${this.dryRun ? chalk.yellow('Yes') : chalk.green('No')}`);
      
      if (this.verbose && results.length > 0) {
        console.log(chalk.blue('\n📋 Processed Content:'));
        results.forEach(guide => {
          console.log(`  ${chalk.green('✓')} ${guide.title} (${guide.contentId})`);
        });
      }

    } catch (error) {
      spinner.fail('Content ingestion failed');
      throw error;
    }
  }

  async findMarkdownFiles(dir) {
    const files = [];
    
    async function scanDirectory(currentDir) {
      const entries = await fs.readdir(currentDir, { withFileTypes: true });
      
      for (const entry of entries) {
        const fullPath = path.join(currentDir, entry.name);
        
        if (entry.isDirectory()) {
          await scanDirectory(fullPath);
        } else if (entry.isFile() && entry.name.endsWith('.md')) {
          files.push(fullPath);
        }
      }
    }
    
    await scanDirectory(dir);
    return files;
  }

  async processMarkdownFile(filePath) {
    const content = await fs.readFile(filePath, 'utf-8');
    
    // Parse frontmatter and content
    const { frontmatter, markdown } = this.parseFrontmatter(content);
    
    // Validate required frontmatter fields
    this.validateFrontmatter(frontmatter, filePath);
    
    // Convert markdown to structured content
    const structuredContent = await this.markdownToStructuredContent(markdown);
    
    // Look for associated video file
    const videoUrl = await this.findAssociatedVideo(filePath, frontmatter.contentId);
    
    // Create guide object
    const guide = {
      content_id: frontmatter.contentId,
      contentId: frontmatter.contentId, // Add for compatibility with logging
      title: frontmatter.title,
      prayer_name: frontmatter.prayerName,
      sect: frontmatter.sect,
      rakah_count: frontmatter.rakahCount,
      content_type: videoUrl ? 'mixed' : 'text',
      text_content: structuredContent,
      video_url: videoUrl,
      thumbnail_url: frontmatter.thumbnailUrl || null,
      version: frontmatter.version || 1,
      updated_at: new Date().toISOString()
    };

    return guide;
  }

  parseFrontmatter(content) {
    const frontmatterRegex = /^---\n([\s\S]*?)\n---\n([\s\S]*)$/;
    const match = content.match(frontmatterRegex);
    
    if (!match) {
      throw new Error('No frontmatter found in markdown file');
    }
    
    const frontmatter = yaml.parse(match[1]);
    const markdown = match[2];
    
    return { frontmatter, markdown };
  }

  validateFrontmatter(frontmatter, filePath) {
    const required = ['contentId', 'title', 'prayerName', 'sect', 'rakahCount'];
    const missing = required.filter(field => !frontmatter[field]);
    
    if (missing.length > 0) {
      throw new Error(`Missing required frontmatter fields in ${filePath}: ${missing.join(', ')}`);
    }
    
    // Validate sect
    if (!['sunni', 'shia'].includes(frontmatter.sect)) {
      throw new Error(`Invalid sect "${frontmatter.sect}" in ${filePath}. Must be "sunni" or "shia"`);
    }
    
    // Validate prayer name
    const validPrayers = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
    if (!validPrayers.includes(frontmatter.prayerName)) {
      throw new Error(`Invalid prayer name "${frontmatter.prayerName}" in ${filePath}`);
    }
    
    // Validate rakah count
    if (!Number.isInteger(frontmatter.rakahCount) || frontmatter.rakahCount < 1) {
      throw new Error(`Invalid rakah count "${frontmatter.rakahCount}" in ${filePath}`);
    }
  }

  async markdownToStructuredContent(markdown) {
    // Parse markdown to tokens
    const tokens = marked.lexer(markdown);
    
    const steps = [];
    const rakahInstructions = [];
    let currentStep = null;
    let stepCounter = 1;
    
    for (const token of tokens) {
      if (token.type === 'heading' && token.depth === 2) {
        // Save previous step if exists
        if (currentStep) {
          steps.push(currentStep);
        }
        
        // Start new step
        currentStep = {
          step: stepCounter++,
          title: token.text,
          description: '',
          arabic: '',
          transliteration: ''
        };
      } else if (token.type === 'paragraph' && currentStep) {
        // Add to current step description
        if (!currentStep.description) {
          currentStep.description = token.text;
        } else {
          // Check if this is Arabic text (contains Arabic characters)
          if (/[\u0600-\u06FF]/.test(token.text)) {
            currentStep.arabic = token.text;
          } else if (token.text.includes('transliteration:') || token.text.includes('Transliteration:')) {
            currentStep.transliteration = token.text.replace(/^.*?transliteration:\s*/i, '');
          }
        }
      } else if (token.type === 'list' && token.ordered === false) {
        // This might be rakah instructions
        token.items.forEach(item => {
          if (item.text.toLowerCase().includes('rakah')) {
            rakahInstructions.push(item.text);
          }
        });
      }
    }
    
    // Add the last step
    if (currentStep) {
      steps.push(currentStep);
    }
    
    return {
      steps,
      rakah_instructions: rakahInstructions
    };
  }

  async findAssociatedVideo(markdownPath, contentId) {
    const dir = path.dirname(markdownPath);
    const videoExtensions = ['.mp4', '.mov', '.m3u8'];
    
    for (const ext of videoExtensions) {
      const videoPath = path.join(dir, `${contentId}${ext}`);
      
      try {
        await fs.access(videoPath);
        // For now, return a placeholder URL
        // In production, this would upload to storage and return the URL
        return `https://storage.supabase.co/v1/object/public/prayer-guides/${contentId}${ext}`;
      } catch {
        // File doesn't exist, continue
      }
    }
    
    return null;
  }
}
