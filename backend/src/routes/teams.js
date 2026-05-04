const router = require('express').Router();
const ctrl   = require('../controllers/teamController');
const { requireAuth } = require('../middleware/auth');

router.get('/',                      ctrl.listTeams);
router.get('/mine',     requireAuth, ctrl.getMyTeam);
router.post('/create',  requireAuth, ctrl.createTeam);
router.post('/:id/join', requireAuth, ctrl.joinTeam);

module.exports = router;
