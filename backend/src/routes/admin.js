const router = require('express').Router();
const { body } = require('express-validator');
const ctrl   = require('../controllers/adminController');
const { requireAuth, requireAdmin } = require('../middleware/auth');
const db = require('../config/database');

// Tournament create has its own permission gate: system admin OR a user
// who manages the clubhouse_id supplied in the body. Defined BEFORE the
// router.use(requireAdmin) so non-admins reach it.
async function canCreateTournament(req, res, next) {
  if (req.user.is_admin) return next();
  const clubhouseId = req.body && req.body.clubhouse_id;
  if (!clubhouseId) {
    return res.status(403).json({
      error: 'Choose a clubhouse you manage to host this tournament.',
    });
  }
  try {
    const { rows } = await db.query(
      `SELECT 1 FROM clubhouses WHERE id = $1 AND owner_id = $2
       UNION
       SELECT 1 FROM clubhouse_members
        WHERE clubhouse_id = $1 AND user_id = $2
          AND role = 'staff' AND status = 'member'`,
      [clubhouseId, req.user.id]
    );
    if (!rows.length) {
      return res.status(403).json({ error: 'You don\'t manage that clubhouse.' });
    }
    next();
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Permission check failed' });
  }
}

router.post('/tournaments',
  requireAuth,
  body('name').trim().notEmpty(),
  body('city').trim().notEmpty(),
  body('date').isISO8601(),
  body('format').isIn(['individual', 'fourball', 'scramble']),
  body('sign_up_fee').isFloat({ min: 0 }),
  body('max_players').isInt({ min: 2 }),
  canCreateTournament,
  ctrl.createTournament
);

// Tournament-scoped routes: admin OR a clubhouse manager whose clubhouse
// owns this tournament.
async function canManageTournament(req, res, next) {
  if (req.user.is_admin) return next();
  const tournamentId = req.params.id;
  if (!tournamentId) return res.status(403).json({ error: 'No tournament' });
  try {
    const { rows } = await db.query(
      `SELECT t.clubhouse_id
         FROM tournaments t
        WHERE t.id = $1`,
      [tournamentId]
    );
    if (!rows.length) return res.status(404).json({ error: 'Tournament not found' });
    const clubhouseId = rows[0].clubhouse_id;
    if (!clubhouseId) {
      return res.status(403).json({ error: 'You don\'t manage this tournament.' });
    }
    const { rows: perm } = await db.query(
      `SELECT 1 FROM clubhouses WHERE id = $1 AND owner_id = $2
       UNION
       SELECT 1 FROM clubhouse_members
        WHERE clubhouse_id = $1 AND user_id = $2
          AND role = 'staff' AND status = 'member'`,
      [clubhouseId, req.user.id]
    );
    if (!perm.length) {
      return res.status(403).json({ error: 'You don\'t manage this tournament.' });
    }
    next();
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Permission check failed' });
  }
}

router.patch('/tournaments/:id', requireAuth, canManageTournament, ctrl.updateTournament);
router.delete('/tournaments/:id', requireAuth, canManageTournament, ctrl.deleteTournament);
router.get('/tournaments/:id/participants', requireAuth, canManageTournament, ctrl.adminGetParticipants);
router.get('/tournaments/:id/financials', requireAuth, canManageTournament, ctrl.getFinancials);
router.patch('/tournaments/:id/financials', requireAuth, canManageTournament, ctrl.updateFinancials);
router.patch('/tournaments/:id/scores/:entryId', requireAuth, canManageTournament, ctrl.adminUpdateScore);
router.patch('/tournaments/:id/entries/:entryId/payment', requireAuth, canManageTournament, ctrl.adminUpdatePayment);

module.exports = router;
