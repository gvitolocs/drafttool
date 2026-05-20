const { verifyBearerToken } = require('./_firebase');
const {
  reserveTicket,
  refundTournament,
  finalizePayout,
} = require('./_tournament_tickets');

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST');
    return res.status(405).json({ error: 'Method not allowed.' });
  }

  try {
    const decoded = await verifyBearerToken(req);
    const action = String(req.query?.action || req.body?.action || '').trim();
    const tournamentId = String(req.body?.tournamentId || '').trim();
    if (!tournamentId) {
      return res.status(400).json({ error: 'Tournament ID is required.' });
    }

    if (action === 'reserve') {
      const result = await reserveTicket({ uid: decoded.uid, tournamentId });
      return res.status(200).json(result);
    }
    if (action === 'refund') {
      const result = await refundTournament({ uid: decoded.uid, tournamentId });
      return res.status(200).json(result);
    }
    if (action === 'finalize') {
      const result = await finalizePayout({
        uid: decoded.uid,
        tournamentId,
        standings: req.body?.standings,
        payoutSplits: req.body?.payoutSplits,
      });
      return res.status(200).json(result);
    }

    return res.status(400).json({ error: 'Unknown ticket action.' });
  } catch (error) {
    console.error('tournament-ticket failed', error);
    return res.status(error.statusCode || 500).json({
      error: error.message || 'Tournament ticket action failed.',
    });
  }
};
