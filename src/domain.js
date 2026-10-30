const ACTIVE = ['Pending', 'Approved', 'Checked out', 'Waitlisted'];
const RESERVED = ['Approved', 'Checked out'];

export function validateRequest({ resource, form, bookings, userId, now = new Date() }) {
  if (!resource || resource.status !== 'Available') return { ok: false, reason: 'This resource is currently unavailable.' };
  const start = new Date(form.start);
  const end = new Date(form.end);
  if (!Number.isFinite(start.getTime()) || !Number.isFinite(end.getTime()) || start <= now || end <= start) {
    return { ok: false, reason: 'Choose a valid future start and end time.' };
  }
  if (!form.purpose?.trim() || form.purpose.trim().length < 5) {
    return { ok: false, reason: 'Add a project purpose of at least 5 characters.' };
  }
  if ((end - start) / 86400000 > Number(resource.maxDays)) {
    return { ok: false, reason: `This resource allows up to ${resource.maxDays} day(s) per booking.` };
  }
  if (bookings.filter(b => b.userId === userId && ACTIVE.includes(b.status)).length >= 3) {
    return { ok: false, reason: 'FairShare limit: you already have 3 active requests or bookings.' };
  }
  const overlaps = bookings.some(b => b.resourceId === resource.id && RESERVED.includes(b.status) && new Date(b.start) < end && new Date(b.end) > start);
  return { ok: true, status: overlaps ? 'Waitlisted' : 'Pending', reason: overlaps ? 'Requested time overlaps an approved booking. Queue order is request time.' : 'Awaiting staff review.', start, end };
}

export function validateApproval({ booking, resource, bookings, trained, verified, approverId, approverRole }) {
  if (!['Resource staff', 'Administrator'].includes(approverRole)) return { ok: false, reason: 'Only authorized staff may approve requests.' };
  if (booking.userId === approverId) return { ok: false, reason: 'You cannot approve your own request.' };
  if (!resource || resource.status !== 'Available') return { ok: false, reason: 'This resource is currently unavailable.' };
  const overlap = bookings.some(b => b.id !== booking.id && b.resourceId === booking.resourceId && RESERVED.includes(b.status) && new Date(b.start) < new Date(booking.end) && new Date(b.end) > new Date(booking.start));
  if (overlap) return { ok: true, status: 'Waitlisted', reason: 'Time was booked before approval; queue order is request time.' };
  if (resource.training && !trained.includes(booking.userId)) return { ok: false, reason: 'Safety induction has not been verified for this requester.' };
  if (resource.membership && !verified.includes(booking.userId)) return { ok: false, reason: 'Workshop membership has not been verified for this requester.' };
  return { ok: true, status: 'Approved' };
}

export function canTransition(from, to) {
  return ({
    Pending: ['Approved', 'Rejected', 'Waitlisted', 'Cancelled'],
    Waitlisted: ['Approved', 'Rejected', 'Cancelled'],
    Approved: ['Checked out', 'Cancelled'],
    'Checked out': ['Returned'],
  })[from]?.includes(to) ?? false;
}

export function normalizeDemoState(value, fallback) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return fallback;
  const arrays = ['resources', 'bookings', 'incidents', 'audit', 'notifications'];
  const result = { ...fallback, ...value };
  for (const field of arrays) {
    if (!Array.isArray(value[field])) result[field] = fallback[field];
    else result[field] = value[field].filter(item => {
      if (!item || typeof item !== 'object' || Array.isArray(item)) return false;
      if (field === 'resources') return typeof item.id === 'string' && typeof item.name === 'string' && typeof item.status === 'string';
      if (field === 'bookings') return typeof item.id === 'string' && typeof item.resourceId === 'string' && typeof item.userId === 'string' && typeof item.status === 'string';
      if (field === 'incidents') return typeof item.id === 'string' && typeof item.description === 'string' && typeof item.status === 'string';
      if (field === 'audit') return typeof item.id === 'string' && typeof item.event === 'string';
      return typeof item.id === 'string' && typeof item.title === 'string';
    });
  }
  for (const field of ['trained', 'verified']) {
    if (!Array.isArray(value[field])) result[field] = fallback[field];
    else result[field] = value[field].filter(item => typeof item === 'string');
  }
  return result;
}
