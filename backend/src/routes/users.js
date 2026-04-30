const router = require('express').Router();
const ctrl   = require('../controllers/userController');
const { requireAuth } = require('../middleware/auth');

router.get('/search',       requireAuth, ctrl.searchUsers);
router.get('/leaderboard',                ctrl.globalLeaderboard);
router.get('/:id',                        ctrl.getUserProfile);
router.get('/:id/stats',                  ctrl.getUserStats);

module.exports = router;
