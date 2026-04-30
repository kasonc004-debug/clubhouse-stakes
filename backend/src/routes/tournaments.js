const router = require('express').Router();
const ctrl   = require('../controllers/tournamentController');
const { requireAuth } = require('../middleware/auth');

router.get('/',                        ctrl.listTournaments);
router.get('/:id',                     ctrl.getTournament);
router.post('/:id/join', requireAuth,  ctrl.joinTournament);
router.get('/:id/participants',        ctrl.getParticipants);

module.exports = router;
