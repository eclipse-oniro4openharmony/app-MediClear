import { createHmac, createHash, randomBytes, randomInt, scrypt, timingSafeEqual } from 'node:crypto';
import { promisify } from 'node:util';
import express from 'express';
import rateLimit from 'express-rate-limit';
import { SignJWT, jwtVerify } from 'jose';
import nodemailer from 'nodemailer';
import { ObjectId } from 'mongodb';
import { z } from 'zod';
import { config } from './config.js';
import { getAuthCollections } from './database.js';

const scryptAsync = promisify(scrypt);
const ACCESS_TOKEN_SECONDS = 15 * 60;
const REFRESH_TOKEN_DAYS = 30;
const EMAIL_CODE_TTL_MS = 15 * 60 * 1000;
const CODE_RESEND_DELAY_MS = 60 * 1000;

const registerSchema = z.object({
  email: z.string().trim().email().max(254),
  password: z.string().min(12).max(128)
});
const loginSchema = z.object({
  email: z.string().trim().email().max(254),
  password: z.string().min(1).max(128)
});
const emailCodeSchema = z.object({
  email: z.string().trim().email().max(254),
  code: z.string().regex(/^\d{6}$/)
});
const resetPasswordSchema = emailCodeSchema.extend({
  password: z.string().min(12).max(128)
});
function httpError(statusCode, message) {
  const error = new Error(message);
  error.statusCode = statusCode;
  return error;
}

function authSecret() {
  if (config.authTokenSecret.length < 32) {
    throw httpError(503, 'Authentication is not configured. Set AUTH_TOKEN_SECRET to at least 32 characters.');
  }
  return new TextEncoder().encode(config.authTokenSecret);
}

function normalizeEmail(email) {
  return email.trim().toLowerCase();
}

async function hashPassword(password) {
  const salt = randomBytes(16);
  const derivedKey = await scryptAsync(password, salt, 64, {
    N: 32768,
    r: 8,
    p: 1,
    maxmem: 64 * 1024 * 1024
  });
  return `scrypt$32768$8$1$${salt.toString('base64url')}$${Buffer.from(derivedKey).toString('base64url')}`;
}

async function verifyPassword(password, encodedHash) {
  const [algorithm, nValue, rValue, pValue, saltValue, hashValue] = encodedHash.split('$');
  if (algorithm !== 'scrypt' || !saltValue || !hashValue) {
    return false;
  }

  const expected = Buffer.from(hashValue, 'base64url');
  const derivedKey = Buffer.from(await scryptAsync(password, Buffer.from(saltValue, 'base64url'), expected.length, {
    N: Number.parseInt(nValue, 10),
    r: Number.parseInt(rValue, 10),
    p: Number.parseInt(pValue, 10),
    maxmem: 64 * 1024 * 1024
  }));
  return expected.length === derivedKey.length && timingSafeEqual(expected, derivedKey);
}

function codeDigest(email, purpose, code) {
  return createHmac('sha256', authSecret())
    .update(`${purpose}:${email}:${code}`)
    .digest('hex');
}

function makeRefreshToken() {
  return randomBytes(48).toString('base64url');
}

function hashRefreshToken(token) {
  return createHash('sha256').update(token).digest('hex');
}

async function makeAccessToken(user) {
  return new SignJWT({ email: user.email })
    .setProtectedHeader({ alg: 'HS256' })
    .setSubject(user._id.toString())
    .setIssuer('mediclear-backend')
    .setAudience('mediclear-app')
    .setIssuedAt()
    .setExpirationTime(`${ACCESS_TOKEN_SECONDS}s`)
    .sign(authSecret());
}

async function createSession(user) {
  const { refreshSessions } = getAuthCollections();
  const refreshToken = makeRefreshToken();
  const expiresAt = new Date(Date.now() + REFRESH_TOKEN_DAYS * 24 * 60 * 60 * 1000);
  await refreshSessions.insertOne({
    userId: user._id,
    tokenHash: hashRefreshToken(refreshToken),
    createdAt: new Date(),
    expiresAt
  });

  return {
    accessToken: await makeAccessToken(user),
    refreshToken,
    accessTokenExpiresIn: ACCESS_TOKEN_SECONDS,
    user: { id: user._id.toString(), email: user.email }
  };
}

async function deliverEmailCode(email, purpose, code) {
  if (config.authEmailMode === 'console' && config.nodeEnv !== 'production') {
    console.info(`[auth-email:development] purpose=${purpose} email=${email} code=${code}`);
    return;
  }
  if (!config.smtpHost || !config.smtpFrom) {
    throw httpError(503, 'Email delivery is not configured. Set SMTP_HOST and SMTP_FROM.');
  }

  const transporter = nodemailer.createTransport({
    host: config.smtpHost,
    port: config.smtpPort,
    secure: config.smtpSecure,
    auth: config.smtpUser.length > 0 ? {
      user: config.smtpUser,
      pass: config.smtpPassword
    } : undefined
  });
  const isVerification = purpose === 'verify-email';
  await transporter.sendMail({
    from: config.smtpFrom,
    to: email,
    subject: isVerification ? 'Verify your MediClear account' : 'Reset your MediClear password',
    text: isVerification
      ? `Your MediClear verification code is ${code}. It expires in 15 minutes.`
      : `Your MediClear password reset code is ${code}. It expires in 15 minutes.`
  });
}

async function issueEmailCode(email, userId, purpose) {
  const { verificationCodes } = getAuthCollections();
  const now = new Date();
  const existing = await verificationCodes.findOne({ email, purpose });
  if (existing && now.getTime() - existing.createdAt.getTime() < CODE_RESEND_DELAY_MS) {
    throw httpError(429, 'Please wait before requesting another email code.');
  }

  const code = randomInt(0, 1000000).toString().padStart(6, '0');
  const codeHash = codeDigest(email, purpose, code);
  await verificationCodes.updateOne(
    { email, purpose },
    {
      $set: {
        userId,
        codeHash,
        createdAt: now,
        expiresAt: new Date(now.getTime() + EMAIL_CODE_TTL_MS),
        attempts: 0
      }
    },
    { upsert: true }
  );

  try {
    await deliverEmailCode(email, purpose, code);
  } catch (error) {
    await verificationCodes.deleteOne({ email, purpose, codeHash });
    throw error;
  }
}

async function consumeEmailCode(email, purpose, code) {
  const { verificationCodes } = getAuthCollections();
  const record = await verificationCodes.findOne({
    email,
    purpose,
    expiresAt: { $gt: new Date() }
  });
  if (!record) {
    return null;
  }

  const suppliedHash = Buffer.from(codeDigest(email, purpose, code), 'hex');
  const storedHash = Buffer.from(record.codeHash, 'hex');
  const matches = suppliedHash.length === storedHash.length && timingSafeEqual(suppliedHash, storedHash);
  if (!matches) {
    const attempts = record.attempts + 1;
    if (attempts >= 5) {
      await verificationCodes.deleteOne({ _id: record._id });
    } else {
      await verificationCodes.updateOne({ _id: record._id }, { $set: { attempts } });
    }
    return null;
  }

  await verificationCodes.deleteOne({ _id: record._id });
  return record;
}

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 120,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many authentication requests. Please try again later.' }
});
const emailCodeLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  limit: 5,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many email code requests. Please try again later.' }
});

export function createAuthRouter() {
  const router = express.Router();
  router.use(authLimiter);

  router.post('/register', emailCodeLimiter, async (request, response, next) => {
    try {
      const parsed = registerSchema.safeParse(request.body);
      if (!parsed.success) {
        response.status(400).json({ error: parsed.error.issues[0]?.message ?? 'Invalid registration details' });
        return;
      }

      const email = normalizeEmail(parsed.data.email);
      const { users } = getAuthCollections();
      const existing = await users.findOne({ email });
      if (existing?.emailVerified) {
        response.status(409).json({ error: 'An account with this email already exists' });
        return;
      }

      const now = new Date();
      const userFields = {
        email,
        passwordHash: await hashPassword(parsed.data.password),
        emailVerified: false,
        updatedAt: now
      };
      let userId;
      if (existing) {
        await users.updateOne({ _id: existing._id }, { $set: userFields });
        userId = existing._id;
      } else {
        const inserted = await users.insertOne({ ...userFields, createdAt: now });
        userId = inserted.insertedId;
      }

      await issueEmailCode(email, userId, 'verify-email');
      response.status(202).json({ message: 'Verification code sent' });
    } catch (error) {
      if (error?.code === 11000) {
        response.status(409).json({ error: 'An account with this email already exists' });
        return;
      }
      next(error);
    }
  });

  router.post('/verify-email', async (request, response, next) => {
    try {
      const parsed = emailCodeSchema.safeParse(request.body);
      if (!parsed.success) {
        response.status(400).json({ error: 'Enter a valid email and six-digit verification code' });
        return;
      }

      const email = normalizeEmail(parsed.data.email);
      const verification = await consumeEmailCode(email, 'verify-email', parsed.data.code);
      if (!verification) {
        response.status(400).json({ error: 'Verification code is invalid or expired' });
        return;
      }

      const { users } = getAuthCollections();
      const update = await users.updateOne(
        { _id: verification.userId },
        { $set: { emailVerified: true, updatedAt: new Date() } }
      );
      if (update.matchedCount === 0) {
        response.status(400).json({ error: 'Registration could not be verified' });
        return;
      }

      response.json({ message: 'Email verified. You can now log in.' });
    } catch (error) {
      next(error);
    }
  });

  router.post('/login', async (request, response, next) => {
    try {
      const parsed = loginSchema.safeParse(request.body);
      if (!parsed.success) {
        response.status(400).json({ error: 'Invalid email or password' });
        return;
      }

      const email = normalizeEmail(parsed.data.email);
      const { users } = getAuthCollections();
      const user = await users.findOne({ email });
      if (!user || !(await verifyPassword(parsed.data.password, user.passwordHash))) {
        response.status(401).json({ error: 'Invalid email or password' });
        return;
      }
      if (!user.emailVerified) {
        response.status(403).json({ error: 'Verify your email before logging in' });
        return;
      }

      response.json(await createSession(user));
    } catch (error) {
      next(error);
    }
  });

  router.post('/refresh', async (request, response, next) => {
    try {
      const parsed = z.object({ refreshToken: z.string().min(32).max(256) }).safeParse(request.body);
      if (!parsed.success) {
        response.status(400).json({ error: 'Refresh token is required' });
        return;
      }

      const { refreshSessions, users } = getAuthCollections();
      const deletion = await refreshSessions.findOneAndDelete({
        tokenHash: hashRefreshToken(parsed.data.refreshToken),
        expiresAt: { $gt: new Date() }
      });
      const session = deletion?.value ?? deletion;
      if (!session) {
        response.status(401).json({ error: 'Refresh token is invalid or expired' });
        return;
      }

      const user = await users.findOne({ _id: session.userId, emailVerified: true });
      if (!user) {
        response.status(401).json({ error: 'Account is not available' });
        return;
      }
      response.json(await createSession(user));
    } catch (error) {
      next(error);
    }
  });

  router.post('/logout', async (request, response, next) => {
    try {
      const parsed = z.object({ refreshToken: z.string().min(32).max(256) }).safeParse(request.body);
      if (parsed.success) {
        await getAuthCollections().refreshSessions.deleteOne({
          tokenHash: hashRefreshToken(parsed.data.refreshToken)
        });
      }
      response.json({ ok: true });
    } catch (error) {
      next(error);
    }
  });

  router.post('/forgot-password', emailCodeLimiter, async (request, response, next) => {
    try {
      const parsed = z.object({ email: z.string().trim().email().max(254) }).safeParse(request.body);
      if (!parsed.success) {
        response.status(400).json({ error: 'Enter a valid email address' });
        return;
      }

      const email = normalizeEmail(parsed.data.email);
      const user = await getAuthCollections().users.findOne({ email, emailVerified: true });
      if (user) {
        await issueEmailCode(email, user._id, 'reset-password');
      }
      response.status(202).json({ message: 'If the account exists, a password reset code has been sent' });
    } catch (error) {
      next(error);
    }
  });

  router.post('/reset-password', async (request, response, next) => {
    try {
      const parsed = resetPasswordSchema.safeParse(request.body);
      if (!parsed.success) {
        response.status(400).json({ error: 'Enter a valid email, code, and password of at least 12 characters' });
        return;
      }

      const email = normalizeEmail(parsed.data.email);
      const verification = await consumeEmailCode(email, 'reset-password', parsed.data.code);
      if (!verification) {
        response.status(400).json({ error: 'Reset code is invalid or expired' });
        return;
      }

      const { users, refreshSessions, verificationCodes } = getAuthCollections();
      const passwordHash = await hashPassword(parsed.data.password);
      await users.updateOne({ _id: verification.userId, email }, { $set: { passwordHash, updatedAt: new Date() } });
      await refreshSessions.deleteMany({ userId: verification.userId });
      await verificationCodes.deleteMany({ email });
      response.json({ message: 'Password reset. You can now log in.' });
    } catch (error) {
      next(error);
    }
  });

  return router;
}

export async function requireAuth(request, response, next) {
  const authorization = request.get('authorization') ?? '';
  const match = authorization.match(/^Bearer\s+(.+)$/i);
  if (!match) {
    response.status(401).json({ error: 'Authentication required' });
    return;
  }

  try {
    const { payload } = await jwtVerify(match[1], authSecret(), {
      issuer: 'mediclear-backend',
      audience: 'mediclear-app'
    });
    const userId = new ObjectId(payload.sub);
    const user = await getAuthCollections().users.findOne({ _id: userId, emailVerified: true });
    if (!user) {
      response.status(401).json({ error: 'Authentication required' });
      return;
    }

    request.auth = { userId: user._id.toString(), email: user.email };
    next();
  } catch (_error) {
    response.status(401).json({ error: 'Authentication required' });
  }
}
