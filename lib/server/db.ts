import 'server-only';
import { Pool, type PoolClient } from 'pg';

let database: Pool | undefined;
export function pool(): Pool {
  if (!database) {
    if (!process.env.DATABASE_URL) throw new Error('DATABASE_URL is required');
    database = new Pool({ connectionString: process.env.DATABASE_URL, max: 10, connectionTimeoutMillis: 5000, idleTimeoutMillis: 30000, statement_timeout: 15000 });
    database.on('error', () => console.error('PostgreSQL pool connection failed'));
  }
  return database;
}

export async function transaction<T>(operation: (client: PoolClient) => Promise<T>): Promise<T> {
  const client = await pool().connect();
  try {
    await client.query('BEGIN');
    const result = await operation(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}
