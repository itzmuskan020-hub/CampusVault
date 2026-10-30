import test from 'node:test';
import assert from 'node:assert/strict';
import { canTransition, normalizeDemoState, validateApproval, validateRequest } from './domain.js';

const now = new Date('2030-04-01T08:00:00Z');
const resource = { id: 'camera', status: 'Available', maxDays: 3, training: true, membership: false };
const base = { resource, form: { purpose: 'Course project', start: '2030-04-02T10:00:00Z', end: '2030-04-02T12:00:00Z' }, bookings: [], userId: 'student', now };
const booking = { id: 'b1', resourceId: 'camera', userId: 'student', start: '2030-04-02T10:00:00Z', end: '2030-04-02T12:00:00Z', status: 'Pending' };

test('accepts a valid future request and returns pending status', () => {
  const result = validateRequest(base);
  assert.equal(result.ok, true);
  assert.equal(result.status, 'Pending');
});

test('rejects past, reversed, overlong, incomplete and unavailable requests', () => {
  assert.equal(validateRequest({ ...base, form: { ...base.form, start: '2030-03-31T10:00:00Z' } }).ok, false);
  assert.equal(validateRequest({ ...base, form: { ...base.form, end: base.form.start } }).ok, false);
  assert.equal(validateRequest({ ...base, form: { ...base.form, end: '2030-04-06T12:00:00Z' } }).ok, false);
  assert.equal(validateRequest({ ...base, form: { ...base.form, purpose: 'ok' } }).ok, false);
  assert.equal(validateRequest({ ...base, resource: { ...resource, status: 'Unavailable' } }).ok, false);
});

test('enforces the FairShare cap and waitlists overlapping approved bookings', () => {
  const three = [1, 2, 3].map(n => ({ id: String(n), userId: 'student', status: 'Pending' }));
  assert.equal(validateRequest({ ...base, bookings: three }).ok, false);
  const reserved = { ...booking, status: 'Approved' };
  const result = validateRequest({ ...base, bookings: [reserved] });
  assert.equal(result.ok, true);
  assert.equal(result.status, 'Waitlisted');
});

test('approval requires staff, requester eligibility, no self-approval and no overlap', () => {
  const args = { booking, resource, bookings: [booking], trained: ['student'], verified: [], approverId: 'staff', approverRole: 'Resource staff' };
  assert.deepEqual(validateApproval(args), { ok: true, status: 'Approved' });
  assert.equal(validateApproval({ ...args, trained: [] }).ok, false);
  assert.equal(validateApproval({ ...args, approverId: 'student' }).ok, false);
  assert.equal(validateApproval({ ...args, approverRole: 'Student' }).ok, false);
  assert.equal(validateApproval({ ...args, bookings: [booking, { ...booking, id: 'other', status: 'Approved' }] }).status, 'Waitlisted');
});

test('allows only valid booking lifecycle transitions', () => {
  assert.equal(canTransition('Approved', 'Checked out'), true);
  assert.equal(canTransition('Checked out', 'Returned'), true);
  assert.equal(canTransition('Returned', 'Approved'), false);
  assert.equal(canTransition('Pending', 'Returned'), false);
});

test('normalizes malformed saved demo state rather than crashing on refresh', () => {
  const fallback = { resources: [{ id: 'r', name: 'Camera', status: 'Available' }], bookings: [], incidents: [], audit: [], notifications: [], trained: ['student'], verified: ['student'] };
  const restored = normalizeDemoState({ bookings: [{ nope: true }, { id: 'b', resourceId: 'r', userId: 'student', status: 'Pending' }], resources: null, trained: 'broken' }, fallback);
  assert.equal(restored.resources, fallback.resources);
  assert.equal(restored.bookings.length, 1);
  assert.deepEqual(restored.trained, fallback.trained);
  assert.equal(normalizeDemoState(null, fallback), fallback);
});
