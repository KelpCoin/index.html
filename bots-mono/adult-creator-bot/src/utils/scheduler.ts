import cron from 'node-cron';
import type { Knex } from 'knex';

export type JobDefinition = {
  name: string;
  schedule: string;
  jitterSeconds: number;
  task: () => Promise<void>;
};

export function scheduleJob(job: JobDefinition, db: Knex) {
  cron.schedule(job.schedule, async () => {
    const jitter = Math.floor(Math.random() * job.jitterSeconds * 1000);
    await new Promise((resolve) => setTimeout(resolve, jitter));
    await job.task();
    await db('job_runs')
      .insert({ job_name: job.name, last_run_at: new Date() })
      .onConflict('job_name')
      .merge({ last_run_at: new Date() });
  });
}
