// Chest rules: sealed content stays sealed, and chests only open when they may.
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection, deleteDoc, deleteField, doc, getDoc, getDocs, runTransaction,
  serverTimestamp, setDoc, setLogLevel, Timestamp, updateDoc, writeBatch,
} from 'firebase/firestore';

setLogLevel('silent');

let env;
const db = (uid) => env.authenticatedContext(uid).firestore();
const at = (ms) => Timestamp.fromMillis(Date.now() + ms);
const HOUR = 3600e3;

const CHEST = 'couples/c1/capsules/x';
const CONTENT = `${CHEST}/sealed/content`;

const chest = (over = {}) => ({
  creatorUid: 'alice',
  title: 't',
  triggerMode: 'dateRelease',
  unlockDate: at(HOUR),
  status: 'sealed',
  createdAt: Timestamp.now(),
  ...over,
});
const dual = (taps = {}, over = {}) =>
  chest({ triggerMode: 'dualTapSync', unlockDate: null, dualTapState: taps, ...over });
const content = (over = {}) => ({
  creatorUid: 'alice', secretNote: 'secret', photoUrl: null, voiceNoteUrl: null, ...over,
});

const seed = (fn) =>
  env.withSecurityRulesDisabled(async (ctx) => {
    await fn(ctx.firestore());
  });
const seedChest = (data, withContent = true) =>
  seed(async (f) => {
    await setDoc(doc(f, CHEST), data);
    if (withContent) await setDoc(doc(f, CONTENT), content());
  });
// The writes the app makes when sealing a chest.
const sealChest = (uid, chestData, contentData) => {
  const f = db(uid);
  const b = writeBatch(f);
  b.set(doc(f, CHEST), { ...chestData, createdAt: serverTimestamp() });
  b.set(doc(f, CONTENT), contentData);
  return b.commit();
};
const open = (extra = {}) => ({ status: 'unlocked', openedAt: serverTimestamp(), ...extra });

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-zing-capsules',
    firestore: {
      host: '127.0.0.1',
      port: 8089,
      rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
    },
  });
});
beforeEach(async () => {
  await env.clearFirestore();
  await seed(async (f) => {
    await setDoc(doc(f, 'couples/c1'), { memberUids: ['alice', 'bob'], status: 'active' });
    for (const uid of ['alice', 'bob']) await setDoc(doc(f, `users/${uid}`), { coupleId: 'c1' });
  });
});
after(() => env.cleanup());

describe('sealing', () => {
  test('creator seals a date chest and a dual-tap chest', async () => {
    await assertSucceeds(sealChest('alice', chest(), content()));
    await assertFails(sealChest('alice', chest(), content()));
    await seed((f) => deleteDoc(doc(f, CHEST)));
    await seed((f) => deleteDoc(doc(f, CONTENT)));
    await assertSucceeds(sealChest('alice', dual(), content()));
  });

  test('an offline chest that syncs after its date is still accepted', async () => {
    await assertSucceeds(sealChest('alice', chest({ unlockDate: at(-HOUR) }), content()));
  });

  test('cannot seal as someone else, already open, or with taps', async () => {
    await assertFails(sealChest('bob', chest(), content()));
    await assertFails(sealChest('mallory', chest({ creatorUid: 'mallory' }), content({ creatorUid: 'mallory' })));
    await assertFails(sealChest('alice', chest({ status: 'unlocked' }), content()));
    await assertFails(sealChest('alice', dual({ p2TappedAt: Timestamp.now() }), content()));
    await assertFails(sealChest('alice', chest({ unlockDate: null }), content()));
  });

  test('content is fixed once sealed, and only its creator can add it', async () => {
    await seedChest(chest());
    await assertFails(updateDoc(doc(db('alice'), CONTENT), { secretNote: 'x' }));
    await assertFails(updateDoc(doc(db('bob'), CONTENT), { secretNote: 'x' }));
    await assertFails(deleteDoc(doc(db('bob'), CONTENT)));
    await seed((f) => deleteDoc(doc(f, CONTENT)));
    await assertFails(setDoc(doc(db('bob'), CONTENT), content({ creatorUid: 'bob' })));
    await assertFails(setDoc(doc(db('bob'), CONTENT), content()));
  });
});

describe('reading content', () => {
  test('sealed: creator only, never the partner or a stranger', async () => {
    for (const data of [chest(), dual()]) {
      await seedChest(data);
      await assertSucceeds(getDoc(doc(db('alice'), CONTENT)));
      await assertFails(getDoc(doc(db('bob'), CONTENT)));
      await assertFails(getDocs(collection(db('bob'), `${CHEST}/sealed`)));
      await assertFails(getDoc(doc(db('mallory'), CONTENT)));
    }
  });

  test('unlocked: both partners, still no stranger', async () => {
    await seedChest(dual({}, { status: 'unlocked' }));
    await assertSucceeds(getDoc(doc(db('bob'), CONTENT)));
    await assertFails(getDoc(doc(db('mallory'), CONTENT)));
  });

  test('a date chest opens by the server clock, even before it is marked', async () => {
    await seedChest(chest({ unlockDate: at(-1000) }));
    await assertSucceeds(getDoc(doc(db('bob'), CONTENT)));
  });

  test('cancelled: closed to the partner, even after its date', async () => {
    await seedChest(chest({ status: 'cancelled', unlockDate: at(-1000) }));
    await assertFails(getDoc(doc(db('bob'), CONTENT)));
  });
});

describe('opening', () => {
  test('date chest: not early by anyone, by either once due', async () => {
    await seedChest(chest());
    await assertFails(updateDoc(doc(db('bob'), CHEST), open()));
    await assertFails(updateDoc(doc(db('alice'), CHEST), open()));
    await assertFails(updateDoc(doc(db('bob'), CHEST), { unlockDate: at(-1000) }));
    await assertFails(updateDoc(doc(db('bob'), CHEST), open({ unlockDate: at(-1000) })));
    await assertFails(updateDoc(doc(db('bob'), CHEST), { triggerMode: 'dualTapSync' }));
    await seedChest(chest({ unlockDate: at(-1000) }));
    await assertSucceeds(updateDoc(doc(db('bob'), CHEST), open()));
  });

  test('dual tap: one partner alone cannot open it', async () => {
    await seedChest(dual());
    const ref = doc(db('bob'), CHEST);
    await assertFails(updateDoc(ref, open()));
    await assertFails(updateDoc(ref, { 'dualTapState.p1TappedAt': serverTimestamp() }));
    await assertFails(updateDoc(ref, {
      dualTapState: { p1TappedAt: Timestamp.now(), p2TappedAt: Timestamp.now() },
      ...open(),
    }));
    await assertFails(updateDoc(ref, open({ 'dualTapState.p2TappedAt': serverTimestamp() })));
    await assertSucceeds(updateDoc(ref, { 'dualTapState.p2TappedAt': serverTimestamp() }));
    await assertFails(updateDoc(ref, open()));
  });

  test('dual tap: the second tap opens it, in either order', async () => {
    await seedChest(dual());
    await assertSucceeds(updateDoc(doc(db('bob'), CHEST), { 'dualTapState.p2TappedAt': serverTimestamp() }));
    await assertSucceeds(updateDoc(doc(db('alice'), CHEST), open({ 'dualTapState.p1TappedAt': serverTimestamp() })));
    await seedChest(dual({ p1TappedAt: Timestamp.now() }));
    await assertSucceeds(updateDoc(doc(db('bob'), CHEST), open({ 'dualTapState.p2TappedAt': serverTimestamp() })));
  });

  test('an open or cancelled chest cannot be re-sealed or reopened', async () => {
    await seedChest(chest({ status: 'unlocked' }));
    await assertFails(updateDoc(doc(db('alice'), CHEST), { status: 'sealed' }));
    await assertFails(updateDoc(doc(db('alice'), CHEST), { status: 'cancelled' }));
    await seedChest(chest({ status: 'cancelled', unlockDate: at(-1000) }));
    await assertFails(updateDoc(doc(db('bob'), CHEST), open()));
  });
});

describe('other chest changes', () => {
  test('only the creator cancels; either archives; nobody edits', async () => {
    await seedChest(chest());
    await assertFails(updateDoc(doc(db('bob'), CHEST), { status: 'cancelled' }));
    await assertFails(updateDoc(doc(db('bob'), CHEST), { title: 'x' }));
    await assertFails(updateDoc(doc(db('bob'), CHEST), { creatorUid: 'bob' }));
    await assertSucceeds(updateDoc(doc(db('bob'), CHEST), { isArchived: true }));
    await assertFails(updateDoc(doc(db('mallory'), CHEST), { isArchived: false }));
    await assertSucceeds(updateDoc(doc(db('alice'), CHEST), { status: 'cancelled' }));
  });

  // Chests sealed before this change keep their content in the chest itself.
  const inline = { secretNote: 'secret', photoUrl: null, voiceNoteUrl: null };
  const moveInside = (uid) => {
    const f = db(uid);
    const b = writeBatch(f);
    b.set(doc(f, CONTENT), content({ creatorUid: uid }));
    b.update(doc(f, CHEST), {
      secretNote: deleteField(), photoUrl: deleteField(), voiceNoteUrl: deleteField(),
    });
    return b.commit();
  };

  test('the creator can move an older chest\'s content inside', async () => {
    await seedChest(chest(inline), false);
    await assertFails(moveInside('bob'));
    await assertFails(updateDoc(doc(db('alice'), CHEST), { secretNote: deleteField() }));
    await assertFails(updateDoc(doc(db('alice'), CHEST), { secretNote: 'changed' }));
    await assertSucceeds(moveInside('alice'));
    await assertFails(getDoc(doc(db('bob'), CONTENT)));
  });

  test('phones still on the older build keep working', async () => {
    await assertSucceeds(setDoc(doc(db('alice'), CHEST), {
      ...chest(inline), createdAt: serverTimestamp(),
    }));
    await seedChest(chest({ unlockDate: at(-1000), ...inline }), false);
    await assertSucceeds(updateDoc(doc(db('bob'), CHEST), { status: 'unlocked', openedAt: Timestamp.now() }));
    await seedChest(dual({ p1TappedAt: Timestamp.now() }, inline), false);
    const f = db('bob');
    await assertSucceeds(runTransaction(f, async (tx) => {
      await tx.get(doc(f, CHEST));
      tx.update(doc(f, CHEST), { 'dualTapState.p2TappedAt': Timestamp.now() });
      tx.update(doc(f, CHEST), { status: 'unlocked', openedAt: Timestamp.now() });
    }));
  });
});
