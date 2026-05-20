const { getFirebaseAdmin } = require('./_firebase');

function cleanString(value, maxLength = 200) {
  return String(value || '').trim().slice(0, maxLength);
}

function cleanPayoutSplits(value) {
  if (!Array.isArray(value)) {
    return [];
  }
  const splits = value.map((item) => ({
    place: Number(item?.place),
    percent: Number(item?.percent),
  })).filter((item) =>
    Number.isInteger(item.place) &&
    item.place > 0 &&
    Number.isInteger(item.percent) &&
    item.percent > 0,
  );
  const total = splits.reduce((sum, item) => sum + item.percent, 0);
  if (splits.length === 0 || total !== 100) {
    const error = new Error('Payout splits must add up to 100%.');
    error.statusCode = 400;
    throw error;
  }
  return splits;
}

async function reserveTicket({ uid, tournamentId }) {
  const admin = getFirebaseAdmin();
  const firestore = admin.firestore();
  const tournamentRef = firestore.collection('drafttool_tournaments').doc(tournamentId);
  const balanceRef = firestore.collection('balances').doc(uid);
  const playerRef = tournamentRef.collection('players').doc(uid);
  let ticketPkn = 0;

  await firestore.runTransaction(async (transaction) => {
    const [tournamentDoc, balanceDoc, playerDoc] = await Promise.all([
      transaction.get(tournamentRef),
      transaction.get(balanceRef),
      transaction.get(playerRef),
    ]);
    if (!tournamentDoc.exists) {
      throw Object.assign(new Error('Tournament not found.'), { statusCode: 404 });
    }
    const tournament = tournamentDoc.data() || {};
    ticketPkn = Number(tournament.ticketPkn || 0);
    if (!Number.isInteger(ticketPkn) || ticketPkn <= 0) {
      throw Object.assign(new Error('This tournament has no ticket.'), { statusCode: 400 });
    }
    if (playerDoc.data()?.ticketReserved === true) {
      return;
    }
    const available = Number(balanceDoc.data()?.availablePkn || 0);
    if (available < ticketPkn) {
      throw Object.assign(new Error('Your PKN balance is too low for this ticket.'), { statusCode: 400 });
    }
    const now = admin.firestore.FieldValue.serverTimestamp();
    transaction.set(balanceRef, {
      availablePkn: admin.firestore.FieldValue.increment(-ticketPkn),
      lockedPkn: admin.firestore.FieldValue.increment(ticketPkn),
      updatedAt: now,
    }, { merge: true });
    transaction.set(playerRef, {
      uid,
      ticketReserved: true,
      ticketPkn,
      joinedAt: now,
      status: 'joined',
    }, { merge: true });
    transaction.set(tournamentRef, {
      escrowPkn: admin.firestore.FieldValue.increment(ticketPkn),
      participantUids: admin.firestore.FieldValue.arrayUnion(uid),
      updatedAt: now,
    }, { merge: true });
    transaction.set(firestore.collection('ledger_entries').doc(), {
      uid,
      type: 'tournament_ticket_reserved',
      amountPkn: -ticketPkn,
      referenceId: tournamentId,
      status: 'locked',
      createdAt: now,
    });
  });

  return { ok: true, ticketPkn };
}

async function refundTournament({ uid, tournamentId }) {
  const admin = getFirebaseAdmin();
  const firestore = admin.firestore();
  const tournamentRef = firestore.collection('drafttool_tournaments').doc(tournamentId);
  const tournamentDoc = await tournamentRef.get();
  if (!tournamentDoc.exists) {
    throw Object.assign(new Error('Tournament not found.'), { statusCode: 404 });
  }
  const tournament = tournamentDoc.data() || {};
  if (tournament.creatorUid !== uid) {
    throw Object.assign(new Error('Only the creator can refund this tournament.'), { statusCode: 403 });
  }
  const players = await tournamentRef.collection('players').where('ticketReserved', '==', true).get();
  const now = admin.firestore.FieldValue.serverTimestamp();

  await firestore.runTransaction(async (transaction) => {
    let refunded = 0;
    players.docs.forEach((playerDoc) => {
      const player = playerDoc.data() || {};
      const playerUid = cleanString(player.uid || playerDoc.id, 120);
      const ticketPkn = Number(player.ticketPkn || 0);
      if (!playerUid || ticketPkn <= 0) {
        return;
      }
      refunded += ticketPkn;
      const balanceRef = firestore.collection('balances').doc(playerUid);
      transaction.set(balanceRef, {
        availablePkn: admin.firestore.FieldValue.increment(ticketPkn),
        lockedPkn: admin.firestore.FieldValue.increment(-ticketPkn),
        updatedAt: now,
      }, { merge: true });
      transaction.set(playerDoc.ref, {
        ticketReserved: false,
        ticketRefunded: true,
        updatedAt: now,
      }, { merge: true });
      transaction.set(firestore.collection('ledger_entries').doc(), {
        uid: playerUid,
        type: 'tournament_ticket_refunded',
        amountPkn: ticketPkn,
        referenceId: tournamentId,
        status: 'refunded',
        createdAt: now,
      });
    });
    transaction.set(tournamentRef, {
      escrowPkn: admin.firestore.FieldValue.increment(-refunded),
      status: 'canceled',
      updatedAt: now,
    }, { merge: true });
  });

  return { ok: true, refundedPlayers: players.size };
}

async function finalizePayout({ uid, tournamentId, standings, payoutSplits }) {
  const admin = getFirebaseAdmin();
  const firestore = admin.firestore();
  const tournamentRef = firestore.collection('drafttool_tournaments').doc(tournamentId);
  const splits = cleanPayoutSplits(payoutSplits);
  if (!Array.isArray(standings) || standings.length === 0) {
    throw Object.assign(new Error('Final standings are required.'), { statusCode: 400 });
  }
  const now = admin.firestore.FieldValue.serverTimestamp();
  let paidTotal = 0;

  await firestore.runTransaction(async (transaction) => {
    const tournamentDoc = await transaction.get(tournamentRef);
    if (!tournamentDoc.exists) {
      throw Object.assign(new Error('Tournament not found.'), { statusCode: 404 });
    }
    const tournament = tournamentDoc.data() || {};
    if (tournament.creatorUid !== uid) {
      throw Object.assign(new Error('Only the creator can finalize payouts.'), { statusCode: 403 });
    }
    if (tournament.payoutFinalized === true) {
      throw Object.assign(new Error('Payout has already been finalized.'), { statusCode: 400 });
    }
    const escrowPkn = Number(tournament.escrowPkn || 0);
    if (escrowPkn <= 0) {
      throw Object.assign(new Error('There is no escrow to pay out.'), { statusCode: 400 });
    }

    splits.forEach((split) => {
      const standing = standings.find((row) => Number(row.place) === split.place);
      const winnerUid = cleanString(standing?.uid, 120);
      if (!winnerUid) {
        return;
      }
      const amount = Math.floor((escrowPkn * split.percent) / 100);
      if (amount <= 0) {
        return;
      }
      paidTotal += amount;
      transaction.set(firestore.collection('balances').doc(winnerUid), {
        availablePkn: admin.firestore.FieldValue.increment(amount),
        updatedAt: now,
      }, { merge: true });
      transaction.set(firestore.collection('ledger_entries').doc(), {
        uid: winnerUid,
        type: 'tournament_payout_received',
        amountPkn: amount,
        referenceId: tournamentId,
        place: split.place,
        createdAt: now,
      });
    });

    transaction.set(tournamentRef, {
      payoutFinalized: true,
      paidOutPkn: paidTotal,
      status: 'finalized',
      finalStandings: standings,
      updatedAt: now,
    }, { merge: true });
  });

  return { ok: true, paidOutPkn: paidTotal };
}

module.exports = {
  reserveTicket,
  refundTournament,
  finalizePayout,
};
