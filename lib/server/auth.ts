import 'server-only';
import { betterAuth, type Auth, type BetterAuthOptions } from 'better-auth';
import nodemailer from 'nodemailer';
import { pool } from './db';

export function origin(): string {
  const value = process.env.APP_ORIGIN;
  if (!value) throw new Error('APP_ORIGIN is required');
  const url = new URL(value);
  if (process.env.NODE_ENV === 'production' && url.protocol !== 'https:') throw new Error('HTTPS is required');
  return url.origin;
}

function mailConfiguration() {
  const { SMTP_HOST, SMTP_USER, SMTP_PASSWORD, SMTP_FROM, SMTP_PORT, SMTP_SECURE } = process.env;
  const port = Number(SMTP_PORT);
  const secure = SMTP_SECURE === 'true';
  if (!SMTP_HOST || !SMTP_USER || !SMTP_PASSWORD || !SMTP_FROM
    || !SMTP_PORT || !Number.isFinite(port) || !Number.isInteger(port) || port < 1 || port > 65535
    || SMTP_SECURE !== 'true' && SMTP_SECURE !== 'false') {
    throw new Error('Authenticated TLS SMTP is required: SMTP_PORT must be an integer from 1 to 65535 and SMTP_SECURE must be explicitly true or false');
  }
  return { host: SMTP_HOST, port, secure, requireTLS: true,
    auth: { user: SMTP_USER, pass: SMTP_PASSWORD }, tls: { minVersion: 'TLSv1.2' as const },
    connectionTimeout: 10000, greetingTimeout: 10000, socketTimeout: 20000 };
}

let authentication: Auth | undefined;
export function auth(): Auth {
  if (!authentication) {
    const baseURL = origin();
    const secret = process.env.BETTER_AUTH_SECRET;
    if (!secret || secret.length < 32) throw new Error('BETTER_AUTH_SECRET must contain at least 32 characters');
    const transport = nodemailer.createTransport(mailConfiguration());
    // This long-running Node deployment retains the delivery promise without delaying
    // account-discovery-sensitive responses. Failures are visible without logging tokens.
    const send = (to: string, subject: string, text: string) => {
      void transport.sendMail({ from: process.env.SMTP_FROM, to, subject, text })
        .catch(() => console.error('Authentication email delivery failed'));
    };
    const instance = betterAuth<BetterAuthOptions>({
      appName: 'Boarded', database: pool(), baseURL, secret,
      trustedOrigins: [baseURL],
      advanced: {
        database: { generateId: 'uuid' },
        useSecureCookies: baseURL.startsWith('https:'),
        defaultCookieAttributes: { httpOnly: true, sameSite: 'lax', secure: baseURL.startsWith('https:') },
        ipAddress: { ipAddressHeaders: ['x-real-ip'] },
      },
      emailAndPassword: {
        enabled: true, minPasswordLength: 8, maxPasswordLength: 128,
        requireEmailVerification: true, autoSignIn: false,
        revokeSessionsOnPasswordReset: true,
        sendResetPassword: async ({ user, url }) => send(user.email, 'Reset your Boarded password', `Reset your password: ${url}`),
      },
      emailVerification: {
        sendOnSignUp: true, sendOnSignIn: true, autoSignInAfterVerification: false,
        expiresIn: 3600,
        sendVerificationEmail: async ({ user, url }) => send(user.email, 'Verify your Boarded email', `Verify your email: ${url}`),
      },
      session: { expiresIn: 60 * 60 * 24 * 7, updateAge: 60 * 60 * 24, cookieCache: { enabled: false } },
      rateLimit: {
        enabled: true, storage: 'database', window: 60, max: 100,
        customRules: {
          '/sign-in/email': { window: 60, max: 10 },
          '/sign-up/email': { window: 60, max: 5 },
          '/request-password-reset': { window: 60, max: 5 },
          '/send-verification-email': { window: 60, max: 5 },
        },
      },
    });
    authentication = instance;
    return instance;
  }
  return authentication;
}
