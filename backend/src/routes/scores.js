const router = require('express').Router();
const ctrl   = require('../controllers/scoreController');
const { requireAuth } = require('../middleware/auth');

router.post('/submit',                requireAuth, ctrl.submitScore);
router.get('/:tournament_id/me',      requireAuth, ctrl.getMyScore);
router.patch('/:tournament_id/hole',  requireAuth, ctrl.updateHoleScore);

module.exports = router;
