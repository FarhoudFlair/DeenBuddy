#!/usr/bin/env node

import { program } from 'commander';
import chalk from 'chalk';
import { ContentIngester } from './ingester.js';
import { ContentValidator } from './validator.js';
import { SupabaseManager } from './supabase.js';

program
  .name('deenbuddy-content')
  .description('DeenBuddy Content Management Pipeline')
  .version('1.0.0');

program
  .command('ingest')
  .description('Ingest content from source directory')
  .option('-s, --source <path>', 'Source directory path', './content')
  .option('-d, --dry-run', 'Perform a dry run without uploading')
  .option('-v, --verbose', 'Verbose output')
  .action(async (options) => {
    try {
      console.log(chalk.blue('🚀 Starting content ingestion...'));
      
      const ingester = new ContentIngester({
        sourcePath: options.source,
        dryRun: options.dryRun,
        verbose: options.verbose
      });
      
      await ingester.run();
      console.log(chalk.green('✅ Content ingestion completed successfully!'));
    } catch (error) {
      console.error(chalk.red('❌ Content ingestion failed:'), error.message);
      process.exit(1);
    }
  });

program
  .command('validate')
  .description('Validate existing content in database')
  .option('-f, --fix', 'Attempt to fix validation errors')
  .option('-v, --verbose', 'Verbose output')
  .action(async (options) => {
    try {
      console.log(chalk.blue('🔍 Starting content validation...'));
      
      const validator = new ContentValidator({
        fix: options.fix,
        verbose: options.verbose
      });
      
      const results = await validator.run();
      
      if (results.errors.length === 0) {
        console.log(chalk.green('✅ All content is valid!'));
      } else {
        console.log(chalk.yellow(`⚠️  Found ${results.errors.length} validation errors`));
        results.errors.forEach(error => {
          console.log(chalk.red(`  - ${error}`));
        });
      }
    } catch (error) {
      console.error(chalk.red('❌ Content validation failed:'), error.message);
      process.exit(1);
    }
  });

program
  .command('sync')
  .description('Sync content with Supabase')
  .option('-f, --force', 'Force sync even if content exists')
  .action(async (options) => {
    try {
      console.log(chalk.blue('🔄 Starting content sync...'));
      
      const supabase = new SupabaseManager();
      await supabase.syncContent({ force: options.force });
      
      console.log(chalk.green('✅ Content sync completed!'));
    } catch (error) {
      console.error(chalk.red('❌ Content sync failed:'), error.message);
      process.exit(1);
    }
  });

program
  .command('status')
  .description('Show content pipeline status')
  .action(async () => {
    try {
      const supabase = new SupabaseManager();
      const status = await supabase.getStatus();
      
      console.log(chalk.blue('📊 Content Pipeline Status'));
      console.log(chalk.gray('─'.repeat(40)));
      console.log(`Total Guides: ${chalk.green(status.totalGuides)}`);
      console.log(`Sunni Guides: ${chalk.green(status.sunniGuides)}`);
      console.log(`Shia Guides: ${chalk.green(status.shiaGuides)}`);
      console.log(`Offline Available: ${chalk.green(status.offlineGuides)}`);
      console.log(`Pending Downloads: ${chalk.yellow(status.pendingDownloads)}`);
      
      if (status.recentUpdates.length > 0) {
        console.log(chalk.blue('\n📅 Recent Updates:'));
        status.recentUpdates.forEach(update => {
          console.log(`  ${chalk.gray(update.date)} - ${update.title}`);
        });
      }
    } catch (error) {
      console.error(chalk.red('❌ Failed to get status:'), error.message);
      process.exit(1);
    }
  });

program.parse();
