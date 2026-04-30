const router = require('express').Router();
const { body } = require('express-validator');
const ctrl   = require('../controllers/adminController');
const { requireAuth, requireAdmin } = require('../middleware/auth');

router.use(requireAuth, requireAdmin);

router.post('/tournaments',
  body('name').trim().notEmpty(),
  body('city').trim().notEmpty(),
  body('date').isISO8601(),
  body('format').isIn(['individual', 'fourball']),
  body('sign_up_fee').isFloat({ min: 0 }),
  body('max_players').isInt({ min: 2 }),
  ctrl.createTournament
);

router.patch('/tournaments/:id', ctrl.updateTournament);
router.get('/tournaments/:id/participants', ctrl.adminGetParticipants);

module.exports = router;
