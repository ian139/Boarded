import { describe, it, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import {
  routes,
  validateAttempt,
  sanitizeText,
  INITIAL_JOURNAL_DATA,
  type AttemptInput,
} from './journal.ts';
import {
  useJournal,
  STORAGE_KEY,
  validateAndSanitizeData,
} from './store.ts';

// Mock localStorage for node:test environment
class MockLocalStorage {
  public store: Map<string, string> = new Map();
  public shouldThrowOnSet = false;

  getItem(key: string): string | null {
    return this.store.has(key) ? this.store.get(key)! : null;
  }

  setItem(key: string, value: string): void {
    if (this.shouldThrowOnSet) {
      throw new Error('QuotaExceededError: localStorage write operation exceeded storage quota');
    }
    this.store.set(key, value);
  }

  removeItem(key: string): void {
    this.store.delete(key);
  }

  clear(): void {
    this.store.clear();
  }
}

describe('Domain validation: validateAttempt', () => {
  it('rejects missing or unknown routes', () => {
    const emptyRoute = validateAttempt({
      routeId: '',
      date: '2026-09-06',
      attempts: 1,
      conditions: '',
      notes: '',
    });
    assert.ok(emptyRoute.routeId, 'Empty routeId must produce an error');

    const unknownRoute = validateAttempt({
      routeId: 'non-existent-wall',
      date: '2026-09-06',
      attempts: 1,
      conditions: '',
      notes: '',
    });
    assert.ok(unknownRoute.routeId, 'Unknown routeId must produce an error');

    const validRoute = validateAttempt({
      routeId: routes[0].id,
      date: '2026-09-06',
      attempts: 1,
      conditions: '',
      notes: '',
    });
    assert.equal(validRoute.routeId, undefined, 'Known routeId must have no route error');
  });

  it('enforces strict YYYY-MM-DD date contract and rejects invalid calendar days', () => {
    assert.ok(
      validateAttempt({
        routeId: 'redpoint-ridge',
        date: '2026-02-31',
        attempts: 1,
        conditions: '',
        notes: '',
      }).date,
      'February 31 is not a valid calendar day'
    );

    assert.ok(
      validateAttempt({
        routeId: 'redpoint-ridge',
        date: '2026/09/06',
        attempts: 1,
        conditions: '',
        notes: '',
      }).date,
      'Non-hyphenated date format must be rejected'
    );

    const valid = validateAttempt({
      routeId: 'redpoint-ridge',
      date: '2026-09-06',
      attempts: 1,
      conditions: '',
      notes: '',
    });
    assert.equal(valid.date, undefined, 'Valid YYYY-MM-DD must pass');
  });

  it('handles Gregorian leap, century, and year boundaries', () => {
    const validDates = ['2024-02-29', '2000-02-29', '0100-02-28'];
    for (const date of validDates) {
      assert.equal(
        validateAttempt({
          routeId: 'redpoint-ridge',
          date,
          attempts: 1,
          conditions: '',
          notes: '',
        }).date,
        undefined,
        `${date} should be accepted`
      );
    }

    const invalidDates = ['1900-02-29', '0099-12-31'];
    for (const date of invalidDates) {
      assert.ok(
        validateAttempt({
          routeId: 'redpoint-ridge',
          date,
          attempts: 1,
          conditions: '',
          notes: '',
        }).date,
        `${date} should be rejected`
      );
    }
  });

  it('enforces positive integer attempts bounded within 1..100', () => {
    assert.ok(
      validateAttempt({
        routeId: 'redpoint-ridge',
        date: '2026-09-06',
        attempts: 0,
        conditions: '',
        notes: '',
      }).attempts,
      'Zero attempts must be rejected'
    );

    assert.ok(
      validateAttempt({
        routeId: 'redpoint-ridge',
        date: '2026-09-06',
        attempts: 101,
        conditions: '',
        notes: '',
      }).attempts,
      'Attempts over 100 must be rejected'
    );

    assert.ok(
      validateAttempt({
        routeId: 'redpoint-ridge',
        date: '2026-09-06',
        attempts: 1.5,
        conditions: '',
        notes: '',
      }).attempts,
      'Fractional attempts must be rejected'
    );
  });

  it('enforces sensible length limits on conditions and notes', () => {
    const tooLongConditions = 'a'.repeat(501);
    assert.ok(
      validateAttempt({
        routeId: 'redpoint-ridge',
        date: '2026-09-06',
        attempts: 1,
        conditions: tooLongConditions,
        notes: '',
      }).conditions,
      'Conditions over 500 characters must produce error'
    );

    const tooLongNotes = 'a'.repeat(1001);
    assert.ok(
      validateAttempt({
        routeId: 'redpoint-ridge',
        date: '2026-09-06',
        attempts: 1,
        conditions: '',
        notes: tooLongNotes,
      }).notes,
      'Notes over 1000 characters must produce error'
    );
  });
});

describe('Text boundary processing: sanitizeText', () => {
  it('preserves user angle brackets while trimming surrounding whitespace', () => {
    const raw = '  Temp <10°C, crimp -> pinch -> jug  ';
    const cleaned = sanitizeText(raw, 500);
    assert.equal(cleaned, 'Temp <10°C, crimp -> pinch -> jug');
    assert.ok(cleaned.includes('<10°C'));
  });

  it('enforces max length bounds', () => {
    const text = '1234567890';
    assert.equal(sanitizeText(text, 5), '12345');
  });
});

describe('Schema hydration and corruption rejection: validateAndSanitizeData', () => {
  it('validates schema and rejects fatally malformed persisted shapes', () => {
    assert.equal(validateAndSanitizeData(null), null);
    assert.equal(validateAndSanitizeData('arbitrary string'), null);
    assert.equal(validateAndSanitizeData({ entries: 'not-an-array' }), null);
    assert.equal(validateAndSanitizeData([1, 2, 3]), null);
  });

  it('rejects entries with missing or empty required fields', () => {
    const badEntry = {
      entries: [
        {
          id: '',
          routeId: 'redpoint-ridge',
          date: '2026-09-06',
          attempts: 1,
          outcome: 'attempted',
          published: false,
        },
      ],
    };
    assert.equal(validateAndSanitizeData(badEntry), null);
  });

  it('rejects non-boolean publication values without truthiness coercion', () => {
    const stringPublished = {
      entries: [
        {
          id: 'e1',
          routeId: 'redpoint-ridge',
          date: '2026-09-06',
          attempts: 1,
          outcome: 'attempted',
          published: 'false',
        },
      ],
    };
    assert.equal(validateAndSanitizeData(stringPublished), null);

    const numberPublished = {
      entries: [
        {
          id: 'e1',
          routeId: 'redpoint-ridge',
          date: '2026-09-06',
          attempts: 1,
          outcome: 'attempted',
          published: 0,
        },
      ],
    };
    assert.equal(validateAndSanitizeData(numberPublished), null);
  });

  it('enforces sent-before-published domain invariant during hydration', () => {
    const publishedUnsent = {
      entries: [
        {
          id: 'e1',
          routeId: 'redpoint-ridge',
          date: '2026-09-06',
          attempts: 2,
          outcome: 'attempted',
          published: true,
        },
      ],
    };
    assert.equal(validateAndSanitizeData(publishedUnsent), null);
  });

  it('rejects malformed attempt counts without coercion or clamping', () => {
    // string attempts
    assert.equal(
      validateAndSanitizeData({
        entries: [
          {
            id: 'e1',
            routeId: 'redpoint-ridge',
            date: '2026-09-06',
            attempts: '6',
            outcome: 'attempted',
            published: false,
          },
        ],
      }),
      null
    );

    // out-of-bounds counts
    assert.equal(
      validateAndSanitizeData({
        entries: [
          {
            id: 'e1',
            routeId: 'redpoint-ridge',
            date: '2026-09-06',
            attempts: 0,
            outcome: 'attempted',
            published: false,
          },
        ],
      }),
      null
    );

    assert.equal(
      validateAndSanitizeData({
        entries: [
          {
            id: 'e1',
            routeId: 'redpoint-ridge',
            date: '2026-09-06',
            attempts: 101,
            outcome: 'attempted',
            published: false,
          },
        ],
      }),
      null
    );
  });

  it('rejects invalid calendar dates during hydration', () => {
    assert.equal(
      validateAndSanitizeData({
        entries: [
          {
            id: 'e1',
            routeId: 'redpoint-ridge',
            date: '2026-02-31',
            attempts: 1,
            outcome: 'attempted',
            published: false,
          },
        ],
      }),
      null
    );

    assert.equal(
      validateAndSanitizeData({
        entries: [
          {
            id: 'e1',
            routeId: 'redpoint-ridge',
            date: 'not-a-date',
            attempts: 1,
            outcome: 'attempted',
            published: false,
          },
        ],
      }),
      null
    );
  });

  it('rejects unknown routeId and unsafe id segment', () => {
    assert.equal(
      validateAndSanitizeData({
        entries: [
          {
            id: 'e1',
            routeId: 'unknown-route-xyz',
            date: '2026-09-06',
            attempts: 1,
            outcome: 'attempted',
            published: false,
          },
        ],
      }),
      null
    );

    assert.equal(
      validateAndSanitizeData({
        entries: [
          {
            id: 'bad id with spaces',
            routeId: 'redpoint-ridge',
            date: '2026-09-06',
            attempts: 1,
            outcome: 'attempted',
            published: false,
          },
        ],
      }),
      null
    );
  });

  it('rejects invalid text fields and overlength strings', () => {
    // Non-string conditions
    assert.equal(
      validateAndSanitizeData({
        entries: [
          {
            id: 'e1',
            routeId: 'redpoint-ridge',
            date: '2026-09-06',
            attempts: 1,
            conditions: 12345,
            outcome: 'attempted',
            published: false,
          },
        ],
      }),
      null
    );

    // Overlength caption
    assert.equal(
      validateAndSanitizeData({
        entries: [
          {
            id: 'e1',
            routeId: 'redpoint-ridge',
            date: '2026-09-06',
            attempts: 1,
            outcome: 'sent',
            published: true,
            caption: 'x'.repeat(281),
          },
        ],
      }),
      null
    );
  });

  it('rejects non-boolean top-level fields', () => {
    assert.equal(
      validateAndSanitizeData({
        entries: [],
        followingMaya: 'true',
      }),
      null
    );

    assert.equal(
      validateAndSanitizeData({
        entries: [],
        activityRead: 1,
      }),
      null
    );
  });

  it('preserves angle brackets in persisted conditions and notes', () => {
    const validWithSymbols = {
      entries: [
        {
          id: 'e1',
          routeId: 'redpoint-ridge',
          date: '2026-09-06',
          attempts: 1,
          conditions: 'Temp <10°C',
          notes: 'Crux move: crimp -> pinch -> jug',
          outcome: 'sent',
          published: false,
          caption: '',
        },
      ],
    };
    const hydrated = validateAndSanitizeData(validWithSymbols);
    assert.ok(hydrated);
    assert.equal(hydrated.entries[0].conditions, 'Temp <10°C');
    assert.equal(hydrated.entries[0].notes, 'Crux move: crimp -> pinch -> jug');
  });
});

describe('State transitions: attempt -> sent -> published', () => {
  let mockStorage: MockLocalStorage;

  beforeEach(() => {
    mockStorage = new MockLocalStorage();
    (globalThis as unknown as { window: { localStorage: MockLocalStorage } }).window = {
      localStorage: mockStorage,
    };
    useJournal.setState({
      entries: [],
      savedRouteIds: [],
      likedPostIds: [],
      comments: [...INITIAL_JOURNAL_DATA.comments],
      followingMaya: true,
      activityRead: false,
      ready: true,
      error: null,
      storageCorrupted: false,
      storageHydrated: true,
    });
  });

  it('records an attempt with initial outcome="attempted" and published=false', () => {
    const result = useJournal.getState().recordAttempt({
      routeId: 'redpoint-ridge',
      date: '2026-09-06',
      attempts: 4,
      conditions: 'Crisp morning, <12°C',
      notes: 'Linked through crux move cleanly -> rested at chains',
    });

    assert.ok('id' in result, 'Must return generated entry id on success');
    const entries = useJournal.getState().entries;
    assert.equal(entries.length, 1);
    assert.equal(entries[0].id, result.id);
    assert.equal(entries[0].outcome, 'attempted');
    assert.equal(entries[0].published, false);
    assert.ok(entries[0].conditions.includes('<12°C'));
  });

  it('forbids publishing an unsent attempt', () => {
    const recordRes = useJournal.getState().recordAttempt({
      routeId: 'redpoint-ridge',
      date: '2026-09-06',
      attempts: 2,
      conditions: '',
      notes: '',
    });
    assert.ok('id' in recordRes);

    const publishRes = useJournal.getState().publish(recordRes.id, 'Tried hard today!');
    assert.ok('error' in publishRes, 'Publishing unsent attempt must return an error');
    assert.match(publishRes.error, /has not been sent/i);

    const entry = useJournal.getState().entries.find((e) => e.id === recordRes.id);
    assert.equal(entry?.published, false, 'Entry must remain unpublished');
  });

  it('transitions attempt to sent, then allows publishing', () => {
    const recordRes = useJournal.getState().recordAttempt({
      routeId: 'redpoint-ridge',
      date: '2026-09-06',
      attempts: 6,
      conditions: 'Dry rock',
      notes: 'Everything clicked on try 6',
    });
    assert.ok('id' in recordRes);

    const sentRes = useJournal.getState().markSent(recordRes.id);
    assert.deepEqual(sentRes, { ok: true });

    let entry = useJournal.getState().entries.find((e) => e.id === recordRes.id);
    assert.equal(entry?.outcome, 'sent');

    const pubRes = useJournal.getState().publish(recordRes.id, 'Sent on try 6!');
    assert.deepEqual(pubRes, { ok: true });

    entry = useJournal.getState().entries.find((e) => e.id === recordRes.id);
    assert.equal(entry?.published, true);
    assert.equal(entry?.caption, 'Sent on try 6!');
  });

  it('guarantees idempotency on repeated markSent and publish calls', () => {
    const recordRes = useJournal.getState().recordAttempt({
      routeId: 'redpoint-ridge',
      date: '2026-09-06',
      attempts: 1,
      conditions: '',
      notes: '',
    });
    assert.ok('id' in recordRes);

    assert.deepEqual(useJournal.getState().markSent(recordRes.id), { ok: true });
    assert.deepEqual(useJournal.getState().markSent(recordRes.id), { ok: true });
    assert.equal(useJournal.getState().entries.length, 1);

    assert.deepEqual(useJournal.getState().publish(recordRes.id, 'First try send'), { ok: true });
    assert.deepEqual(useJournal.getState().publish(recordRes.id, 'First try send'), { ok: true });
    assert.equal(useJournal.getState().entries.length, 1);
  });

  it('safely handles missing entry operations without crashing or corrupting', () => {
    const nonExistent = 'entry-missing-999';
    assert.ok('error' in useJournal.getState().markSent(nonExistent));
    assert.ok('error' in useJournal.getState().publish(nonExistent, 'Ghost send'));
    assert.ok('error' in useJournal.getState().deleteEntry(nonExistent));
  });
});

describe('Deletion and restoration recovery', () => {
  let mockStorage: MockLocalStorage;

  beforeEach(() => {
    mockStorage = new MockLocalStorage();
    (globalThis as unknown as { window: { localStorage: MockLocalStorage } }).window = {
      localStorage: mockStorage,
    };
    useJournal.setState({
      entries: [],
      savedRouteIds: [],
      likedPostIds: [],
      comments: [...INITIAL_JOURNAL_DATA.comments],
      followingMaya: true,
      activityRead: false,
      ready: true,
      error: null,
      storageCorrupted: false,
      storageHydrated: true,
    });
  });

  it('supports deleting an entry and restoring it for UI undo/recovery', () => {
    const recordRes = useJournal.getState().recordAttempt({
      routeId: 'redpoint-ridge',
      date: '2026-09-06',
      attempts: 3,
      conditions: 'Sunny',
      notes: 'Resting before the roof',
    });
    assert.ok('id' in recordRes);

    const savedEntry = { ...useJournal.getState().entries[0] };
    assert.equal(useJournal.getState().entries.length, 1);

    const delRes = useJournal.getState().deleteEntry(recordRes.id);
    assert.deepEqual(delRes, { ok: true });
    assert.equal(useJournal.getState().entries.length, 0);

    const restoreRes = useJournal.getState().restoreEntry(savedEntry);
    assert.deepEqual(restoreRes, { ok: true });
    assert.equal(useJournal.getState().entries.length, 1);
    assert.equal(useJournal.getState().entries[0].id, recordRes.id);

    // Repeated restore is idempotent
    assert.deepEqual(useJournal.getState().restoreEntry(savedEntry), { ok: true });
    assert.equal(useJournal.getState().entries.length, 1);
  });
});

describe('Storage resilience and corruption protection', () => {
  let mockStorage: MockLocalStorage;

  beforeEach(() => {
    mockStorage = new MockLocalStorage();
    (globalThis as unknown as { window: { localStorage: MockLocalStorage } }).window = {
      localStorage: mockStorage,
    };
    useJournal.setState({
      entries: [],
      savedRouteIds: [],
      likedPostIds: [],
      comments: [...INITIAL_JOURNAL_DATA.comments],
      followingMaya: true,
      activityRead: false,
      ready: false,
      error: null,
      storageCorrupted: false,
      storageHydrated: false,
    });
  });

  it('preserves corrupted storage on initialize without silently resetting or wiping user data', () => {
    mockStorage.setItem(STORAGE_KEY, '{ malformed json: not valid ...');

    useJournal.getState().initialize();

    const state = useJournal.getState();
    assert.ok(state.ready, 'Store should become ready');
    assert.ok(state.error, 'Store must report visible error');
    assert.match(state.error!, /malformed JSON/i);

    // Verify storage key was NOT overwritten
    assert.equal(mockStorage.getItem(STORAGE_KEY), '{ malformed json: not valid ...');
  });

  it('prevents later mutations from silently overwriting initialized corrupted storage', () => {
    const rawCorrupt = '{"entries": "invalid-structure"}';
    mockStorage.setItem(STORAGE_KEY, rawCorrupt);

    useJournal.getState().initialize();
    assert.ok(useJournal.getState().error, 'Must report error on invalid schema');

    // Attempting mutation must return an error and NOT overwrite storage
    const result = useJournal.getState().recordAttempt({
      routeId: 'redpoint-ridge',
      date: '2026-09-06',
      attempts: 2,
      conditions: '',
      notes: '',
    });

    assert.ok('error' in result, 'Mutation must fail when storage is corrupted');
    assert.match(result.error, /corrupted data/i);
    assert.equal(mockStorage.getItem(STORAGE_KEY), rawCorrupt, 'Storage must not be overwritten');
  });

  it('retryStorage preserves unreadable corrupted storage without overwriting with defaults', () => {
    const rawMalformed = '{ malformed json';
    mockStorage.setItem(STORAGE_KEY, rawMalformed);

    useJournal.getState().initialize();
    assert.match(useJournal.getState().error!, /malformed JSON/i);

    // Calling retryStorage must re-read and preserve rather than overwrite
    useJournal.getState().retryStorage();
    assert.equal(mockStorage.getItem(STORAGE_KEY), rawMalformed, 'Storage must remain untouched');
    assert.match(useJournal.getState().error!, /malformed JSON/i);
  });

  it('protects failure -> Retry -> resubmit producing exactly one attempt without duplicate state', () => {
    useJournal.getState().initialize();
    mockStorage.shouldThrowOnSet = true;

    const draft: AttemptInput = {
      routeId: 'redpoint-ridge',
      date: '2026-09-06',
      attempts: 3,
      conditions: 'Cold morning, <10°C',
      notes: 'Foot slipped at crux',
    };

    // 1. Initial attempt fails to persist
    const failRes = useJournal.getState().recordAttempt(draft);
    assert.ok('error' in failRes, 'Must return error on persistence failure');
    assert.match(failRes.error, /storage write failed/i);

    // In-memory journal state is NOT modified
    assert.equal(useJournal.getState().entries.length, 0, 'Must preserve old journal on write failure');
    assert.ok(useJournal.getState().error);

    // 2. Storage recovers; user triggers Retry
    mockStorage.shouldThrowOnSet = false;
    useJournal.getState().retryStorage();
    assert.equal(useJournal.getState().error, null, 'Retry re-reads storage and clears error');
    assert.equal(useJournal.getState().entries.length, 0, 'Retry does not replay pending operation');

    // 3. User resubmits form draft
    const successRes = useJournal.getState().recordAttempt(draft);
    assert.ok('id' in successRes, 'Successful resubmit returns generated record id');
    assert.equal(useJournal.getState().entries.length, 1, 'Exactly one attempt in store');

    // Durable storage contains exactly one attempt
    const stored = JSON.parse(mockStorage.getItem(STORAGE_KEY)!);
    assert.equal(stored.entries.length, 1, 'Exactly one attempt in durable storage');
    assert.equal(stored.entries[0].id, successRes.id);
  });

  it('protects failure -> Retry -> resubmit producing exactly one comment without duplicate state', () => {
    useJournal.getState().initialize();
    const initialCommentsCount = useJournal.getState().comments.length;
    mockStorage.shouldThrowOnSet = true;

    // 1. Initial comment fails to persist
    const failRes = useJournal.getState().addComment('maya-redpoint', 'Great beta on the crux!');
    assert.ok('error' in failRes, 'Must return error on persistence failure');

    // In-memory comments are NOT modified
    assert.equal(useJournal.getState().comments.length, initialCommentsCount);
    assert.ok(useJournal.getState().error);

    // 2. Storage recovers; user triggers Retry
    mockStorage.shouldThrowOnSet = false;
    useJournal.getState().retryStorage();
    assert.equal(useJournal.getState().error, null);
    assert.equal(useJournal.getState().comments.length, initialCommentsCount);

    // 3. User resubmits comment
    const successRes = useJournal.getState().addComment('maya-redpoint', 'Great beta on the crux!');
    assert.deepEqual(successRes, { ok: true });
    assert.equal(useJournal.getState().comments.length, initialCommentsCount + 1);

    const stored = JSON.parse(mockStorage.getItem(STORAGE_KEY)!);
    assert.equal(stored.comments.length, initialCommentsCount + 1);
  });

  it('failed delete retains original entry and retry alone does not delete', () => {
    useJournal.getState().initialize();
    const recordRes = useJournal.getState().recordAttempt({
      routeId: 'redpoint-ridge',
      date: '2026-09-06',
      attempts: 2,
      conditions: '',
      notes: '',
    });
    assert.ok('id' in recordRes);
    assert.equal(useJournal.getState().entries.length, 1);

    // Storage write failure on delete
    mockStorage.shouldThrowOnSet = true;
    const deleteRes = useJournal.getState().deleteEntry(recordRes.id);
    assert.ok('error' in deleteRes, 'Delete must fail when storage write fails');

    // In-memory entry is preserved
    assert.equal(useJournal.getState().entries.length, 1, 'Entry must be retained on failed delete');
    assert.equal(useJournal.getState().entries[0].id, recordRes.id);

    // Storage recovers; retry alone must NOT delete the entry
    mockStorage.shouldThrowOnSet = false;
    useJournal.getState().retryStorage();
    assert.equal(useJournal.getState().error, null);
    assert.equal(useJournal.getState().entries.length, 1, 'Retry alone does not delete the entry');

    const stored = JSON.parse(mockStorage.getItem(STORAGE_KEY)!);
    assert.equal(stored.entries.length, 1, 'Storage still retains the entry');
  });

  it('denied initial getter with preexisting storage then recovery retains prior data', () => {
    const priorData = {
      entries: [
        {
          id: 'prior-entry-1',
          routeId: 'golden-hour',
          date: '2026-09-05',
          attempts: 4,
          conditions: 'Golden hour light, <15°C',
          notes: 'Delicate balance on headwall crimps',
          outcome: 'sent',
          published: true,
          caption: 'Sent in the sunset',
        },
      ],
      savedRouteIds: ['golden-hour'],
      likedPostIds: [],
      comments: [...INITIAL_JOURNAL_DATA.comments],
      followingMaya: true,
      activityRead: false,
    };
    const rawPrior = JSON.stringify(priorData);
    mockStorage.setItem(STORAGE_KEY, rawPrior);

    // Simulate getter denial on initial load
    let accessAllowed = false;
    const restrictedWindow = {
      get localStorage(): Storage {
        if (!accessAllowed) {
          throw new Error('SecurityError: access to localStorage denied');
        }
        return mockStorage as unknown as Storage;
      },
    };
    (globalThis as unknown as { window: unknown }).window = restrictedWindow;

    // 1. Initialize with getter denied
    useJournal.getState().initialize();
    const state = useJournal.getState();
    assert.ok(state.ready, 'Store should become ready to show recovery UI');
    assert.ok(state.error, 'Store must report access error');
    assert.match(state.error!, /SecurityError/i);
    assert.equal(state.entries.length, 0, 'Defaults in memory');

    // 2. Mutations while storage unread must return error and NOT overwrite storage
    const writeResult = useJournal.getState().recordAttempt({
      routeId: 'redpoint-ridge',
      date: '2026-09-06',
      attempts: 1,
      conditions: '',
      notes: '',
    });
    assert.ok('error' in writeResult, 'Must block mutations before storage is safely loaded');
    assert.equal(mockStorage.getItem(STORAGE_KEY), rawPrior, 'Preexisting storage must be completely untouched');

    // 3. Access restored, user clicks Retry
    accessAllowed = true;
    useJournal.getState().retryStorage();

    const recoveredState = useJournal.getState();
    assert.equal(recoveredState.error, null, 'Error cleared after successful recovery');
    assert.equal(recoveredState.entries.length, 1, 'Prior entries recovered');
    assert.equal(recoveredState.entries[0].id, 'prior-entry-1');
    assert.equal(recoveredState.savedRouteIds[0], 'golden-hour');
    assert.equal(mockStorage.getItem(STORAGE_KEY), rawPrior, 'Storage remains intact with prior data');
  });

  it('preserves malformed entry fields in storage as raw and returns error without overwriting', () => {
    const rawMalformedEntry = JSON.stringify({
      entries: [
        {
          id: 'e-bad',
          routeId: 'redpoint-ridge',
          date: '2026-02-31', // invalid calendar date
          attempts: '6', // string attempts
          conditions: 12345, // bad type
          notes: 'x'.repeat(1001), // overlength
          caption: 'y'.repeat(281), // overlength
          outcome: 'attempted',
          published: false,
        },
      ],
    });
    mockStorage.setItem(STORAGE_KEY, rawMalformedEntry);

    useJournal.getState().initialize();
    assert.ok(useJournal.getState().error);
    assert.match(useJournal.getState().error!, /invalid schema/i);

    // Raw bytes remain untouched in storage
    assert.equal(mockStorage.getItem(STORAGE_KEY), rawMalformedEntry);

    // Calling retryStorage preserves raw storage
    useJournal.getState().retryStorage();
    assert.equal(mockStorage.getItem(STORAGE_KEY), rawMalformedEntry);
    assert.match(useJournal.getState().error!, /invalid schema/i);

    // Mutation attempts fail and do not overwrite
    const res = useJournal.getState().recordAttempt({
      routeId: 'redpoint-ridge',
      date: '2026-09-06',
      attempts: 1,
      conditions: '',
      notes: '',
    });
    assert.ok('error' in res);
    assert.equal(mockStorage.getItem(STORAGE_KEY), rawMalformedEntry);
  });

  it('catches security exceptions from accessing the window.localStorage property', () => {
    const restrictedWindow = {
      get localStorage(): Storage {
        throw new Error('SecurityError: access to localStorage denied');
      },
    };
    (globalThis as unknown as { window: unknown }).window = restrictedWindow;

    // initialize must not crash with unhandled exception
    useJournal.getState().initialize();
    assert.ok(useJournal.getState().ready, 'Store should become ready');
    assert.ok(useJournal.getState().error, 'Store must surface storage access error');
    assert.match(useJournal.getState().error!, /SecurityError/i);

    // recordAttempt must return error instead of throwing uncaught exception
    const writeResult = useJournal.getState().recordAttempt({
      routeId: 'redpoint-ridge',
      date: '2026-09-06',
      attempts: 1,
      conditions: '',
      notes: '',
    });
    assert.ok('error' in writeResult, 'Must return error on denied storage access');
    assert.match(writeResult.error, /Cannot modify journal/i);
  });
});
