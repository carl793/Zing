// Security-rules tests. Run with `npm test` (needs a JDK for the emulator).
// Uses the offline "demo-zing" project; production is never contacted.
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  addDoc, collection, deleteDoc, doc, getDoc, getDocs, query, runTransaction,
  serverTimestamp, setDoc, setLogLevel, Timestamp, updateDoc, where, writeBatch,
} from 'firebase/firestore';

setLogLevel('silent');

let env;
const db = (uid) => env.authenticatedContext(uid).firestore();
const future = () => Timestamp.fromMillis(Date.now() + 3600e3);
const past = () => Timestamp.fromMillis(Date.now() - 3600e3);

const room = (over = {}) => ({
  createdByUid: 'alice',
  status: 'pending',
  createdAt: Timestamp.now(),
  expiresAt: future(),
  ...over,
});
const couple = (over = {}) => ({
  memberUids: ['alice', 'bob'],
  pairingCode: '111111',
  status: 'active',
  linkedAt: Timestamp.now(),
  unitPref: 'km',
  reunionQuest: { status: 'none' },
  settings: { reunionAlerts: true },
  ...over,
});

const seed = (fn) =>
  env.withSecurityRulesDisabled(async (ctx) => {
    await fn(ctx.firestore());
  });

// Alice and Bob are linked; Mallory is a stranger with an account.
const seedLinked = (aliceCoupleId = 'c1') =>
  seed(async (f) => {
    await setDoc(doc(f, 'users/alice'), { email: 'a@x.co', coupleId: aliceCoupleId });
    await setDoc(doc(f, 'users/bob'), { email: 'b@x.co', coupleId: 'c1' });
    await setDoc(doc(f, 'users/mallory'), { email: 'm@x.co', coupleId: null });
    await setDoc(doc(f, 'couples/c1'), couple());
  });

// Exactly the writes the app makes when joining a room.
const join = (f, uid, code, { coupleId = 'cNew', members } = {}) =>
  runTransaction(f, async (tx) => {
    const snap = await tx.get(doc(f, `rooms/${code}`));
    tx.set(doc(f, `couples/${coupleId}`), couple({
      memberUids: members ?? [snap.data().createdByUid, uid],
      pairingCode: code,
      linkedAt: serverTimestamp(),
    }));
    tx.update(doc(f, `rooms/${code}`), { status: 'linked', coupleId });
    tx.set(doc(f, `users/${uid}`), { coupleId }, { merge: true });
  });

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-zing',
    firestore: {
      host: '127.0.0.1',
      port: 8089,
      rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
    },
  });
});
beforeEach(() => env.clearFirestore());
after(() => env.cleanup());

describe('profiles', () => {
  test('own and partner readable; strangers and signed-out denied', async () => {
    await seedLinked();
    await assertSucceeds(getDoc(doc(db('alice'), 'users/alice')));
    await assertSucceeds(getDoc(doc(db('alice'), 'users/bob')));
    await assertFails(getDoc(doc(db('mallory'), 'users/alice')));
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'users/alice')));
  });

  test('a new account can check for and create its own profile', async () => {
    await assertSucceeds(getDoc(doc(db('newbie'), 'users/newbie')));
    await assertSucceeds(setDoc(doc(db('newbie'), 'users/newbie'), { coupleId: null }));
  });

  test('nobody can list profiles', async () => {
    await seedLinked();
    await assertFails(getDocs(collection(db('alice'), 'users')));
    await assertFails(getDocs(collection(db('mallory'), 'users')));
  });

  test('joiner can read a creator who has not claimed the link yet', async () => {
    await seedLinked(null);
    await assertSucceeds(getDoc(doc(db('bob'), 'users/alice')));
  });

  test('pointing your profile at a stranger couple grants nothing', async () => {
    await seedLinked();
    await assertSucceeds(updateDoc(doc(db('mallory'), 'users/mallory'), { coupleId: 'c1' }));
    await assertFails(getDoc(doc(db('mallory'), 'users/alice')));
    await assertFails(getDoc(doc(db('mallory'), 'couples/c1')));
  });

  test('only the owner writes a profile', async () => {
    await seedLinked();
    await assertSucceeds(updateDoc(doc(db('alice'), 'users/alice'), { displayName: 'A' }));
    await assertFails(updateDoc(doc(db('bob'), 'users/alice'), { coupleId: null }));
  });
});

describe('pairing', () => {
  beforeEach(() => seed(async (f) => {
    await setDoc(doc(f, 'rooms/111111'), room());
    await setDoc(doc(f, 'users/alice'), { coupleId: null });
    await setDoc(doc(f, 'users/bob'), { coupleId: null });
  }));

  test('create a code (existence check, then create)', async () => {
    await assertSucceeds(getDoc(doc(db('alice'), 'rooms/222222')));
    await assertSucceeds(setDoc(doc(db('alice'), 'rooms/222222'), room()));
    await assertFails(setDoc(doc(db('mallory'), 'rooms/333333'), room()));
  });

  test('full join transaction, then the creator claims and recovers', async () => {
    await assertSucceeds(join(db('bob'), 'bob', '111111'));
    await assertSucceeds(getDocs(query(
      collection(db('alice'), 'rooms'), where('createdByUid', '==', 'alice'))));
    await assertSucceeds(getDoc(doc(db('alice'), 'couples/cNew')));
    await assertSucceeds(setDoc(doc(db('alice'), 'users/alice'), { coupleId: 'cNew' }, { merge: true }));
    await assertSucceeds(getDoc(doc(db('alice'), 'users/bob')));
    await assertSucceeds(getDoc(doc(db('bob'), 'users/alice')));
  });

  test('cannot join own, expired, cancelled or linked rooms', async () => {
    await assertFails(join(db('alice'), 'alice', '111111'));
    for (const over of [{ expiresAt: past() }, { status: 'cancelled' }, { status: 'linked' }]) {
      await seed((f) => setDoc(doc(f, 'rooms/111111'), room(over)));
      await assertFails(join(db('bob'), 'bob', '111111'));
    }
  });

  test('cannot harvest codes', async () => {
    await assertFails(getDocs(collection(db('mallory'), 'rooms')));
    await assertFails(getDocs(query(
      collection(db('mallory'), 'rooms'), where('status', '==', 'pending'))));
  });

  test('cannot hijack: flip a room, forge members, or make a bare couple', async () => {
    const m = db('mallory');
    await assertFails(updateDoc(doc(m, 'rooms/111111'), { status: 'linked', coupleId: 'evil' }));
    await assertFails(join(m, 'mallory', '111111', { members: ['alice', 'bob'] }));
    await assertFails(join(m, 'mallory', '111111', { members: ['bob', 'mallory'] }));
    await assertFails(setDoc(doc(m, 'couples/evil'), couple({ memberUids: ['alice', 'mallory'] })));
  });

  test('only the creator cancels, and only while pending', async () => {
    await assertFails(updateDoc(doc(db('mallory'), 'rooms/111111'), { status: 'cancelled' }));
    await assertSucceeds(updateDoc(doc(db('alice'), 'rooms/111111'), { status: 'cancelled' }));
    await assertFails(updateDoc(doc(db('alice'), 'rooms/111111'), { status: 'pending' }));
  });
});

describe('couples', () => {
  beforeEach(() => seedLinked());

  const unlink = (f, uid, signedBy = uid) => {
    const b = writeBatch(f);
    b.update(doc(f, 'couples/c1'), {
      status: 'unlinked', unlinkedByUid: signedBy, unlinkedAt: serverTimestamp(),
    });
    b.set(doc(f, `users/${uid}`), { coupleId: null }, { merge: true });
    return b.commit();
  };

  test('members change quest, settings and unit; strangers nothing', async () => {
    const ref = doc(db('alice'), 'couples/c1');
    await assertSucceeds(updateDoc(ref, { unitPref: 'mi' }));
    await assertSucceeds(updateDoc(ref, { 'settings.reunionAlerts': false }));
    await assertSucceeds(updateDoc(ref, {
      reunionQuest: { status: 'accepted', acceptedAt: serverTimestamp() },
    }));
    await assertFails(updateDoc(doc(db('mallory'), 'couples/c1'), { unitPref: 'km' }));
  });

  test('member list and link data are immutable', async () => {
    const ref = doc(db('bob'), 'couples/c1');
    await assertFails(updateDoc(ref, { memberUids: ['alice', 'bob', 'mallory'] }));
    await assertFails(updateDoc(ref, { linkedAt: past() }));
    await assertFails(deleteDoc(ref));
  });

  test('unlink is signed by the caller and ends profile access', async () => {
    await assertFails(unlink(db('bob'), 'bob', 'alice'));
    await assertSucceeds(unlink(db('alice'), 'alice'));
    await assertFails(getDoc(doc(db('bob'), 'users/alice')));
    await assertSucceeds(updateDoc(doc(db('bob'), 'users/bob'), { coupleId: null }));
  });

  test('an ex-partner cannot reactivate the couple to regain access', async () => {
    await unlink(db('alice'), 'alice');
    await assertFails(updateDoc(doc(db('bob'), 'couples/c1'), { status: 'active' }));
    await assertFails(getDoc(doc(db('bob'), 'users/alice')));
  });
});

describe('memories, comments, capsules', () => {
  beforeEach(() => seedLinked());
  const mem = (uid) => ({ authorUid: uid, title: 't', createdAt: serverTimestamp() });

  test('author-only edits; members read; strangers shut out', async () => {
    const path = 'couples/c1/memories/m1';
    await assertSucceeds(setDoc(doc(db('alice'), path), mem('alice')));
    await assertFails(setDoc(doc(db('bob'), 'couples/c1/memories/m2'), mem('alice')));
    await assertSucceeds(getDocs(collection(db('bob'), 'couples/c1/memories')));
    await assertFails(getDocs(collection(db('mallory'), 'couples/c1/memories')));
    await assertSucceeds(updateDoc(doc(db('alice'), path), { title: 'x' }));
    await assertFails(updateDoc(doc(db('bob'), path), { title: 'x' }));
    await assertFails(updateDoc(doc(db('alice'), path), { authorUid: 'bob' }));
    await assertSucceeds(addDoc(collection(db('bob'), `${path}/comments`), {
      authorUid: 'bob', text: 'hi', createdAt: serverTimestamp(),
    }));
    await assertFails(deleteDoc(doc(db('bob'), path)));
    await assertSucceeds(deleteDoc(doc(db('alice'), path)));
  });

  test('capsules: one whereIn query is enough for the vault', async () => {
    const path = 'couples/c1/capsules/x';
    await assertSucceeds(setDoc(doc(db('alice'), path), {
      creatorUid: 'alice', status: 'sealed', createdAt: serverTimestamp(),
    }));
    await assertSucceeds(getDocs(query(
      collection(db('bob'), 'couples/c1/capsules'),
      where('status', 'in', ['sealed', 'unlocked']))));
    await assertFails(updateDoc(doc(db('bob'), path), { creatorUid: 'bob' }));
    await assertSucceeds(updateDoc(doc(db('bob'), path), { isArchived: true }));
    await assertSucceeds(updateDoc(doc(db('alice'), path), { status: 'cancelled' }));
  });

  // Older builds send two updates to one chest in the same transaction.
  test('dual-tap transaction', async () => {
    await seed((f) => setDoc(doc(f, 'couples/c1/capsules/d'), {
      creatorUid: 'alice', status: 'sealed', triggerMode: 'dualTapSync',
      dualTapState: { p1TappedAt: Timestamp.now() }, createdAt: Timestamp.now(),
    }));
    const f = db('bob');
    await assertSucceeds(runTransaction(f, async (tx) => {
      const ref = doc(f, 'couples/c1/capsules/d');
      await tx.get(ref);
      tx.update(ref, { 'dualTapState.p2TappedAt': Timestamp.now() });
      tx.update(ref, { status: 'unlocked', openedAt: Timestamp.now() });
    }));
  });
});
