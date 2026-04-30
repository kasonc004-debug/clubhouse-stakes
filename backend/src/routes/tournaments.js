const router = require('express').Router();
const ctrl   = require('../controllers/tournamentController');
const { requireAuth, optionalAuth } = require('../middleware/auth');

router.get('/',                          ctrl.listTournaments);
router.get('/mine',     requireAuth,     ctrl.getMyTournaments);
router.get('/:id',      optionalAuth,    ctrl.getTournament);
router.post('/:id/join',  requireAuth, ctrl.joinTournament);
router.post('/:id/skins', requireAuth, ctrl.joinSkins);
router.get('/:id/participants',        ctrl.getParticipants);

module.exports = router;
