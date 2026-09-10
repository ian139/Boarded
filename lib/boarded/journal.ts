/**
 * Domain types, seed data, and validation for Boarded local climbing journal.
 */

export interface Route {
  id: string;
  name: string;
  grade: string;
  crag: string;
  type: string;
  height: string;
  rock: string;
  style: string;
  description: string;
}

export interface AttemptInput {
  routeId: string;
  date: string;
  attempts: number;
  conditions: string;
  notes: string;
}

export interface Entry {
  id: string;
  routeId: string;
  date: string;
  attempts: number;
  conditions: string;
  notes: string;
  outcome: 'attempted' | 'sent';
  published: boolean;
  caption: string;
}

export interface Comment {
  id: string;
  postId: string;
  text: string;
  author: string;
  createdAt?: string;
}

export interface JournalData {
  entries: Entry[];
  savedRouteIds: string[];
  likedPostIds: string[];
  comments: Comment[];
  followingMaya: boolean;
  activityRead: boolean;
}

export interface MayaPost {
  id: string;
  author: string;
  routeId: string;
  routeName: string;
  grade: string;
  crag: string;
  type: string;
  height: string;
  rock: string;
  style: string;
  outcome: 'sent';
  attempts: number;
  date: string;
  timestamp: string;
  displayTime: string;
  caption: string;
  baseKudos: number;
  initialCommentsCount: number;
  photoUrl: string;
}

export const routes: Route[] = [
  {
    id: 'redpoint-ridge',
    name: 'Redpoint Ridge',
    grade: '5.12a',
    crag: 'Stonegate',
    type: 'Sport',
    height: '27 m',
    rock: 'Limestone',
    style: 'Overhang',
    description: 'Six tries. Quiet feet through the crux, then daylight. Sustained limestone endurance testpiece with precise sequential footwork.',
  },
  {
    id: 'steep-circuit',
    name: 'Steep Circuit',
    grade: 'V6',
    crag: 'Bishop',
    type: 'Boulder',
    height: '4.5 m',
    rock: 'Granite',
    style: 'Compression',
    description: 'Classic physical roof line demanding aggressive heel hooks, deliberate tension, and a committed mantle finish.',
  },
  {
    id: 'golden-hour',
    name: 'Golden Hour',
    grade: '5.11c',
    crag: 'Stonegate',
    type: 'Sport',
    height: '24 m',
    rock: 'Limestone',
    style: 'Vertical',
    description: 'Technical face climbing on sharp crimps and delicate balance through the upper headwall as the light angles in.',
  },
];

export const mayaPost: MayaPost = {
  id: 'maya-redpoint',
  author: 'Maya K.',
  routeId: 'redpoint-ridge',
  routeName: 'Redpoint Ridge',
  grade: '5.12a',
  crag: 'Stonegate',
  type: 'Sport',
  height: '27 m',
  rock: 'Limestone',
  style: 'Overhang',
  outcome: 'sent',
  attempts: 6,
  date: '2026-09-06',
  timestamp: '2026-09-06T09:00:00Z',
  displayTime: 'Sep 6, 2026 · 09:00 UTC',
  caption: 'Six tries. One quiet moment when it all clicked.',
  baseKudos: 34,
  initialCommentsCount: 12,
  photoUrl: '/boarded/redpoint-ridge.webp',
};

export const INITIAL_COMMENTS: Comment[] = [
  {
    id: 'seed-c1',
    postId: 'maya-redpoint',
    author: 'Alex R.',
    text: 'That heel hook sequence was inspiring to watch!',
    createdAt: '2026-09-06T09:12:00Z',
  },
  {
    id: 'seed-c2',
    postId: 'maya-redpoint',
    author: 'Jordan T.',
    text: 'Clean send Maya, congrats on ticking the project!',
    createdAt: '2026-09-06T09:18:00Z',
  },
  {
    id: 'seed-c3',
    postId: 'maya-redpoint',
    author: 'Sam V.',
    text: 'That crux transition looked so dialed when you stuck it.',
    createdAt: '2026-09-06T09:25:00Z',
  },
  {
    id: 'seed-c4',
    postId: 'maya-redpoint',
    author: 'Elena M.',
    text: 'Hard work paying off! Looked effortless from the belay.',
    createdAt: '2026-09-06T09:33:00Z',
  },
  {
    id: 'seed-c5',
    postId: 'maya-redpoint',
    author: 'Liam P.',
    text: 'Massive send! 5.12a at Stonegate is serious endurance.',
    createdAt: '2026-09-06T09:41:00Z',
  },
  {
    id: 'seed-c6',
    postId: 'maya-redpoint',
    author: 'Chloe D.',
    text: 'So psyched for you Maya! What is next on the list?',
    createdAt: '2026-09-06T09:50:00Z',
  },
  {
    id: 'seed-c7',
    postId: 'maya-redpoint',
    author: 'Marcus B.',
    text: 'Way to keep composure through that second roof.',
    createdAt: '2026-09-06T10:02:00Z',
  },
  {
    id: 'seed-c8',
    postId: 'maya-redpoint',
    author: 'Nora K.',
    text: 'Rest day well earned. Amazing execution on the finish!',
    createdAt: '2026-09-06T10:15:00Z',
  },
  {
    id: 'seed-c9',
    postId: 'maya-redpoint',
    author: 'Devon S.',
    text: 'Stonegate classic in the bag. Huge congratulations!',
    createdAt: '2026-09-06T10:28:00Z',
  },
  {
    id: 'seed-c10',
    postId: 'maya-redpoint',
    author: 'Tariq H.',
    text: 'Cleanest footwork on the ridge all season.',
    createdAt: '2026-09-06T10:44:00Z',
  },
  {
    id: 'seed-c11',
    postId: 'maya-redpoint',
    author: 'Rachel Z.',
    text: 'Inspired by your patience working through the moves.',
    createdAt: '2026-09-06T11:05:00Z',
  },
  {
    id: 'seed-c12',
    postId: 'maya-redpoint',
    author: 'Julian W.',
    text: 'That final mantle was ice cold. Pure class!',
    createdAt: '2026-09-06T11:20:00Z',
  },
];

export const INITIAL_JOURNAL_DATA: JournalData = {
  entries: [],
  savedRouteIds: [],
  likedPostIds: [],
  comments: INITIAL_COMMENTS,
  followingMaya: true,
  activityRead: false,
};

const DATE_REGEX = /^\d{4}-(?:0[1-9]|1[0-2])-(?:0[1-9]|[12]\d|3[01])$/;

/**
 * Validates attempt input fields according to domain contract.
 * Returns a record of field error messages keyed by field name.
 * An empty object indicates all fields are valid.
 */
export function validateAttempt(input: AttemptInput): Record<string, string> {
  const errors: Record<string, string> = {};

  if (!input || typeof input !== 'object') {
    errors.routeId = 'Invalid input payload.';
    return errors;
  }

  // routeId validation
  const routeId = typeof input.routeId === 'string' ? input.routeId.trim() : '';
  if (!routeId) {
    errors.routeId = 'Route selection is required.';
  } else if (!routes.some((r) => r.id === routeId)) {
    errors.routeId = 'Selected route does not exist in known routes.';
  }

  // date validation (YYYY-MM-DD contract)
  const dateStr = typeof input.date === 'string' ? input.date.trim() : '';
  if (!dateStr) {
    errors.date = 'Date is required.';
  } else if (!DATE_REGEX.test(dateStr)) {
    errors.date = 'Date must be formatted as YYYY-MM-DD.';
  } else {
    const year =
      (dateStr.charCodeAt(0) - 48) * 1000 +
      (dateStr.charCodeAt(1) - 48) * 100 +
      (dateStr.charCodeAt(2) - 48) * 10 +
      (dateStr.charCodeAt(3) - 48);
    const month = (dateStr.charCodeAt(5) - 48) * 10 + dateStr.charCodeAt(6) - 48;
    const day = (dateStr.charCodeAt(8) - 48) * 10 + dateStr.charCodeAt(9) - 48;
    const leapYear = year % 4 === 0 && (year % 100 !== 0 || year % 400 === 0);
    const daysInMonth =
      month === 2
        ? leapYear
          ? 29
          : 28
        : month === 4 || month === 6 || month === 9 || month === 11
          ? 30
          : 31;
    if (year < 100 || day > daysInMonth) {
      errors.date = 'Invalid calendar date.';
    }
  }

  // attempts validation (positive integer 1..100)
  const attempts = input.attempts;
  if (typeof attempts !== 'number' || !Number.isInteger(attempts) || attempts < 1) {
    errors.attempts = 'Attempts must be an integer of at least 1.';
  } else if (attempts > 100) {
    errors.attempts = 'Attempts cannot exceed 100 in a single log.';
  }

  // conditions validation (length <= 500)
  const conditions = typeof input.conditions === 'string' ? input.conditions : '';
  if (conditions.length > 500) {
    errors.conditions = 'Conditions cannot exceed 500 characters.';
  }

  // notes validation (length <= 1000)
  const notes = typeof input.notes === 'string' ? input.notes : '';
  if (notes.length > 1000) {
    errors.notes = 'Notes cannot exceed 1000 characters.';
  }

  return errors;
}

/**
 * Sanitizes untrusted strings by trimming whitespace and enforcing length bounds.
 * Preserves user content verbatim (e.g. angle brackets in climber notes like '<5°C').
 */
export function sanitizeText(text: string, maxLength = 1000): string {
  if (typeof text !== 'string') return '';
  return text.trim().slice(0, maxLength);
}
